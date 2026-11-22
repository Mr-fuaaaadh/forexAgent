//+------------------------------------------------------------------+
//| MultiTimeframeContext.mqh                                        |
//| H1 bias + M15 structure state and safe directional arbitration.  |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_MULTI_TIMEFRAME_CONTEXT_MQH
#define FOREX_AGENT_MULTI_TIMEFRAME_CONTEXT_MQH

#include "MarketStructure.mqh"
#include "StructurePersistence.mqh"

enum PA_TradeContext
  {
   PA_CONTEXT_UNAVAILABLE = 0,
   PA_CONTEXT_NO_TRADE,
   PA_CONTEXT_BULLISH_ALIGNED,
   PA_CONTEXT_BEARISH_ALIGNED,
   PA_CONTEXT_NEUTRAL_REVERSAL_BULLISH,
   PA_CONTEXT_NEUTRAL_REVERSAL_BEARISH
  };

struct PA_MultiTimeframeSnapshot
  {
   PA_TradeContext context;
   int             h1_direction;
   int             m15_direction;
   PA_BreakType    h1_last_break;
   PA_BreakType    m15_last_break;
   datetime        h1_bar_time;
   datetime        m15_bar_time;
   datetime        m15_confirmed_reversal_time;
  };

// Process closed candles chronologically. For each historical signal,
// build a series window whose index 1 is that signal and whose index 0 is
// the next candle. The structure function never reads index 0 for signals.
bool PA_AdvanceTimeframeState(const MqlRates &rates[],
                              const int count,
                              const int lookback,
                              const datetime after_time,
                              PA_StructureState &state)
  {
   if(count < 12 || lookback < 4)
      return false;

   int oldest_unprocessed_shift = 0;
   for(int shift = count - 8; shift >= 1; shift--)
     {
      if(after_time <= 0 || rates[shift].time > after_time)
        {
         oldest_unprocessed_shift = shift;
         break;
        }
     }

   if(oldest_unprocessed_shift == 0)
      return (state.last_processed_bar_time > 0);

   for(int signal_shift = oldest_unprocessed_shift;
       signal_shift >= 1; signal_shift--)
     {
      if(after_time > 0 && rates[signal_shift].time <= after_time)
         continue;

      const int window_count = count - signal_shift + 1;
      MqlRates window[];
      ArrayResize(window,window_count);
      ArraySetAsSeries(window,true);

      for(int i = 0; i < window_count; i++)
         window[i] = rates[signal_shift - 1 + i];

      PA_StructureSnapshot ignored;
      if(!PA_UpdateStructureState(window,window_count,lookback,state,ignored))
        {
         // During a full rebuild, early candles may not yet have both a
         // confirmed swing high and swing low. The structure engine has
         // retained any one-sided pivot it found; continue forward until
         // both anchors exist. Once anchors exist, an unprocessed failure
         // is a genuine data/state error and must fail closed.
         if(state.latest_swing_high_time <= 0 ||
            state.latest_swing_low_time <= 0)
            continue;

         if(state.last_processed_bar_time < rates[signal_shift].time)
            return false;
        }
     }
   return (state.last_processed_bar_time > 0);
  }

bool PA_RebuildTimeframeState(const MqlRates &rates[],
                              const int count,
                              const int lookback,
                              PA_StructureState &state)
  {
   PA_ResetStructureState(state);
   return PA_AdvanceTimeframeState(rates,count,lookback,0,state);
  }

// Load saved state or reconstruct it. Then advance exactly once if a new
// closed candle exists and persist the result. No order execution occurs.
bool PA_UpdateTimeframeState(const string symbol,
                             const ENUM_TIMEFRAMES timeframe,
                             const long magic_number,
                             const int history_bars,
                             const int swing_lookback,
                             PA_StructureState &state,
                             PA_StructureSnapshot &snapshot)
  {
   if(symbol == "" || magic_number <= 0 ||
      history_bars < 32 || swing_lookback < 4)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   const int copied = CopyRates(symbol,timeframe,0,history_bars,rates);
   if(copied < 12)
      return false;

   bool restored = PA_LoadStructureState(symbol,timeframe,magic_number,state);
   if(restored &&
      (state.last_processed_bar_time < rates[copied-1].time ||
       state.last_processed_bar_time > rates[1].time))
      restored = false;

   if(!restored)
     {
      if(!PA_RebuildTimeframeState(rates,copied,swing_lookback,state))
         return false;
     }
   else
     {
      if(!PA_AdvanceTimeframeState(rates,copied,swing_lookback,
                                   state.last_processed_bar_time,state))
         return false;
     }

   PA_ResetStructureSnapshot(snapshot);
   snapshot.resulting_direction = state.direction;
   snapshot.break_type = state.last_break_type;
   snapshot.signal_bar_time = state.last_processed_bar_time;
   snapshot.protected_high = state.protected_high;
   snapshot.protected_low = state.protected_low;
   snapshot.has_swing_high = (state.latest_swing_high_time > 0);
   snapshot.has_swing_low = (state.latest_swing_low_time > 0);
   snapshot.swing_high = state.latest_swing_high;
   snapshot.swing_low = state.latest_swing_low;
   snapshot.swing_high_time = state.latest_swing_high_time;
   snapshot.swing_low_time = state.latest_swing_low_time;

   if(!PA_SaveStructureState(symbol,timeframe,magic_number,state))
      return false;
   return true;
  }

// Strict direction arbitration:
// - H1 and M15 must agree before normal aligned context is permitted.
// - A countertrend M15 direction against a non-neutral H1 is blocked.
// - If H1 is neutral, M15 may qualify only after its own CHoCH and a
//   subsequent BOS in the reversal direction.
// - Conflicting or unavailable data always means no trade.
PA_TradeContext PA_ResolveMultiTimeframeContext(
   const PA_StructureState &h1_state,
   const PA_StructureState &m15_state)
  {
   if(h1_state.last_processed_bar_time <= 0 ||
      m15_state.last_processed_bar_time <= 0)
      return PA_CONTEXT_UNAVAILABLE;

   if(h1_state.direction > 0 && m15_state.direction > 0)
      return PA_CONTEXT_BULLISH_ALIGNED;

   if(h1_state.direction < 0 && m15_state.direction < 0)
      return PA_CONTEXT_BEARISH_ALIGNED;

   if(h1_state.direction == 0)
     {
      if(m15_state.confirmed_reversal_direction > 0 &&
         m15_state.confirmed_reversal_time > m15_state.reversal_choch_time)
         return PA_CONTEXT_NEUTRAL_REVERSAL_BULLISH;

      if(m15_state.confirmed_reversal_direction < 0 &&
         m15_state.confirmed_reversal_time > m15_state.reversal_choch_time)
         return PA_CONTEXT_NEUTRAL_REVERSAL_BEARISH;
     }

   return PA_CONTEXT_NO_TRADE;
  }

bool PA_BuildMultiTimeframeSnapshot(
   const PA_StructureState &h1_state,
   const PA_StructureState &m15_state,
   PA_MultiTimeframeSnapshot &snapshot)
  {
   snapshot.context = PA_CONTEXT_UNAVAILABLE;
   snapshot.h1_direction = h1_state.direction;
   snapshot.m15_direction = m15_state.direction;
   snapshot.h1_last_break = h1_state.last_break_type;
   snapshot.m15_last_break = m15_state.last_break_type;
   snapshot.h1_bar_time = h1_state.last_processed_bar_time;
   snapshot.m15_bar_time = m15_state.last_processed_bar_time;
   snapshot.m15_confirmed_reversal_time = m15_state.confirmed_reversal_time;

   snapshot.context = PA_ResolveMultiTimeframeContext(h1_state,m15_state);
   return (snapshot.context != PA_CONTEXT_UNAVAILABLE);
  }

#endif // FOREX_AGENT_MULTI_TIMEFRAME_CONTEXT_MQH
