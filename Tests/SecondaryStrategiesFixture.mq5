//+------------------------------------------------------------------+
//| SecondaryStrategiesFixture.mq5                                   |
//| Synthetic tests for BOS/OB, breakout, continuation and priority.  |
//| No orders are ever sent.                                          |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "..\Include\SecondaryStrategyRuntime.mqh"

int g_passed=0;
int g_failed=0;

void Check(const string name,const bool condition)
  {
   if(condition)
     {
      g_passed++;
      Print("PASS: ",name);
     }
   else
     {
      g_failed++;
      Print("FAIL: ",name);
     }
  }

void BuildM5(MqlRates &rates[],const datetime latest_time)
  {
   ArrayResize(rates,60);
   ArraySetAsSeries(rates,true);
   for(int i=0;i<60;i++)
     {
      rates[i].time=latest_time-(datetime)((i-1)*300);
      rates[i].open=20.0;
      rates[i].high=22.0;
      rates[i].low=18.0;
      rates[i].close=20.0;
      rates[i].tick_volume=100;
      rates[i].spread=5;
      rates[i].real_volume=100;
     }
  }

void BuildBullishH1(MqlRates &rates[],const datetime latest_time)
  {
   ArrayResize(rates,40);
   ArraySetAsSeries(rates,true);
   for(int i=0;i<40;i++)
     {
      rates[i].time=latest_time-(datetime)((i-1)*3600);
      rates[i].open=21.0; rates[i].high=25.0;
      rates[i].low=20.0; rates[i].close=22.0;
      rates[i].tick_volume=100; rates[i].spread=10;
      rates[i].real_volume=100;
     }
   rates[14].high=26.0; rates[12].low=14.0;
   rates[8].high=28.0; rates[6].low=17.0;
  }

void OnStart()
  {
   MqlRates rates[];
   PA_StructureSnapshot snapshot;
   PA_StrategySignal signal;
   PA_ResetStructureSnapshot(snapshot);
   snapshot.break_type=PA_BREAK_CHOCH_BULLISH;
   snapshot.resulting_direction=1;

   const datetime now=TimeCurrent();
   BuildM5(rates,now);
   MqlRates h1_rates[];
   BuildBullishH1(h1_rates,now);
   Check("H1 HH/HL sequence qualifies bullish Model A",
         PA_HasConfirmedH1TrendStructure(h1_rates,ArraySize(h1_rates),1));
   Check("H1 HH/HL sequence does not qualify bearish Model A",
         !PA_HasConfirmedH1TrendStructure(h1_rates,ArraySize(h1_rates),-1));

   // Confirm that a new M15 BOS captures all three independent setup types.
   MqlRates m15_rates[];
   ArrayResize(m15_rates,40);
   ArraySetAsSeries(m15_rates,true);
   for(int i=0;i<40;i++)
     {
      m15_rates[i].time=now-(datetime)((i-1)*900);
      m15_rates[i].open=20.0;
      m15_rates[i].high=23.0;
      m15_rates[i].low=19.0;
      m15_rates[i].close=21.0;
      m15_rates[i].tick_volume=100;
      m15_rates[i].spread=5;
      m15_rates[i].real_volume=100;
     }
   m15_rates[2].open=22.0;
   m15_rates[2].close=20.0;
   m15_rates[2].high=22.5;
   m15_rates[2].low=19.0;
   m15_rates[1].open=20.0;
   m15_rates[1].close=26.0;
   m15_rates[1].high=27.0;
   m15_rates[1].low=19.5;

   PA_StructureState m15_state;
   PA_ResetStructureState(m15_state);
   m15_state.direction=1;
   m15_state.latest_swing_high=25.0;
   m15_state.latest_swing_low=15.0;
   m15_state.latest_swing_high_time=now-3600;
   m15_state.latest_swing_low_time=now-5400;
   m15_state.last_structure_event_time=m15_rates[1].time;
   m15_state.last_processed_bar_time=m15_rates[1].time;
   m15_state.last_break_type=PA_BREAK_BOS_BULLISH;

   PA_MultiTimeframeSnapshot context;
   context.context=PA_CONTEXT_BULLISH_ALIGNED;
   context.h1_direction=1;
   context.m15_direction=1;
   context.h1_bar_time=now-3600;
   context.m15_bar_time=m15_rates[1].time;
   context.m15_confirmed_reversal_time=0;
   context.h1_last_break=PA_BREAK_BOS_BULLISH;
   context.m15_last_break=PA_BREAK_BOS_BULLISH;

   PA_SecondaryStrategyState captured;
   PA_ResetSecondaryStrategyState(captured);
   PA_CaptureM15BOS(_Symbol,h1_rates,ArraySize(h1_rates),
                    m15_rates,ArraySize(m15_rates),
                    m15_state,context,captured);
   Check("M15 BOS captures OB, breakout and continuation setups",
         captured.order_block.stage==PA_SECONDARY_WAIT_RETEST &&
         captured.breakout.stage==PA_SECONDARY_WAIT_RETEST &&
         captured.continuation.stage==PA_SECONDARY_WAIT_PULLBACK &&
         captured.continuation.zone_low<captured.continuation.reference_level &&
         captured.continuation.zone_high>captured.continuation.reference_level);

   PA_CaptureM15BOS(_Symbol,h1_rates,ArraySize(h1_rates),
                    m15_rates,ArraySize(m15_rates),
                    m15_state,context,captured);
   Check("same M15 BOS event is not captured twice",
         captured.last_seen_m15_event_time==m15_state.last_structure_event_time);

   const bool same_m15_close_blocked=PA_EvaluateBOSOrderBlockRetest(
      _Symbol,rates,ArraySize(rates),0.05,snapshot,
      captured.order_block,signal);
   Check("OB retest cannot trigger on the M15 BOS closing candle",
         !same_m15_close_blocked &&
         signal.rejection_reason=="WAITING_FOR_POST_BOS_M5_CANDLE");

   // BOS -> order-block retest.
   PA_SecondarySetup ob;
   PA_ResetSecondarySetup(ob);
   ob.stage=PA_SECONDARY_WAIT_RETEST;
   ob.direction=1;
   ob.source_event_time=now-1800;
   ob.zone_low=19.0;
   ob.zone_high=21.0;
   ob.reference_level=21.0;
   rates[1].open=20.0;
   rates[1].low=18.0;
   rates[1].high=23.0;
   rates[1].close=22.0;
   const bool ob_ok=PA_EvaluateBOSOrderBlockRetest(_Symbol,rates,
      ArraySize(rates),0.05,snapshot,ob,signal);
   Check("BOS order-block retest emits bullish signal",
         ob_ok && signal.strategy==PA_STRATEGY_BOS_OB_RETEST &&
         signal.direction==1 && signal.setup_id!="" &&
         signal.rejection_reason=="SIGNAL_READY_NO_ORDER_SENT");

   // Breakout -> retest of the M15 breakout level.
   PA_SecondarySetup breakout;
   PA_ResetSecondarySetup(breakout);
   breakout.stage=PA_SECONDARY_WAIT_RETEST;
   breakout.direction=1;
   breakout.source_event_time=now-1800;
   breakout.reference_level=20.0;
   rates[1].open=21.5;
   rates[1].low=19.8;
   rates[1].high=22.5;
   rates[1].close=22.0;
   const bool breakout_ok=PA_EvaluateBreakoutRetest(_Symbol,rates,
      ArraySize(rates),0.05,snapshot,breakout,signal);
   Check("breakout retest emits bullish signal",
         breakout_ok && signal.strategy==PA_STRATEGY_BREAKOUT_RETEST &&
         signal.direction==1 && signal.setup_id!="");

   // Model A: a rejection inside the frozen M15 ATR band, followed by
   // a separate completed M5 close above the rejection candle's high.
   BuildM5(rates,now);
   PA_SecondarySetup trend;
   PA_ResetSecondarySetup(trend);
   trend.stage=PA_SECONDARY_WAIT_PULLBACK;
   trend.direction=1;
   trend.source_event_time=now-1800;
   trend.setup_created_time=now-900;
   trend.reference_level=20.0;
   trend.zone_low=19.7;
   trend.zone_high=20.3;
   rates[1].open=20.5; rates[1].low=19.9;
   rates[1].high=21.0; rates[1].close=20.8;
   const bool pullback_seen=PA_EvaluateTrendPullback(_Symbol,rates,
      ArraySize(rates),0.05,trend,signal);
   Check("Model A captures directional rejection inside pullback band",
         !pullback_seen && trend.stage==PA_SECONDARY_WAIT_CONTINUATION &&
         trend.pullback_extreme==19.9);

   rates[2]=rates[1];
   rates[1].time=rates[2].time+300;
   rates[1].open=20.8; rates[1].low=20.0;
   rates[1].high=21.4; rates[1].close=21.2;
   const bool continuation_ok=PA_EvaluateTrendPullback(_Symbol,rates,
      ArraySize(rates),0.05,trend,signal);
   Check("Model A emits only after later close breaks rejection high",
         continuation_ok && signal.strategy==PA_STRATEGY_TREND_PULLBACK &&
         signal.direction==1 && signal.setup_id!="" &&
         signal.invalidation_level==19.9);

   PA_SecondarySetup no_rejection;
   PA_ResetSecondarySetup(no_rejection);
   no_rejection.stage=PA_SECONDARY_WAIT_PULLBACK;
   no_rejection.direction=1;
   no_rejection.source_event_time=now-1800;
   no_rejection.setup_created_time=now-900;
   no_rejection.reference_level=20.0;
   no_rejection.zone_low=19.7;
   no_rejection.zone_high=20.3;
   BuildM5(rates,now);
   rates[1].open=20.0; rates[1].low=19.9;
   rates[1].high=21.0; rates[1].close=20.1;
   const bool no_reject_signal=PA_EvaluateTrendPullback(_Symbol,rates,
      ArraySize(rates),0.05,no_rejection,signal);
   Check("Model A rejects zone touch without directional rejection",
         !no_reject_signal && no_rejection.stage==PA_SECONDARY_WAIT_PULLBACK &&
         signal.rejection_reason=="PULLBACK_TOUCH_WITHOUT_DIRECTIONAL_REJECTION");

   // Same-direction candidates resolve by priority: BOS/OB before breakout.
   PA_StrategySignal candidates[3];
   for(int i=0;i<3;i++)
      PA_ResetStrategySignal(candidates[i]);
   candidates[0].strategy=PA_STRATEGY_BREAKOUT_RETEST;
   candidates[0].direction=1;
   candidates[0].setup_id="breakout";
   candidates[1].strategy=PA_STRATEGY_BOS_OB_RETEST;
   candidates[1].direction=1;
   candidates[1].setup_id="ob";
   const bool priority_ok=PA_ArbitrateStrategySignals(candidates,2,signal);
   Check("same-direction signals choose BOS/OB higher priority",
         priority_ok && signal.strategy==PA_STRATEGY_BOS_OB_RETEST);

   // Any opposing qualified setup blocks all strategy signals.
   candidates[2].strategy=PA_STRATEGY_TREND_PULLBACK;
   candidates[2].direction=-1;
   candidates[2].setup_id="short";
   const bool conflict_ok=PA_ArbitrateStrategySignals(candidates,3,signal);
   Check("conflicting qualified strategies reject all signals",
         !conflict_ok &&
         signal.rejection_reason=="CONFLICTING_QUALIFIED_STRATEGY_DIRECTIONS");

   // Primary sweep strategy has priority over all secondary strategies.
   PA_M5Signal primary;
   PA_ResetM5Signal(primary);
   primary.signal=PA_ENTRY_BUY;
   primary.direction=1;
   primary.signal_bar_time=now;
   primary.sweep_time=now-900;
   primary.setup_id="primary";
   PA_ResetStrategySignal(candidates[0]);
   candidates[0].strategy=PA_STRATEGY_BOS_OB_RETEST;
   candidates[0].direction=1;
   candidates[0].setup_id="ob";
   const bool all_ok=PA_ArbitrateAllStrategies(primary,candidates,1,signal);
   Check("primary sweep strategy outranks secondary strategies",
         all_ok && signal.strategy==PA_STRATEGY_SWEEP_CHOCH_FVG);

   // Persistence round trip.
   PA_SecondaryStrategyState state,saved_state;
   PA_ResetSecondaryStrategyState(state);
   state.last_processed_m5_bar_time=now;
   state.last_seen_m15_event_time=now-900;
   state.order_block.stage=PA_SECONDARY_WAIT_RETEST;
   state.order_block.direction=1;
   state.order_block.source_event_time=now-900;
   state.order_block.zone_low=19.0;
   state.order_block.zone_high=21.0;
   state.order_block.reference_level=21.0;
   const long magic=99007861;
   const bool saved=PA_SaveSecondaryStrategyState(_Symbol,magic,state);
   const bool loaded=PA_LoadSecondaryStrategyState(_Symbol,magic,saved_state);
   Check("secondary setup state survives persistence round-trip",
         saved && loaded &&
         saved_state.order_block.stage==PA_SECONDARY_WAIT_RETEST &&
         saved_state.order_block.direction==1 &&
         saved_state.last_processed_m5_bar_time==now);

   Print("Secondary strategy fixtures complete. Passed=",g_passed,
         " Failed=",g_failed);
  }
