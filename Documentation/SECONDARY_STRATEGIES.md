# Secondary strategy modules

## Scope
`Include/SecondaryStrategies.mqh` adds three independent signal-only modules:
1. BOS + order-block retest.
2. M15 breakout + retest.
3. H1/M15 trend continuation + pullback.

No module sends orders, calculates volume, or modifies positions.

## M15 event capture
`PA_CaptureM15BOS` accepts a new completed M15 BOS event only once. The M15 bar timestamp must match the structure event timestamp, and H1/M15 context must be aligned in the BOS direction.

- Order block: nearest opposing M15 candle among the preceding eight bars before the BOS candle. The zone is frozen when captured.
- Breakout: M15 BOS candle body must exceed 0.5 × M15 ATR(14). The broken swing reference is retained for the retest.
- Trend continuation: the broken swing reference is retained as the pullback level.

These are explicit first-pass mechanical definitions. They require fixture and historical validation before they can be considered strategy-complete.

## M5 confirmation
- Order block: price overlaps the zone within spread/ATR tolerance, then closes beyond the zone with directional M5 rejection or CHoCH confirmation.
- Breakout: price retests the breakout level within spread/ATR tolerance, closes back in the breakout direction, and has M5 directional confirmation.
- Trend continuation: price pulls back to the broken level, then a later candle forms a higher low/lower high and closes beyond the prior M5 candle extreme with directional confirmation.

Setups expire after 36 M5 bars for OB/breakout and 48 bars for continuation. A close through the invalidation side of the OB zone, breakout level, or pullback reference invalidates the setup.

## Priority and conflicts
Priority is fixed: sweep/CHoCH/FVG (1), BOS/OB (2), breakout/retest (3), trend continuation/pullback (4). Same-direction qualified signals resolve to the highest priority. If any simultaneously qualified signals disagree in direction, the result is no trade.

`PA_RunSecondaryStrategies` provides a new-M5-bar dispatcher, restores/persists setup state, enforces H1/M15 alignment, and arbitrates the three secondary modules. `PA_ArbitrateAllStrategies` combines the primary M5 signal with up to three secondary signals under the complete priority order.

## Persistence
`Include/SecondaryStrategyPersistence.mqh` stores pending zones, event timestamps, stages, counters, and setup-ID hashes in terminal Global Variables, namespaced by account login, Magic Number, symbol, and strategy group. These values are local to the MT5 terminal and are not cloud backups.

## Synthetic fixture
`Tests/SecondaryStrategiesFixture.mq5` covers M15 BOS capture, duplicate-event guard, OB retest, breakout retest, trend pullback/continuation, priority, direction conflict, primary-strategy priority, and persistence round-trip. It sends no orders.

## Validation status
Source and fixture files are committed but have not been compiled or run in MetaEditor/MT5 in this environment. Run the fixture and record terminal build and Experts output before marking these modules validated.