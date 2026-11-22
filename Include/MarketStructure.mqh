//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| Closed-bar price-action primitives and protected-swing state.   |
//| No trading or order-execution functions are defined here.         |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_MARKET_STRUCTURE_MQH
#define FOREX_AGENT_MARKET_STRUCTURE_MQH

enum PA_BreakType
  {
   PA_BREAK_NONE = 0,
   PA_BREAK_BOS_BULLISH,
   PA_BREAK_BOS_BEARISH,
   PA_BREAK_CHOCH_BULLISH,
   PA_BREAK_CHOCH_BEARISH
  };

struct PA_StructureSnapshot
  {
   bool         has_swing_high;
   bool         has_swing_low;
   double       swing_high;
   double       swing_low;
   datetime     swing_high_time;
   datetime     swing_low_time;
   PA_BreakType break_type;
   int          resulting_direction; // +1 bullish, -1 bearish, 0 neutral
   datetime     signal_bar_time;
   double       protected_high;
   double       protected_low;
  };

struct PA_StructureState
  {
   int      direction; // +1 bullish, -1 bearish, 0 not established
   double   latest_swing_high;
   double   latest_swing_low;
   datetime latest_swing_high_time;
   datetime latest_swing_low_time;
   double   protected_high;
   double   protected_low;
   datetime protected_high_time;
   datetime protected_low_time;
   datetime last_processed_bar_time;
   datetime last_structure_event_time;
  };

struct PA_Gap
  {
   bool     valid;
   bool     bullish;
   double   lower;
   double   upper;
   double   size;
   datetime confirmation_time;
  };

// Contract: rates is a series array; index 0 is forming, index 1 is
// the latest completed candle. Never pass a non-series array.

void PA_ResetStructureState(PA_StructureState &state)
  {
   state.direction = 0;
   state.latest_swing_high = 0.0;
   state.latest_swing_low = 0.0;
   state.latest_swing_high_time = 0;
   state.latest_swing_low_time = 0;
   state.protected_high = 0.0;
   state.protected_low = 0.0;
   state.protected_high_time = 0;
   state.protected_low_time = 0;
   state.last_processed_bar_time = 0;
   state.last_structure_event_time = 0;
  }

void PA_ResetStructureSnapshot(PA_StructureSnapshot &snapshot)
  {
   snapshot.has_swing_high = false;
   snapshot.has_swing_low = false;
   snapshot.swing_high = 0.0;
   snapshot.swing_low = 0.0;
   snapshot.swing_high_time = 0;
   snapshot.swing_low_time = 0;
   snapshot.break_type = PA_BREAK_NONE;
   snapshot.resulting_direction = 0;
   snapshot.signal_bar_time = 0;
   snapshot.protected_high = 0.0;
   snapshot.protected_low = 0.0;
  }

// Strict 3-left/3-right pivot. A pivot at shift S becomes available only
// after three newer candles have closed: S must therefore be >= 4.
bool PA_IsConfirmedSwingHigh(const MqlRates &rates[],
                             const int count,
                             const int shift)
  {
   if(shift < 4 || shift + 3 >= count)
      return false;

   const double candidate = rates[shift].high;
   for(int offset = 1; offset <= 3; offset++)
     {
      if(candidate <= rates[shift - offset].high ||
         candidate <= rates[shift + offset].high)
         return false;
     }
   return true;
  }

bool PA_IsConfirmedSwingLow(const MqlRates &rates[],
                            const int count,
                            const int shift)
  {
   if(shift < 4 || shift + 3 >= count)
      return false;

   const double candidate = rates[shift].low;
   for(int offset = 1; offset <= 3; offset++)
     {
      if(candidate >= rates[shift - offset].low ||
         candidate >= rates[shift + offset].low)
         return false;
     }
   return true;
  }

// lookback is the maximum pivot shift to inspect. Since the array is a
// series, scanning from shift 4 upward returns the most recently confirmed.
bool PA_FindLatestConfirmedSwing(const MqlRates &rates[],
                                 const int count,
                                 const int lookback,
                                 const bool find_high,
                                 double &level,
                                 datetime &pivot_time)
  {
   level = 0.0;
   pivot_time = 0;
   if(count < 8 || lookback < 4)
      return false;

   const int last_shift = (int)MathMin(lookback, count - 4);
   for(int shift = 4; shift <= last_shift; shift++)
     {
      const bool found = find_high
                         ? PA_IsConfirmedSwingHigh(rates, count, shift)
                         : PA_IsConfirmedSwingLow(rates, count, shift);
      if(found)
        {
         level = find_high ? rates[shift].high : rates[shift].low;
         pivot_time = rates[shift].time;
         return true;
        }
     }
   return false;
  }

// Stateful structure update. Call once per newly closed candle with a
// series array. It ignores duplicate/replayed bars using bar timestamps.
//
// Neutral state: a close through the latest confirmed swing establishes
// the initial direction (BOS).
// Bull state: close below protected_low is bearish CHoCH; close above the
// latest confirmed swing high is bullish BOS and refreshes protected_low.
// Bear state: symmetric behavior using protected_high/latest swing low.
//
// The caller must persist PA_StructureState across terminal restarts.
// This is a deterministic primitive; higher-level strategy logic must
// still validate H1/M15 alignment and setup-specific conditions.
bool PA_UpdateStructureState(const MqlRates &rates[],
                             const int count,
                             const int lookback,
                             PA_StructureState &state,
                             PA_StructureSnapshot &snapshot)
  {
   PA_ResetStructureSnapshot(snapshot);

   if(count < 9 || lookback < 4 || rates[1].time <= 0)
      return false;

   const datetime signal_time = rates[1].time;
   if(state.last_processed_bar_time > 0 &&
      signal_time <= state.last_processed_bar_time)
      return false;

   double new_high = 0.0;
   double new_low = 0.0;
   datetime new_high_time = 0;
   datetime new_low_time = 0;

   const bool has_high = PA_FindLatestConfirmedSwing(
      rates, count, lookback, true, new_high, new_high_time);
   const bool has_low = PA_FindLatestConfirmedSwing(
      rates, count, lookback, false, new_low, new_low_time);

   if(!has_high || !has_low)
      return false;

   // Update remembered pivots only when a genuinely newer pivot confirms.
   if(new_high_time > state.latest_swing_high_time)
     {
      state.latest_swing_high = new_high;
      state.latest_swing_high_time = new_high_time;
     }
   if(new_low_time > state.latest_swing_low_time)
     {
      state.latest_swing_low = new_low;
      state.latest_swing_low_time = new_low_time;
     }

   snapshot.has_swing_high = true;
   snapshot.has_swing_low = true;
   snapshot.swing_high = state.latest_swing_high;
   snapshot.swing_low = state.latest_swing_low;
   snapshot.swing_high_time = state.latest_swing_high_time;
   snapshot.swing_low_time = state.latest_swing_low_time;
   snapshot.signal_bar_time = signal_time;

   const double close_price = rates[1].close;

   if(state.direction == 0)
     {
      if(close_price > state.latest_swing_high)
        {
         state.direction = 1;
         state.protected_low = state.latest_swing_low;
         state.protected_low_time = state.latest_swing_low_time;
         state.last_structure_event_time = signal_time;
         snapshot.break_type = PA_BREAK_BOS_BULLISH;
        }
      else if(close_price < state.latest_swing_low)
        {
         state.direction = -1;
         state.protected_high = state.latest_swing_high;
         state.protected_high_time = state.latest_swing_high_time;
         state.last_structure_event_time = signal_time;
         snapshot.break_type = PA_BREAK_BOS_BEARISH;
        }
     }
   else if(state.direction > 0)
     {
      // A protected-low violation has priority over continuation.
      if(state.protected_low > 0.0 &&
         close_price < state.protected_low)
        {
         state.direction = -1;
         state.protected_high = state.latest_swing_high;
         state.protected_high_time = state.latest_swing_high_time;
         state.last_structure_event_time = signal_time;
         snapshot.break_type = PA_BREAK_CHOCH_BEARISH;
        }
      else if(close_price > state.latest_swing_high &&
              state.latest_swing_high_time > state.last_structure_event_time)
        {
         state.protected_low = state.latest_swing_low;
         state.protected_low_time = state.latest_swing_low_time;
         state.last_structure_event_time = signal_time;
         snapshot.break_type = PA_BREAK_BOS_BULLISH;
        }
     }
   else if(state.direction < 0)
     {
      if(state.protected_high > 0.0 &&
         close_price > state.protected_high)
        {
         state.direction = 1;
         state.protected_low = state.latest_swing_low;
         state.protected_low_time = state.latest_swing_low_time;
         state.last_structure_event_time = signal_time;
         snapshot.break_type = PA_BREAK_CHOCH_BULLISH;
        }
      else if(close_price < state.latest_swing_low &&
              state.latest_swing_low_time > state.last_structure_event_time)
        {
         state.protected_high = state.latest_swing_high;
         state.protected_high_time = state.latest_swing_high_time;
         state.last_structure_event_time = signal_time;
         snapshot.break_type = PA_BREAK_BOS_BEARISH;
        }
     }

   state.last_processed_bar_time = signal_time;
   snapshot.resulting_direction = state.direction;
   snapshot.protected_high = state.protected_high;
   snapshot.protected_low = state.protected_low;
   return true;
  }

// Bullish sweep: closed candle pierces a confirmed swing low and closes
// back above it. Bearish sweep is the inverse.
bool PA_DetectLiquiditySweep(const MqlRates &rates[],
                             const int count,
                             const double swing_level,
                             const bool bullish_sweep,
                             const double spread_price,
                             const double atr14,
                             double &sweep_extreme)
  {
   sweep_extreme = 0.0;
   if(count < 2 || swing_level <= 0.0 ||
      spread_price < 0.0 || atr14 <= 0.0)
      return false;

   const double minimum_distance = MathMax(2.0 * spread_price,
                                            0.05 * atr14);
   if(bullish_sweep)
     {
      const double distance = swing_level - rates[1].low;
      if(rates[1].low < swing_level &&
         rates[1].close > swing_level &&
         distance >= minimum_distance)
        {
         sweep_extreme = rates[1].low;
         return true;
        }
     }
   else
     {
      const double distance = rates[1].high - swing_level;
      if(rates[1].high > swing_level &&
         rates[1].close < swing_level &&
         distance >= minimum_distance)
        {
         sweep_extreme = rates[1].high;
         return true;
        }
     }
   return false;
  }

// Three-candle FVG using completed candles only:
// A = shift 3 (oldest), B = shift 2, C = shift 1 (newest).
bool PA_DetectFairValueGap(const MqlRates &rates[],
                           const int count,
                           const double spread_price,
                           const double atr14,
                           PA_Gap &gap)
  {
   gap.valid = false;
   gap.bullish = false;
   gap.lower = 0.0;
   gap.upper = 0.0;
   gap.size = 0.0;
   gap.confirmation_time = 0;

   if(count < 4 || spread_price < 0.0 || atr14 <= 0.0)
      return false;

   const double minimum_gap = MathMax(2.0 * spread_price,
                                       0.05 * atr14);
   const double bullish_size = rates[1].low - rates[3].high;
   if(bullish_size > 0.0 && bullish_size >= minimum_gap)
     {
      gap.valid = true;
      gap.bullish = true;
      gap.lower = rates[3].high;
      gap.upper = rates[1].low;
      gap.size = bullish_size;
      gap.confirmation_time = rates[1].time;
      return true;
     }

   const double bearish_size = rates[3].low - rates[1].high;
   if(bearish_size > 0.0 && bearish_size >= minimum_gap)
     {
      gap.valid = true;
      gap.bullish = false;
      gap.lower = rates[1].high;
      gap.upper = rates[3].low;
      gap.size = bearish_size;
      gap.confirmation_time = rates[1].time;
      return true;
     }
   return false;
  }

#endif // FOREX_AGENT_MARKET_STRUCTURE_MQH
