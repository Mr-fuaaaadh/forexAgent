# Secondary strategy modules

## Scope
`Include/SecondaryStrategies.mqh` provides three secondary signal modules:
1. BOS + order-block retest.
2. M15 BOS breakout + retest.
3. H1/M15 trend continuation + pullback.

These modules generate signals only. The root EA combines their output with the primary signal and may pass the selected candidate to the separate demo-only execution module when explicitly enabled and all account/baseline guards pass.

## M15 event capture
`PA_CaptureM15BOS` accepts a new completed M15 BOS event once. The M15 bar timestamp must match the structure event timestamp, and H1/M15 context must be aligned in the BOS direction.

- Order block: nearest opposing M15 candle among the preceding eight bars before the BOS candle. Zone is frozen when captured.
- Breakout: M15 BOS candle body must exceed 0.5 × M15 ATR(14). The broken swing reference is retained for retest.
- Trend continuation: broken swing reference is retained as pullback level.

These are first-pass mechanical definitions and require fixture and historical validation.

## M5 confirmation
- Order block: price overlaps the zone within spread/ATR tolerance, then closes beyond the zone with directional M5 rejection or CHoCH confirmation.
- Breakout: price retests the breakout level within spread/ATR tolerance, closes in breakout direction, and has M5 directional confirmation.
- Trend continuation: price pulls back to the broken level, then a later candle forms a higher low/lower high and closes beyond the prior M5 candle extreme with directional confirmation.

Setups expire after 36 M5 bars for OB/breakout and 48 bars for continuation. Structural failure or H1/M15 context flip invalidates pending setups.

## Priority and conflicts
Priority is fixed: sweep/CHoCH/FVG (1), BOS/OB (2), breakout/retest (3), trend continuation/pullback (4). Same-direction qualified signals resolve to highest priority. Any simultaneously qualified opposing direction means no trade.

`PA_RunSecondaryStrategies` dispatches and persists secondary setup state. `PA_ArbitrateAllStrategies` combines the primary M5 signal with secondary candidates in the root EA.

## Research limitations
The current breakout module does not implement the full 12-M15-candle compression/range criteria in the research target. The current trend-pullback module does not fully implement explicit H1 HH/HL or LL/LH qualification and the research ATR pullback band. Model D session expansion is not present in these secondary modules.

## Validation
Source and fixture scripts exist. The previous compile evidence predates the current integrated execution revision; run all fixtures in MetaEditor/MT5 and record terminal build/output before marking the modules validated. None of these statements imply profitability.


## Model B2 — fast reclaim and MSS
- Sweep a confirmed M15 swing or the previous completed D1 high/low. Excursion must be at least max(0.05 × M15 ATR(14), 2 × spread).
- Reclaim by a completed close across the swept level on the sweep candle or within the next two completed M5 candles.
- Require a distinct later M5 CHoCH/MSS; reclaim candle cannot double as MSS.
- Require a later directional confirmation candle, then a subsequent completed close beyond that candle's high/low.
- Cancel on missed reclaim deadline, sweep-extreme breach, context invalidation, or 12-bar setup expiry.
- B2 has a separate label, state, persistence and setup ID from B1. B1 remains unchanged.
