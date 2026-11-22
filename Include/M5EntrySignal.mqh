//+------------------------------------------------------------------+
//| M5EntrySignal.mqh                                                 |
//| Closed-bar sweep -> CHoCH -> FVG retest signal state machine.    |
//| Emits signals only; contains no order execution.                  |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_M5_ENTRY_SIGNAL_MQH
#define FOREX_AGENT_M5_ENTRY_SIGNAL_MQH

#include "MultiTimeframeContext.mqh"

enum PA_EntrySignal
  {
   PA_ENTRY_NONE = 0,
   PA_ENTRY_BUY,
   PA_ENTRY_SELL
  };

enum PA_SetupStage
  {
   PA_SETUP_IDLE = 0,
   PA_SETUP_WAIT_CHOCH,
   PA_SETUP_WAIT_FVG,
   PA_SETUP_WAIT_RETEST
  };

struct PA_M5SetupState
  {
   PA_SetupStage stage;
   int           direction;
   datetime      sweep_time;
   double        sweep_extreme;
   double        swept_level;
   datetime      choch_time;
   datetime      fvg_time;
   double        fvg_lower;
   double        fvg_upper;
   int           bars_since_sweep;
   int           bars_since_choch;
   datetime      last_processed_bar_time;
   string        last_emitted_setup_id;
  };

struct PA_M5Signal
  {
   PA_EntrySignal signal;
   int            direction;
   datetime       signal_bar_time;
   datetime       sweep_time;
   datetime       choch_time;
   datetime       fvg_time;
   double         sweep_extreme;
   double         fvg_lower;
   double         fvg_upper;
   string         setup_id;
   string         rejection_reason;
  };

void PA_ResetM5SetupState(PA_M5SetupState &state)
  {
   state.stage = PA_SETUP_IDLE;
   state.direction = 0;
   state.sweep_time = 0;
   state.sweep_extreme = 0.0;
   state.swept_level = 0.0;
   state.choch_time = 0;
   state.fvg_time = 0;
   state.fvg_lower = 0.0;
   state.fvg_upper = 0.0;
   state.bars_since_sweep = 0;
   state.bars_since_choch = 0;
   state.last_processed_bar_time = 0;
   state.last_emitted_setup_id = "";
  }

void PA_ResetM5Signal(PA_M5Signal &signal)
  {
   signal.signal = PA_ENTRY_NONE;
   signal.direction = 0;
   signal.signal_bar_time = 0;
   signal.sweep_time = 0;
   signal.choch_time = 0;
   signal.fvg_time = 0;
   signal.sweep_extreme = 0.0;
   signal.fvg_lower = 0.0;
   signal.fvg_upper = 0.0;
   signal.setup_id = "";
   signal.rejection_reason = "";
  }

double PA_CalculateATR14(const MqlRates &rates[],const int count)
  {
   if(count < 16)
      return 0.0;

   double total = 0.0;
   for(int shift = 1; shift <= 14; shift++)
     {
      const double previous_close = rates[shift+1].close;
      const double true_range = MathMax(rates[shift].high-rates[shift].low,
         MathMax(MathAbs(rates[shift].high-previous_close),
                 MathAbs(rates[shift].low-previous_close)));
      total += true_range;
     }
   return total/14.0;
  }

string PA_MakeSetupId(const string symbol,
                      const int direction,
                      const datetime sweep_time,
                      const datetime choch_time,
                      const datetime fvg_time)
  {
   return StringFormat("%s|%s|%I64d|%I64d|%I64d",
                       symbol,
                       direction > 0 ? "BUY" : "SELL",
                       (long)sweep_time,
                       (long)choch_time,
                       (long)fvg_time);
  }

uint PA_M5SetupIdHash(const string setup_id)
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(setup_id);i++)
     {
      hash^=(uint)StringGetCharacter(setup_id,i);
      hash=(uint)(hash*16777619);
     }
   return hash;
  }

void PA_RejectM5Setup(PA_M5SetupState &state,const string reason,
                      PA_M5Signal &signal)
  {
   signal.rejection_reason = reason;
   state.stage = PA_SETUP_IDLE;
   state.direction = 0;
   state.sweep_time = 0;
   state.sweep_extreme = 0.0;
   state.swept_level = 0.0;
   state.choch_time = 0;
   state.fvg_time = 0;
   state.fvg_lower = 0.0;
   state.fvg_upper = 0.0;
   state.bars_since_sweep = 0;
   state.bars_since_choch = 0;
  }

// Call once for each newly closed M5 candle. rates must be a series array:
// [0] forming candle, [1] latest closed candle. The caller supplies the
// current H1/M15 context, spread in price units, and persistent state.
bool PA_EvaluateM5EntrySignal(const string symbol,
                              const MqlRates &rates[],
                              const int count,
                              const double spread_price,
                              const PA_MultiTimeframeSnapshot &context,
                              PA_StructureState &m5_structure,
                              PA_M5SetupState &setup,
                              PA_M5Signal &signal,
                              const int maximum_setup_bars=12)
  {
   PA_ResetM5Signal(signal);

   if(symbol == "" || count < 20 || spread_price < 0.0 ||
      maximum_setup_bars < 3 || rates[1].time <= 0)
     {
      signal.rejection_reason = "INVALID_INPUT_OR_INSUFFICIENT_HISTORY";
      return false;
     }

   const datetime bar_time = rates[1].time;
   if(setup.last_processed_bar_time > 0 &&
      bar_time <= setup.last_processed_bar_time)
     {
      signal.rejection_reason = "DUPLICATE_OR_OLD_M5_BAR";
      return false;
     }
   setup.last_processed_bar_time = bar_time;

   const bool bullish_context =
      (context.context == PA_CONTEXT_BULLISH_ALIGNED ||
       context.context == PA_CONTEXT_NEUTRAL_REVERSAL_BULLISH);
   const bool bearish_context =
      (context.context == PA_CONTEXT_BEARISH_ALIGNED ||
       context.context == PA_CONTEXT_NEUTRAL_REVERSAL_BEARISH);

   if(!bullish_context && !bearish_context)
     {
      if(setup.stage != PA_SETUP_IDLE)
         PA_RejectM5Setup(setup,"H1_M15_CONTEXT_NOT_ALIGNED",signal);
      else
         signal.rejection_reason = "H1_M15_CONTEXT_NOT_ALIGNED";
      return true;
     }

   PA_StructureSnapshot structure_snapshot;
   if(!PA_UpdateStructureState(rates,count,40,m5_structure,structure_snapshot))
     {
      signal.rejection_reason = "M5_STRUCTURE_NOT_READY";
      return true;
     }

   const double atr14 = PA_CalculateATR14(rates,count);
   if(atr14 <= 0.0)
     {
      signal.rejection_reason = "ATR_NOT_READY";
      return true;
     }

   if(setup.stage != PA_SETUP_IDLE)
     {
      setup.bars_since_sweep++;
      if(setup.stage >= PA_SETUP_WAIT_FVG)
         setup.bars_since_choch++;
      if(setup.bars_since_sweep > maximum_setup_bars ||
         setup.bars_since_choch > maximum_setup_bars)
        {
         PA_RejectM5Setup(setup,"SETUP_EXPIRED",signal);
         return true;
        }
     }

   // If a completed M5 CHoCH points against the pending setup, invalidate it.
   if(setup.stage != PA_SETUP_IDLE &&
      ((setup.direction > 0 &&
        structure_snapshot.break_type == PA_BREAK_CHOCH_BEARISH) ||
       (setup.direction < 0 &&
        structure_snapshot.break_type == PA_BREAK_CHOCH_BULLISH)))
     {
      PA_RejectM5Setup(setup,"OPPOSITE_M5_CHOCH",signal);
      return true;
     }

   if(setup.stage == PA_SETUP_IDLE)
     {
      double extreme = 0.0;
      if(bullish_context &&
         structure_snapshot.has_swing_low &&
         PA_DetectLiquiditySweep(rates,count,structure_snapshot.swing_low,
                                 true,spread_price,atr14,extreme))
        {
         setup.stage = PA_SETUP_WAIT_CHOCH;
         setup.direction = 1;
         setup.sweep_time = bar_time;
         setup.sweep_extreme = extreme;
         setup.swept_level = structure_snapshot.swing_low;
         setup.bars_since_sweep = 0;
         signal.rejection_reason = "BULLISH_SWEEP_CAPTURED_WAIT_CHOCH";
         return true;
        }

      if(bearish_context &&
         structure_snapshot.has_swing_high &&
         PA_DetectLiquiditySweep(rates,count,structure_snapshot.swing_high,
                                 false,spread_price,atr14,extreme))
        {
         setup.stage = PA_SETUP_WAIT_CHOCH;
         setup.direction = -1;
         setup.sweep_time = bar_time;
         setup.sweep_extreme = extreme;
         setup.swept_level = structure_snapshot.swing_high;
         setup.bars_since_sweep = 0;
         signal.rejection_reason = "BEARISH_SWEEP_CAPTURED_WAIT_CHOCH";
         return true;
        }

      signal.rejection_reason = "NO_QUALIFIED_LIQUIDITY_SWEEP";
      return true;
     }

   // Do not accept a CHoCH on the same candle as the sweep. It must be a
   // later completed candle and must be reported by the structure engine.
   if(setup.stage == PA_SETUP_WAIT_CHOCH)
     {
      if(bar_time <= setup.sweep_time)
         return true;

      const bool choch_confirmed =
         (setup.direction > 0 &&
          structure_snapshot.break_type == PA_BREAK_CHOCH_BULLISH) ||
         (setup.direction < 0 &&
          structure_snapshot.break_type == PA_BREAK_CHOCH_BEARISH);
      if(choch_confirmed)
        {
         setup.stage = PA_SETUP_WAIT_FVG;
         setup.choch_time = bar_time;
         setup.bars_since_choch = 0;
         signal.rejection_reason = "CHOCH_CONFIRMED_WAIT_FVG";
        }
      else
         signal.rejection_reason = "WAITING_FOR_M5_CHOCH";
      return true;
     }

   if(setup.stage == PA_SETUP_WAIT_FVG)
     {
      if(bar_time <= setup.choch_time)
         return true;

      PA_Gap gap;
      if(PA_DetectFairValueGap(rates,count,spread_price,atr14,gap) &&
         gap.bullish == (setup.direction > 0))
        {
         setup.stage = PA_SETUP_WAIT_RETEST;
         setup.fvg_time = gap.confirmation_time;
         setup.fvg_lower = gap.lower;
         setup.fvg_upper = gap.upper;
         signal.rejection_reason = "FVG_CONFIRMED_WAIT_RETEST";
        }
      else
         signal.rejection_reason = "WAITING_FOR_DIRECTIONAL_FVG";
      return true;
     }

   if(setup.stage == PA_SETUP_WAIT_RETEST)
     {
      if(bar_time <= setup.fvg_time)
         return true;

      bool retest_rejection = false;
      if(setup.direction > 0)
         retest_rejection = (rates[1].low <= setup.fvg_upper &&
                             rates[1].close > setup.fvg_upper &&
                             rates[1].close > rates[1].open);
      else
         retest_rejection = (rates[1].high >= setup.fvg_lower &&
                             rates[1].close < setup.fvg_lower &&
                             rates[1].close < rates[1].open);

      if(!retest_rejection)
        {
         signal.rejection_reason = "WAITING_FOR_FVG_RETEST_REJECTION";
         return true;
        }

      const string setup_id = PA_MakeSetupId(symbol,setup.direction,
                                             setup.sweep_time,
                                             setup.choch_time,
                                             setup.fvg_time);
      const string persisted_id_marker=StringFormat("HASH:%I64d",(long)PA_M5SetupIdHash(setup_id));
      if(setup_id == setup.last_emitted_setup_id ||
         persisted_id_marker == setup.last_emitted_setup_id)
        {
         PA_RejectM5Setup(setup,"DUPLICATE_SETUP_ID",signal);
         return true;
        }

      signal.signal = setup.direction > 0 ? PA_ENTRY_BUY : PA_ENTRY_SELL;
      signal.direction = setup.direction;
      signal.signal_bar_time = bar_time;
      signal.sweep_time = setup.sweep_time;
      signal.choch_time = setup.choch_time;
      signal.fvg_time = setup.fvg_time;
      signal.sweep_extreme = setup.sweep_extreme;
      signal.fvg_lower = setup.fvg_lower;
      signal.fvg_upper = setup.fvg_upper;
      signal.setup_id = setup_id;
      signal.rejection_reason = "SIGNAL_READY_NO_ORDER_SENT";
      setup.last_emitted_setup_id = setup_id;
      PA_RejectM5Setup(setup,"SIGNAL_EMITTED",signal);
      return true;
     }

   signal.rejection_reason = "UNKNOWN_SETUP_STAGE";
   PA_ResetM5SetupState(setup);
   return false;
  }

#endif // FOREX_AGENT_M5_ENTRY_SIGNAL_MQH
