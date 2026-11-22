# Market structure engine

## Current module
`Include/MarketStructure.mqh` contains pure MQL5 primitives for:
- 3-left/3-right confirmed swing highs and lows
- Latest confirmed swing lookup
- Closed-bar close-through-pivot classification as BOS or CHoCH candidate
- Liquidity sweep detection with spread/ATR minimum distance
- Three-completed-candle FVG detection

It contains no order placement or position-management code.

## Series-array contract
Callers must set rates as a series array (`ArraySetAsSeries(rates, true)`), so index 0 is the current forming candle and index 1 is the latest completed candle. Provide enough history and check the return value of `CopyRates`.

A pivot at shift S is only confirmed when the three newer bars at S-1 through S-3 are closed. The implementation requires S >= 4, preventing a forming bar from participating in confirmation.

## Important interpretation limit
`PA_EvaluateStructure` is a primitive, not a complete market-structure state machine. It compares the last completed close with the latest confirmed high/low and uses the caller-provided prior direction to label a BOS/CHoCH candidate. A future strategy layer must track protected highs/lows and validate whether the breached pivot is the protected swing before treating a candidate as a qualified CHoCH.

## Deterministic test cases
Create synthetic `MqlRates` series fixtures with a known index-1 closed candle and verify:
1. A pivot with fewer than three newer closed candles is not confirmed.
2. Equal highs/lows invalidate a strict pivot.
3. A close above the latest confirmed high yields bullish BOS when prior direction is 0 or +1.
4. A close above the latest confirmed high yields bullish CHoCH candidate when prior direction is -1.
5. A wick above a pivot with close below does not produce a break.
6. A bullish sweep must pierce the swing low, close above it, and meet `max(2*spread, 0.05*ATR14)`.
7. A bearish sweep is the inverse.
8. FVG uses shifts 3, 2, and 1 only; bar 0 must not affect the result.
9. Gaps smaller than the minimum threshold are rejected.
10. Insufficient bars or invalid ATR/spread inputs return false.

## Validation status
The module has been added to source control but has not been compiled in MetaEditor or run in MT5 Strategy Tester. Do not describe it as compile-verified. Next, add an MT5 test harness or reproducible fixture EA and validate edge cases in MetaEditor.
