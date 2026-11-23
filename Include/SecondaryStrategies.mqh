//+------------------------------------------------------------------+
//| SecondaryStrategies.mqh                                          |
//| BOS/OB, breakout/retest and trend-pullback signal modules.       |
//| Signal generation only: no trade/order APIs are used here.        |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_SECONDARY_STRATEGIES_MQH
#define FOREX_AGENT_SECONDARY_STRATEGIES_MQH

#include "M5EntrySignal.mqh"

enum PA_StrategyType
  {
   PA_STRATEGY_NONE = 0,
   PA_STRATEGY_SWEEP_CHOCH_FVG,
   PA_STRATEGY_BOS_OB_RETEST,
   PA_STRATEGY_BREAKOUT_RETEST,
   PA_STRATEGY_TREND_PULLBACK,
   PA_STRATEGY_SWEEP_RECLAIM_MSS
  };

enum PA_SecondaryStage
  {
   PA_SECONDARY_IDLE = 0,
   PA_SECONDARY_WAIT_RETEST,
   PA_SECONDARY_WAIT_PULLBACK,
   PA_SECONDARY_WAIT_CONTINUATION,
   PA_SECONDARY_WAIT_RECLAIM,
   PA_SECONDARY_WAIT_MSS,
   PA_SECONDARY_WAIT_CONFIRMATION,
   PA_SECONDARY_WAIT_TRIGGER
  };

struct PA_SecondarySetup
  {
   PA_SecondaryStage stage;
   int               direction;
   datetime          source_event_time;
   datetime          setup_created_time;
   double            zone_low;
   double            zone_high;
   double            reference_level;
   double            pullback_extreme;
   int               bars_waiting;
   string            setup_id;
  };

struct PA_SecondaryStrategyState
  {
   datetime       last_processed_m5_bar_time;
   datetime       last_seen_m15_event_time;
   PA_SecondarySetup order_block;
   PA_SecondarySetup breakout;
   PA_SecondarySetup continuation;
   PA_SecondarySetup model_b2;
   string         last_emitted_setup_id;
  };

struct PA_StrategySignal
  {
   PA_StrategyType strategy;
   int             direction;
   datetime        signal_bar_time;
   datetime        source_event_time;
   double          reference_level;
   double          invalidation_level;
   double          zone_low;
   double          zone_high;
   string          setup_id;
   string          rejection_reason;
  };

void PA_ResetSecondarySetup(PA_SecondarySetup &setup)
  {
   setup.stage=PA_SECONDARY_IDLE;
   setup.direction=0;
   setup.source_event_time=0;
   setup.setup_created_time=0;
   setup.zone_low=0.0;
   setup.zone_high=0.0;
   setup.reference_level=0.0;
   setup.pullback_extreme=0.0;
   setup.bars_waiting=0;
   setup.setup_id="";
  }

void PA_ResetSecondaryStrategyState(PA_SecondaryStrategyState &state)
  {
   state.last_processed_m5_bar_time=0;
   state.last_seen_m15_event_time=0;
   PA_ResetSecondarySetup(state.order_block);
   PA_ResetSecondarySetup(state.breakout);
   PA_ResetSecondarySetup(state.continuation);
   PA_ResetSecondarySetup(state.model_b2);
   state.last_emitted_setup_id="";
  }

void PA_ResetStrategySignal(PA_StrategySignal &signal)
  {
   signal.strategy=PA_STRATEGY_NONE;
   signal.direction=0;
   signal.signal_bar_time=0;
   signal.source_event_time=0;
   signal.reference_level=0.0;
   signal.invalidation_level=0.0;
   signal.zone_low=0.0;
   signal.zone_high=0.0;
   signal.setup_id="";
   signal.rejection_reason="";
  }

string PA_StrategyName(const PA_StrategyType strategy)
  {
   if(strategy==PA_STRATEGY_SWEEP_CHOCH_FVG) return "SWEEP_CHOCH_FVG";
   if(strategy==PA_STRATEGY_BOS_OB_RETEST) return "BOS_OB_RETEST";
   if(strategy==PA_STRATEGY_BREAKOUT_RETEST) return "BREAKOUT_RETEST";
   if(strategy==PA_STRATEGY_TREND_PULLBACK) return "TREND_PULLBACK";
   if(strategy==PA_STRATEGY_SWEEP_RECLAIM_MSS) return "SWEEP_RECLAIM_MSS_B2";
   return "NONE";
  }

string PA_MakeSecondarySetupId(const string symbol,
                               const PA_StrategyType strategy,
                               const int direction,
                               const datetime source_time,
                               const double reference_level)
  {
   return StringFormat("%s|%s|%s|%I64d|%s",
      symbol,PA_StrategyName(strategy),direction>0?"BUY":"SELL",
      (long)source_time,DoubleToString(reference_level,8));
  }

double PA_SecondaryATR(const MqlRates &rates[],const int count,
                       const int period=14)
  {
   if(count<period+2 || period<1)
      return 0.0;
   double total=0.0;
   for(int shift=1;shift<=period;shift++)
     {
      const double previous=rates[shift+1].close;
      const double tr=MathMax(rates[shift].high-rates[shift].low,
         MathMax(MathAbs(rates[shift].high-previous),
                 MathAbs(rates[shift].low-previous)));
      total+=tr;
     }
   return total/period;
  }

// Latest two confirmed pivots; series arrays use smaller shifts for newer bars.
bool PA_GetLatestTwoConfirmedSwings(const MqlRates &rates[],const int count,
                                    const int lookback,const bool find_high,
                                    double &latest_level,datetime &latest_time,
                                    double &previous_level,datetime &previous_time)
  {
   latest_level=0.0; latest_time=0;
   previous_level=0.0; previous_time=0;
   if(count<12 || lookback<4) return false;
   int found=0;
   const int last_shift=(int)MathMin(lookback,count-4);
   for(int shift=4;shift<=last_shift;shift++)
     {
      const bool pivot=find_high ? PA_IsConfirmedSwingHigh(rates,count,shift)
                                 : PA_IsConfirmedSwingLow(rates,count,shift);
      if(!pivot) continue;
      const double level=find_high?rates[shift].high:rates[shift].low;
      const datetime pivot_time=rates[shift].time;
      if(found==0)
        {
         latest_level=level; latest_time=pivot_time; found=1;
        }
      else
        {
         previous_level=level; previous_time=pivot_time;
         return (latest_time>previous_time);
        }
     }
   return false;
  }

bool PA_HasConfirmedH1TrendStructure(const MqlRates &h1_rates[],
                                     const int h1_count,const int direction,
                                     const int lookback=80)
  {
   if(direction!=1 && direction!=-1) return false;
   double lh=0.0,ph=0.0,ll=0.0,pl=0.0;
   datetime lht=0,pht=0,llt=0,plt=0;
   if(!PA_GetLatestTwoConfirmedSwings(h1_rates,h1_count,lookback,true,
      lh,lht,ph,pht) ||
      !PA_GetLatestTwoConfirmedSwings(h1_rates,h1_count,lookback,false,
      ll,llt,pl,plt))
      return false;
   if(direction>0) return (lh>ph && ll>pl);
   return (lh<ph && ll<pl);
  }

bool PA_IsBullishRejection(const MqlRates &bar)
  {
   const double body=MathAbs(bar.close-bar.open);
   const double lower_wick=MathMin(bar.open,bar.close)-bar.low;
   const double midpoint=(bar.high+bar.low)/2.0;
   return (bar.close>bar.open && lower_wick>=body &&
           bar.close>midpoint);
  }

bool PA_IsBearishRejection(const MqlRates &bar)
  {
   const double body=MathAbs(bar.close-bar.open);
   const double upper_wick=bar.high-MathMax(bar.open,bar.close);
   const double midpoint=(bar.high+bar.low)/2.0;
   return (bar.close<bar.open && upper_wick>=body &&
           bar.close<midpoint);
  }

bool PA_IsBullishM5Confirmation(const MqlRates &rates[],
                                const int count,
                                const PA_StructureSnapshot &snapshot)
  {
   if(count<3)
      return false;
   const bool current_choch=(snapshot.signal_bar_time==rates[1].time &&
      snapshot.break_type==PA_BREAK_CHOCH_BULLISH);
   return (current_choch ||
           (PA_IsBullishRejection(rates[1]) &&
            rates[1].close>rates[1].high-(rates[1].high-rates[1].low)*0.25));
  }

bool PA_IsBearishM5Confirmation(const MqlRates &rates[],
                                const int count,
                                const PA_StructureSnapshot &snapshot)
  {
   if(count<3)
      return false;
   const bool current_choch=(snapshot.signal_bar_time==rates[1].time &&
      snapshot.break_type==PA_BREAK_CHOCH_BEARISH);
   return (current_choch ||
           (PA_IsBearishRejection(rates[1]) &&
            rates[1].close<rates[1].low+(rates[1].high-rates[1].low)*0.25));
  }

void PA_EmitSecondarySignal(const string symbol,
                            const PA_StrategyType strategy,
                            const PA_SecondarySetup &setup,
                            const datetime signal_time,
                            const double invalidation,
                            PA_StrategySignal &signal)
  {
   signal.strategy=strategy;
   signal.direction=setup.direction;
   signal.signal_bar_time=signal_time;
   signal.source_event_time=setup.source_event_time;
   signal.reference_level=setup.reference_level;
   signal.invalidation_level=invalidation;
   signal.zone_low=setup.zone_low;
   signal.zone_high=setup.zone_high;
   signal.setup_id=PA_MakeSecondarySetupId(symbol,strategy,setup.direction,
                                           setup.source_event_time,
                                           setup.reference_level);
   signal.rejection_reason="SIGNAL_READY_NO_ORDER_SENT";
  }

// Find the nearest opposing candle before the M15 BOS candle.
// rates is series: shift 1 is BOS candle, shifts 2..max are older.
bool PA_FindOrderBlock(const MqlRates &rates[],const int count,
                       const int direction,const int maximum_search,
                       double &zone_low,double &zone_high)
  {
   zone_low=0.0;
   zone_high=0.0;
   if(count<4 || maximum_search<1)
      return false;
   const int last=(int)MathMin(maximum_search+1,count-1);
   for(int shift=2;shift<=last;shift++)
     {
      const bool opposing=direction>0
         ? rates[shift].close<rates[shift].open
         : rates[shift].close>rates[shift].open;
      if(opposing)
        {
         zone_low=rates[shift].low;
         zone_high=rates[shift].high;
         return (zone_high>zone_low);
        }
     }
   return false;
  }

// Capture a newly confirmed M15 BOS exactly once. The caller must update
// the M15 structure state from closed candles before calling this module.
void PA_CaptureM15BOS(const string symbol,
                      const MqlRates &h1_rates[],
                      const int h1_count,
                      const MqlRates &m15_rates[],
                      const int m15_count,
                      const PA_StructureState &m15_state,
                      const PA_MultiTimeframeSnapshot &context,
                      PA_SecondaryStrategyState &state)
  {
   const datetime event_time=m15_state.last_structure_event_time;
   if(event_time<=0 || event_time<=state.last_seen_m15_event_time)
      return;
   state.last_seen_m15_event_time=event_time;

   const bool bullish_bos=(m15_state.last_break_type==PA_BREAK_BOS_BULLISH);
   const bool bearish_bos=(m15_state.last_break_type==PA_BREAK_BOS_BEARISH);
   if(!bullish_bos && !bearish_bos)
      return;

   const int direction=bullish_bos?1:-1;
   const bool aligned=(direction>0 &&
      context.context==PA_CONTEXT_BULLISH_ALIGNED) ||
      (direction<0 && context.context==PA_CONTEXT_BEARISH_ALIGNED);
   if(!aligned || m15_count<20 || m15_rates[1].time!=event_time)
      return;

   double ob_low=0.0,ob_high=0.0;
   if(PA_FindOrderBlock(m15_rates,m15_count,direction,8,ob_low,ob_high))
     {
      PA_ResetSecondarySetup(state.order_block);
      state.order_block.stage=PA_SECONDARY_WAIT_RETEST;
      state.order_block.direction=direction;
      state.order_block.source_event_time=event_time;
      state.order_block.setup_created_time=event_time+PeriodSeconds(PERIOD_M15);
      state.order_block.zone_low=ob_low;
      state.order_block.zone_high=ob_high;
      state.order_block.reference_level=direction>0?ob_high:ob_low;
      state.order_block.setup_id=PA_MakeSecondarySetupId(symbol,
         PA_STRATEGY_BOS_OB_RETEST,direction,event_time,
         state.order_block.reference_level);
     }

   // Breakout requires a strong M15 BOS candle body (> 0.5 ATR).
   const double atr=PA_SecondaryATR(m15_rates,m15_count,14);
   const double body=MathAbs(m15_rates[1].close-m15_rates[1].open);
   if(atr>0.0 && body>0.5*atr)
     {
      const double level=direction>0
         ? m15_state.latest_swing_high : m15_state.latest_swing_low;
      if(level>0.0)
        {
         PA_ResetSecondarySetup(state.breakout);
         state.breakout.stage=PA_SECONDARY_WAIT_RETEST;
         state.breakout.direction=direction;
         state.breakout.source_event_time=event_time;
         state.breakout.setup_created_time=event_time+PeriodSeconds(PERIOD_M15);
         state.breakout.reference_level=level;
         state.breakout.zone_low=level;
         state.breakout.zone_high=level;
         state.breakout.setup_id=PA_MakeSecondarySetupId(symbol,
            PA_STRATEGY_BREAKOUT_RETEST,direction,event_time,level);
        }
     }

   // Model A requires explicit H1 HH/HL or LL/LH and a completed-M15 ATR.
   const bool h1_valid=PA_HasConfirmedH1TrendStructure(h1_rates,h1_count,direction,80);
   const double m15_atr=PA_SecondaryATR(m15_rates,m15_count,14);
   const double support=direction>0
      ? m15_state.latest_swing_high : m15_state.latest_swing_low;
   if(h1_valid && m15_atr>0.0 && support>0.0)
     {
      const double half_zone=0.15*m15_atr;
      PA_ResetSecondarySetup(state.continuation);
      state.continuation.stage=PA_SECONDARY_WAIT_PULLBACK;
      state.continuation.direction=direction;
      state.continuation.source_event_time=event_time;
      state.continuation.setup_created_time=event_time+PeriodSeconds(PERIOD_M15);
      state.continuation.reference_level=support;
      state.continuation.zone_low=support-half_zone;
      state.continuation.zone_high=support+half_zone;
      state.continuation.setup_id=PA_MakeSecondarySetupId(symbol,
         PA_STRATEGY_TREND_PULLBACK,direction,event_time,support);
     }
   else
      PA_ResetSecondarySetup(state.continuation);
  }


bool PA_EvaluateModelB2(const string symbol,
                        const MqlRates &m15_rates[],const int m15_count,
                        const MqlRates &d1_rates[],const int d1_count,
                        const MqlRates &m5_rates[],const int m5_count,
                        const double spread_price,const int context_direction,
                        const PA_StructureSnapshot &m5_snapshot,
                        PA_SecondarySetup &setup,PA_StrategySignal &signal)
  {
   PA_ResetStrategySignal(signal);
   if(symbol=="" || m15_count<20 || m5_count<20 ||
      spread_price<0.0 || (context_direction!=1 && context_direction!=-1) ||
      m5_rates[1].time<=0)
     { signal.rejection_reason="MODEL_B2_INVALID_INPUT"; return false; }
   const double atr=PA_SecondaryATR(m15_rates,m15_count,14);
   if(atr<=0.0)
     { signal.rejection_reason="MODEL_B2_M15_ATR_NOT_READY"; return false; }

   if(setup.stage==PA_SECONDARY_IDLE)
     {
      double sh=0.0,sl=0.0,ph=0.0,pl=0.0;
      datetime sht=0,slt=0,pht=0,plt=0;
      const bool have_high=PA_GetLatestTwoConfirmedSwings(m15_rates,m15_count,80,true,sh,sht,ph,pht);
      const bool have_low=PA_GetLatestTwoConfirmedSwings(m15_rates,m15_count,80,false,sl,slt,pl,plt);
      const double min_distance=MathMax(0.05*atr,2.0*spread_price);
      double level=0.0,extreme=0.0,best=0.0;
      bool found=false;
      if(context_direction>0)
        {
         if(have_low && m5_rates[1].time>slt)
           { const double d=sl-m5_rates[1].low;
             if(m5_rates[1].low<sl && d>=min_distance)
               { found=true; level=sl; extreme=m5_rates[1].low; best=d; } }
         if(d1_count>1 && m5_rates[1].time>d1_rates[1].time)
           { const double d=d1_rates[1].low-m5_rates[1].low;
             if(m5_rates[1].low<d1_rates[1].low && d>=min_distance && d>best)
               { found=true; level=d1_rates[1].low; extreme=m5_rates[1].low; } }
        }
      else
        {
         if(have_high && m5_rates[1].time>sht)
           { const double d=m5_rates[1].high-sh;
             if(m5_rates[1].high>sh && d>=min_distance)
               { found=true; level=sh; extreme=m5_rates[1].high; best=d; } }
         if(d1_count>1 && m5_rates[1].time>d1_rates[1].time)
           { const double d=m5_rates[1].high-d1_rates[1].high;
             if(m5_rates[1].high>d1_rates[1].high && d>=min_distance && d>best)
               { found=true; level=d1_rates[1].high; extreme=m5_rates[1].high; } }
        }
      if(!found)
        { signal.rejection_reason="MODEL_B2_NO_QUALIFIED_M15_OR_PREVIOUS_DAY_SWEEP"; return false; }
      setup.stage=PA_SECONDARY_WAIT_RECLAIM;
      setup.direction=context_direction;
      setup.source_event_time=m5_rates[1].time;
      setup.setup_created_time=m5_rates[1].time;
      setup.reference_level=level;
      setup.pullback_extreme=extreme;
      setup.zone_low=0.0; setup.zone_high=0.0; setup.bars_waiting=0;
      setup.setup_id=PA_MakeSecondarySetupId(symbol,PA_STRATEGY_SWEEP_RECLAIM_MSS,
         context_direction,setup.source_event_time,level);
      const bool reclaimed=context_direction>0 ? m5_rates[1].close>level : m5_rates[1].close<level;
      if(reclaimed)
        { setup.stage=PA_SECONDARY_WAIT_MSS; signal.rejection_reason="MODEL_B2_SAME_BAR_RECLAIM_WAIT_MSS"; }
      else signal.rejection_reason="MODEL_B2_SWEEP_CAPTURED_WAIT_RECLAIM";
      return false;
     }

   if(setup.direction!=context_direction)
     { PA_ResetSecondarySetup(setup); signal.rejection_reason="MODEL_B2_CONTEXT_DIRECTION_INVALIDATED"; return false; }
   if(m5_rates[1].time<=setup.source_event_time)
     { signal.rejection_reason="MODEL_B2_WAITING_FOR_NEXT_CLOSED_BAR"; return false; }
   setup.bars_waiting++;
   if(setup.bars_waiting>12)
     { PA_ResetSecondarySetup(setup); signal.rejection_reason="MODEL_B2_SETUP_EXPIRED"; return false; }
   if((setup.direction>0 && m5_rates[1].low<setup.pullback_extreme) ||
      (setup.direction<0 && m5_rates[1].high>setup.pullback_extreme))
     { PA_ResetSecondarySetup(setup); signal.rejection_reason="MODEL_B2_SWEEP_EXTREME_BREACHED"; return false; }

   if(setup.stage==PA_SECONDARY_WAIT_RECLAIM)
     {
      const bool reclaimed=setup.direction>0 ? m5_rates[1].close>setup.reference_level
                                              : m5_rates[1].close<setup.reference_level;
      if(reclaimed)
        { setup.stage=PA_SECONDARY_WAIT_MSS; setup.setup_created_time=m5_rates[1].time;
          signal.rejection_reason="MODEL_B2_RECLAIM_CONFIRMED_WAIT_MSS"; }
      else if(setup.bars_waiting>=2)
        { PA_ResetSecondarySetup(setup); signal.rejection_reason="MODEL_B2_RECLAIM_DEADLINE_MISSED"; }
      else signal.rejection_reason="MODEL_B2_WAITING_FOR_RECLAIM";
      return false;
     }
   if(setup.stage==PA_SECONDARY_WAIT_MSS)
     {
      if(m5_rates[1].time<=setup.setup_created_time)
        { signal.rejection_reason="MODEL_B2_RECLAIM_CANDLE_CANNOT_BE_MSS"; return false; }
      const bool opposite_mss=(setup.direction>0 &&
         m5_snapshot.break_type==PA_BREAK_CHOCH_BEARISH) ||
         (setup.direction<0 && m5_snapshot.break_type==PA_BREAK_CHOCH_BULLISH);
      if(opposite_mss)
        { PA_ResetSecondarySetup(setup); signal.rejection_reason="MODEL_B2_OPPOSITE_MSS_INVALIDATED"; return false; }
      const bool mss=(m5_snapshot.signal_bar_time==m5_rates[1].time) &&
         ((setup.direction>0 && m5_snapshot.break_type==PA_BREAK_CHOCH_BULLISH) ||
          (setup.direction<0 && m5_snapshot.break_type==PA_BREAK_CHOCH_BEARISH));
      if(!mss) { signal.rejection_reason="MODEL_B2_WAITING_FOR_DISTINCT_MSS"; return false; }
      setup.stage=PA_SECONDARY_WAIT_CONFIRMATION;
      setup.setup_created_time=m5_rates[1].time;
      signal.rejection_reason="MODEL_B2_MSS_CONFIRMED_WAIT_DIRECTIONAL_CANDLE";
      return false;
     }
   if(setup.stage==PA_SECONDARY_WAIT_CONFIRMATION)
     {
      if(m5_rates[1].time<=setup.setup_created_time) return false;
      const double mid=(m5_rates[1].high+m5_rates[1].low)/2.0;
      const bool confirmed=setup.direction>0
         ? (m5_rates[1].close>m5_rates[1].open && m5_rates[1].close>mid)
         : (m5_rates[1].close<m5_rates[1].open && m5_rates[1].close<mid);
      if(!confirmed) { signal.rejection_reason="MODEL_B2_WAITING_FOR_DIRECTIONAL_CONFIRMATION"; return false; }
      if(setup.direction>0) setup.zone_high=m5_rates[1].high;
      else setup.zone_low=m5_rates[1].low;
      setup.stage=PA_SECONDARY_WAIT_TRIGGER;
      setup.setup_created_time=m5_rates[1].time;
      signal.rejection_reason="MODEL_B2_CONFIRMATION_CANDLE_CAPTURED_WAIT_TRIGGER";
      return false;
     }
   if(setup.stage==PA_SECONDARY_WAIT_TRIGGER)
     {
      if(m5_rates[1].time<=setup.setup_created_time) return false;
      const bool trigger=setup.direction>0
         ? (m5_rates[1].close>setup.zone_high && m5_rates[1].close>m5_rates[1].open)
         : (m5_rates[1].close<setup.zone_low && m5_rates[1].close<m5_rates[1].open);
      if(!trigger) { signal.rejection_reason="MODEL_B2_WAITING_FOR_CONFIRMATION_TRIGGER_BREAK"; return false; }
      signal.strategy=PA_STRATEGY_SWEEP_RECLAIM_MSS;
      signal.direction=setup.direction; signal.signal_bar_time=m5_rates[1].time;
      signal.source_event_time=setup.source_event_time;
      signal.reference_level=setup.reference_level;
      signal.invalidation_level=setup.pullback_extreme;
      signal.zone_low=setup.zone_low; signal.zone_high=setup.zone_high;
      signal.setup_id=setup.setup_id;
      signal.rejection_reason="MODEL_B2_SIGNAL_READY_NO_ORDER_SENT";
      PA_ResetSecondarySetup(setup);
      return true;
     }
   signal.rejection_reason="MODEL_B2_UNKNOWN_STAGE";
   PA_ResetSecondarySetup(setup);
   return false;
  }

bool PA_EvaluateBOSOrderBlockRetest(const string symbol,
                                   const MqlRates &m5_rates[],
                                   const int m5_count,
                                   const double spread_price,
                                   const PA_StructureSnapshot &m5_snapshot,
                                   PA_SecondarySetup &setup,
                                   PA_StrategySignal &signal)
  {
   PA_ResetStrategySignal(signal);
   if(setup.stage!=PA_SECONDARY_WAIT_RETEST || m5_count<3)
      return false;
   if(m5_rates[1].time<=setup.setup_created_time)
     {
      signal.rejection_reason="WAITING_FOR_POST_BOS_M5_CANDLE";
      return false;
     }
   setup.bars_waiting++;
   if(setup.bars_waiting>36)
     {
      PA_ResetSecondarySetup(setup);
      signal.rejection_reason="BOS_OB_SETUP_EXPIRED";
      return false;
     }

   const double tolerance=MathMax(2.0*spread_price,
      0.05*PA_SecondaryATR(m5_rates,m5_count,14));
   if((setup.direction>0 && m5_rates[1].close<setup.zone_low) ||
      (setup.direction<0 && m5_rates[1].close>setup.zone_high))
     {
      PA_ResetSecondarySetup(setup);
      signal.rejection_reason="ORDER_BLOCK_INVALIDATED";
      return false;
     }
   const bool touched=(m5_rates[1].low<=setup.zone_high+tolerance &&
                       m5_rates[1].high>=setup.zone_low-tolerance);
   if(!touched)
     {
      signal.rejection_reason="WAITING_FOR_ORDER_BLOCK_RETEST";
      return false;
     }

   const bool confirmed=setup.direction>0
      ? (m5_rates[1].close>setup.zone_high &&
         PA_IsBullishM5Confirmation(m5_rates,m5_count,m5_snapshot))
      : (m5_rates[1].close<setup.zone_low &&
         PA_IsBearishM5Confirmation(m5_rates,m5_count,m5_snapshot));
   if(!confirmed)
     {
      signal.rejection_reason="ORDER_BLOCK_RETEST_NOT_CONFIRMED";
      return false;
     }

   PA_EmitSecondarySignal(symbol,PA_STRATEGY_BOS_OB_RETEST,setup,
      m5_rates[1].time,setup.direction>0?setup.zone_low:setup.zone_high,
      signal);
   PA_ResetSecondarySetup(setup);
   return true;
  }

bool PA_EvaluateBreakoutRetest(const string symbol,
                              const MqlRates &m5_rates[],
                              const int m5_count,
                              const double spread_price,
                              const PA_StructureSnapshot &m5_snapshot,
                              PA_SecondarySetup &setup,
                              PA_StrategySignal &signal)
  {
   PA_ResetStrategySignal(signal);
   if(setup.stage!=PA_SECONDARY_WAIT_RETEST || m5_count<3)
      return false;
   if(m5_rates[1].time<=setup.setup_created_time)
     {
      signal.rejection_reason="WAITING_FOR_POST_BOS_M5_CANDLE";
      return false;
     }
   setup.bars_waiting++;
   if(setup.bars_waiting>36)
     {
      PA_ResetSecondarySetup(setup);
      signal.rejection_reason="BREAKOUT_SETUP_EXPIRED";
      return false;
     }

   const double tolerance=MathMax(2.0*spread_price,
      0.10*PA_SecondaryATR(m5_rates,m5_count,14));
   const double level=setup.reference_level;
   if((setup.direction>0 && m5_rates[1].close<level-tolerance) ||
      (setup.direction<0 && m5_rates[1].close>level+tolerance))
     {
      PA_ResetSecondarySetup(setup);
      signal.rejection_reason="BREAKOUT_LEVEL_INVALIDATED";
      return false;
     }
   const bool retest=setup.direction>0
      ? (m5_rates[1].low<=level+tolerance &&
         m5_rates[1].close>level)
      : (m5_rates[1].high>=level-tolerance &&
         m5_rates[1].close<level);
   if(!retest)
     {
      signal.rejection_reason="WAITING_FOR_BREAKOUT_RETEST";
      return false;
     }

   const bool confirmed=setup.direction>0
      ? PA_IsBullishM5Confirmation(m5_rates,m5_count,m5_snapshot)
      : PA_IsBearishM5Confirmation(m5_rates,m5_count,m5_snapshot);
   if(!confirmed)
     {
      signal.rejection_reason="BREAKOUT_RETEST_NOT_CONFIRMED";
      return false;
     }

   PA_EmitSecondarySignal(symbol,PA_STRATEGY_BREAKOUT_RETEST,setup,
      m5_rates[1].time,level,signal);
   PA_ResetSecondarySetup(setup);
   return true;
  }

bool PA_EvaluateTrendPullback(const string symbol,
                              const MqlRates &m5_rates[],
                              const int m5_count,
                              const double spread_price,
                              PA_SecondarySetup &setup,
                              PA_StrategySignal &signal)
  {
   PA_ResetStrategySignal(signal);
   if(setup.stage==PA_SECONDARY_IDLE || m5_count<4 ||
      (setup.direction!=1 && setup.direction!=-1) ||
      setup.zone_high<=setup.zone_low || spread_price<0.0)
      return false;
   if(m5_rates[1].time<=setup.setup_created_time)
     {
      signal.rejection_reason="WAITING_FOR_POST_BOS_M5_CANDLE";
      return false;
     }
   setup.bars_waiting++;
   if(setup.bars_waiting>48)
     {
      PA_ResetSecondarySetup(setup);
      signal.rejection_reason="TREND_PULLBACK_SETUP_EXPIRED";
      return false;
     }
   if((setup.direction>0 && m5_rates[1].close<setup.zone_low) ||
      (setup.direction<0 && m5_rates[1].close>setup.zone_high))
     {
      PA_ResetSecondarySetup(setup);
      signal.rejection_reason="TREND_PULLBACK_ZONE_INVALIDATED";
      return false;
     }
   if(setup.stage==PA_SECONDARY_WAIT_PULLBACK)
     {
      const bool touched=(m5_rates[1].low<=setup.zone_high &&
                          m5_rates[1].high>=setup.zone_low);
      if(!touched)
        {
         signal.rejection_reason="WAITING_FOR_TREND_PULLBACK_ZONE";
         return false;
        }
      const bool rejected=setup.direction>0
         ? PA_IsBullishRejection(m5_rates[1])
         : PA_IsBearishRejection(m5_rates[1]);
      if(!rejected)
        {
         signal.rejection_reason="PULLBACK_TOUCH_WITHOUT_DIRECTIONAL_REJECTION";
         return false;
        }
      setup.stage=PA_SECONDARY_WAIT_CONTINUATION;
      setup.pullback_extreme=setup.direction>0?m5_rates[1].low:m5_rates[1].high;
      setup.setup_created_time=m5_rates[1].time;
      signal.rejection_reason="PULLBACK_REJECTION_CAPTURED_WAIT_BREAK";
      return false;
     }
   if(setup.stage==PA_SECONDARY_WAIT_CONTINUATION)
     {
      if(m5_rates[1].time<=setup.setup_created_time) return false;
      const bool bullish_break=(setup.direction>0 &&
         m5_rates[1].close>m5_rates[2].high &&
         m5_rates[1].close>m5_rates[1].open);
      const bool bearish_break=(setup.direction<0 &&
         m5_rates[1].close<m5_rates[2].low &&
         m5_rates[1].close<m5_rates[1].open);
      if(!bullish_break && !bearish_break)
        {
         signal.rejection_reason="WAITING_FOR_REJECTION_CANDLE_BREAK";
         return false;
        }
      PA_EmitSecondarySignal(symbol,PA_STRATEGY_TREND_PULLBACK,setup,
         m5_rates[1].time,setup.pullback_extreme,signal);
      PA_ResetSecondarySetup(setup);
      return true;
     }
   return false;
  }

// Higher-priority signals win only when every simultaneously qualified
// signal agrees in direction. Any opposing qualified signal means NO TRADE.
bool PA_ArbitrateStrategySignals(const PA_StrategySignal &signals[],
                                 const int count,
                                 PA_StrategySignal &selected)
  {
   PA_ResetStrategySignal(selected);
   if(count<=0)
      return false;

   int agreed_direction=0;
   int selected_index=-1;
   int selected_priority=100;

   for(int i=0;i<count;i++)
     {
      if(signals[i].strategy==PA_STRATEGY_NONE ||
         signals[i].direction==0 || signals[i].setup_id=="")
         continue;
      if(agreed_direction==0)
         agreed_direction=signals[i].direction;
      else if(agreed_direction!=signals[i].direction)
        {
         selected.rejection_reason="CONFLICTING_QUALIFIED_STRATEGY_DIRECTIONS";
         return false;
        }

      const int priority=(int)signals[i].strategy;
      if(priority<selected_priority)
        {
         selected_priority=priority;
         selected_index=i;
        }
     }

   if(selected_index<0)
      return false;
   selected=signals[selected_index];
   selected.rejection_reason="PRIORITY_SELECTED_NO_ORDER_SENT";
   return true;
  }

#endif // FOREX_AGENT_SECONDARY_STRATEGIES_MQH
