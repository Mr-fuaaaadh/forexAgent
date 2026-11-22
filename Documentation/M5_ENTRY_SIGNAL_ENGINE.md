# M5 entry signal engine

## Scope
`Include/M5EntrySignal.mqh` implements the primary setup sequence as a deterministic signal state machine. It emits a BUY/SELL signal record only. It does not send orders, calculate lots, or manage positions.

`Include/M5SetupPersistence.mqh` persists in-progress setup stages and the last emitted setup ID marker. `Include/M5EntryRuntime.mqh` restores the M5 structure/setup state, evaluates one new closed candle, and saves both states. State is stored in local MT5 Terminal Global Variables and is not cloud-synchronized.

## Required sequence
1. H1/M15 context must be bullish-aligned or bearish-aligned (or an explicitly qualified neutral-H1 reversal context).
2. M5 closed candle sweeps a confirmed swing by at least `max(2 × spread, 0.05 × ATR(14))`.
3. A later M5 closed candle confirms CHoCH in the intended direction. Sweep and CHoCH cannot be the same candle.
4. A subsequent completed three-candle FVG forms in the same direction and passes the same minimum gap threshold.
5. A later candle retests the FVG boundary and closes back through the far edge in the intended direction with a directional candle body.
6. A deterministic setup ID is emitted from symbol, direction, sweep time, CHoCH time, and FVG time.

The setup expires after a configurable maximum number of M5 bars (default 12). Opposite M5 CHoCH, higher-timeframe conflict, or expiry invalidates the pending setup.

## Closed-bar and duplicate protection
- Input rates must be a series array: index 0 is forming, index 1 is the latest completed candle.
- Signal evaluation uses only closed bars.
- Duplicate/old M5 bar timestamps are rejected.
- M5 structure is advanced on every newly closed candle, even while H1/M15 context is blocked, so intermediate structure events are not silently skipped.
- The runtime wrapper persists the last processed M5 bar and setup state.
- A persisted setup-ID hash is compared on restore to prevent re-emitting the same setup after a restart.

## Retest definition
- Bullish: the candle low touches or enters the FVG upper boundary, then closes above the FVG upper boundary with a bullish body.
- Bearish: the candle high touches or enters the FVG lower boundary, then closes below the FVG lower boundary with a bearish body.

This is the initial deterministic retest definition. It is a strategy parameter to validate, not a claim that it is universally optimal.

## Synthetic fixture
`Tests/M5EntrySignalFixture.mq5` constructs a bullish sweep → later bullish CHoCH → bullish FVG → retest sequence. It also checks persistence, setup identity fields, duplicate-bar rejection, and higher-timeframe conflict blocking. It sends no orders.

## Validation status
The source and fixture are committed, but have not been compiled or executed in MetaEditor/MT5 in this environment. Run the fixture in MT5, inspect Experts logs, and report the MT5 build before marking it validated.