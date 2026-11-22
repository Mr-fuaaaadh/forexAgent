//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| Deterministic closed-bar price-action primitives.                |
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
   int          resulting_direction; // +1 bullish, -1 bearish, 0 unchanged/unknown
   datetime     signal_bar_time;
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

// Rates must be copied with ArraySetAsSeries(rates, true).
// Index 0 is the forming candle; all signal functions use closed bars only.

// A pivot at shift S is confirmed only after three newer closed candles
// (S-1, S-2, S-3) and three older candles (S+1, S+2, S+3) are available.
bool PA_IsConfirmedSwingHigh(const MqlRates &rates[],
                             const int count,
                             const int shift)
  {
   if(shift < 4 || shift + 3 >= count)
      return false;

   const double candidate = rates[shift].high;
   for(int offset = 1; offset <= 3; offset++)
     {
      if(candidate <= rates[shift - offset].high)
         return false;
      if(candidate <= rates[shift + offset].high)
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
      if(candidate >= rates[shift - offset].low)
         return false;
      if(candidate >= rates[shift + offset].low)
         return false;
     }
   return true;
  }

// Finds the most recent confirmed pivot in the requested closed-bar window.
// lookback is the maximum pivot shift to inspect, not a bar count from now.
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

   const int last_shift = MathMin(lookback, count - 4);
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

// prior_direction is the caller's previously established structure direction.
// +1 = bullish, -1 = bearish, 0 = unknown/neutral.
// This primitive classifies a close through the latest confirmed pivot.
// A strategy layer must decide whether that pivot is the protected swing
// for the active structure before treating the result as a full CHoCH.
bool PA_EvaluateStructure(const MqlRates &rates[],
                          const int count,
                          const int lookback,
                          const int prior_direction,
                          PA_StructureSnapshot &snapshot)
  {
   snapshot.has_swing_high = false;
   snapshot.has_swing_low = false;
   snapshot.swing_high = 0.0;
   snapshot.swing_low = 0.0;
   snapshot.swing_high_time = 0;
   snapshot.swing_low_time = 0;
   snapshot.break_type = PA_BREAK_NONE;
   snapshot.resulting_direction = prior_direction;
   snapshot.signal_bar_time = 0;

   if(count < 9 || lookback < 4)
      return false;

   snapshot.signal_bar_time = rates[1].time;
   snapshot.has_swing_high = PA_FindLatestConfirmedSwing(
      rates, count, lookback, true,
      snapshot.swing_high, snapshot.swing_high_time);
   snapshot.has_swing_low = PA_FindLatestConfirmedSwing(
      rates, count, lookback, false,
      snapshot.swing_low, snapshot.swing_low_time);

   if(!snapshot.has_swing_high || !snapshot.has_swing_low)
      return false;

   const double closed_price = rates[1].close;
   if(closed_price > snapshot.swing_high)
     {
      snapshot.break_type = (prior_direction < 0)
                            ? PA_BREAK_CHOCH_BULLISH
                            : PA_BREAK_BOS_BULLISH;
      snapshot.resulting_direction = 1;
     }
   else if(closed_price < snapshot.swing_low)
     {
      snapshot.break_type = (prior_direction > 0)
                            ? PA_BREAK_CHOCH_BEARISH
                            : PA_BREAK_BOS_BEARISH;
      snapshot.resulting_direction = -1;
     }

   return true;
  }

// Bullish sweep: closed candle's low pierces the confirmed swing low,
// then closes back above it. Bearish sweep is the inverse.
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
