# Multi-timeframe context engine

## Purpose
`Include/MultiTimeframeContext.mqh` connects the existing closed-bar structure engine to the approved H1/M15 framework. It does not generate orders or enable trading.

## Timeframe responsibilities
- H1: directional bias.
- M15: structure direction and reversal sequence.
- M5: remains the later entry/exit confirmation layer; this module does not evaluate M5 entries.

## State recovery
`PA_UpdateTimeframeState` requests a bounded history window using `CopyRates`, restores state from terminal Global Variables, and advances state through closed bars. If no valid saved state exists, it reconstructs state chronologically from available history. The replay window for each historical signal excludes bars that had not yet closed at that historical point, avoiding lookahead.

State keys are namespaced by account login, Magic Number, symbol, and timeframe. The caller must still validate returned values and treat insufficient history or failed persistence as unavailable context. Terminal Global Variables are local terminal state, not a cross-device/cloud backup.

## Direction arbitration
`PA_ResolveMultiTimeframeContext` applies these rules:
1. H1 bullish + M15 bullish => bullish aligned context.
2. H1 bearish + M15 bearish => bearish aligned context.
3. H1/M15 opposing directions => no trade.
4. Neutral H1 => no trade unless M15 has a CHoCH followed by a later BOS in the same reversal direction.
5. Missing/invalid timeframe state => unavailable; block new entries.

A countertrend M15 direction against a non-neutral H1 is not authorized merely because M15 has changed direction. A future strategy layer must also enforce the specified setup priority and M5 confirmation.

## Synthetic fixture
`Tests/MultiTimeframeContextFixture.mq5` checks bullish/bearish alignment, direction conflict rejection, neutral-H1 reversal sequencing, and persistence round-trip. Run it as an MT5 Script and inspect the Experts log. It does not place trades.

## Validation
The source and fixture are committed but have not been compiled or executed in MetaEditor/MT5 in this environment. Record actual terminal build and PASS/FAIL output before marking tests complete.