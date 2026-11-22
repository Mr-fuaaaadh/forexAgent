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
`PA_UpdateStructureState` is the stateful structure primitive. It stores direction, latest confirmed pivots, protected swing, last structural event, and last processed candle timestamp. Neutral state establishes direction with a BOS; bullish state changes to bearish only after a close below its protected low; bearish state changes to bullish only after a close above its protected high. Continuation BOS refreshes the protected opposite swing. The caller must initialize and persist `PA_StructureState` across terminal restarts. The implementation is still a foundation: strategy-specific protected-swing definitions and multi-timeframe arbitration need further validation.

## Synthetic MT5 fixture\n`Tests/MarketStructureFixture.mq5` is a script that creates synthetic `MqlRates` data and checks pivot confirmation, strict equality handling, sweep thresholds, bullish FVG, initial bullish BOS, duplicate-candle suppression, and protected-low CHoCH. Run it from MetaTrader 5; it does not place trades. Review the Experts log for PASS/FAIL output.\n\n## Deterministic test cases
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
The module has been added to source control but has not been compiled in MetaEditor or run in MT5 Strategy Tester. Do not describe it as compile-verified. The fixture script is committed but has not been run in MetaTrader 5 or compiled in MetaEditor in this environment. Record actual terminal/build output before marking validation complete.
