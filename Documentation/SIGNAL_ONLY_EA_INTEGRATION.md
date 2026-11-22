# Signal-only EA integration

## Scope

The root `PriceActionHybridEA.mq5` wires the H1/M15 structure context to the primary M5 liquidity-sweep → CHoCH → FVG → retest signal engine.

This is a **signal-only integration**, not an order-execution EA. It does not submit, modify, or close orders.

## Runtime sequence

1. Validate input ranges and refuse startup if either trading toggle is enabled.
2. Validate the selected chart symbol using broker-provided base/profit currency metadata (XAU/USD only).
3. Restore H1, M15, M5 structure and M5 setup state from terminal global variables when available.
4. Build/update H1 and M15 structure using completed candles and resolve directional context.
5. Wait for a newly opened M5 candle; then evaluate the candle that has just closed.
6. Evaluate the primary sweep → CHoCH → FVG → retest state machine.
7. Persist M5 structure and setup state. If persistence fails, suppress the signal log.
8. Log a qualified BUY/SELL signal as `SIGNAL ONLY ... NO ORDER SENT`; otherwise log the rejection reason.

## Inputs

- `InpEnableTrading`: must remain false. Startup is rejected if true.
- `InpAllowLiveTrading`: must remain false. Startup is rejected if true.
- `InpMagicNumber`: namespaces persistent state.
- `InpHistoryBars`: history requested for each timeframe.
- `InpSwingLookback`: confirmed-swing search range.
- `InpMaximumSetupBars`: maximum age of the primary setup.

`InpRiskPercent` is retained for configuration compatibility but is not used for sizing in this signal-only build.

## User-reported validation (2026-11-22)

- MetaEditor strict compile reported 0 errors and 0 warnings.
- XAUUSD chart attachment reported `SIGNAL-ONLY EA READY` on H1, M5, M1, and M15 chart instances during timeframe changes.
- The observed chart context was H1=-1 and M15=1, resolved as `PA_CONTEXT_NO_TRADE`. Conflicting higher-timeframe directions are correctly blocked.
- Strategy Tester initialization also succeeded, but the available history/tick data did not cover the full requested period. See `VALIDATION_LOG.md`.

These observations confirm compilation and initialization only. A qualified signal, sustained closed-bar processing, and restart/replay behavior have not yet been demonstrated.

## Known limitations / not yet implemented

- Secondary BOS/OB, breakout/retest, and trend-pullback modules exist but are not wired into the root EA runtime arbitration.
- No order execution, monetary lot sizing, SL/TP placement, position management, daily/weekly loss controls, news calendar, rollover, spread/ATR filter, or slippage control.
- The symbol check uses currency metadata and is not a complete broker contract compatibility adapter.
- Existing structure-state persistence has not yet been validated through restart/replay tests on the user's terminal.
- Synthetic fixtures are present but their MT5 execution results have not yet been recorded.
- The runtime does not prove signal profitability. Complete Strategy Tester and demo forward validation are still required.

## Installation and first test

1. Update the intended Git branch.
2. Copy the repository contents while preserving the root `Include` folder into the MT5 data folder under `MQL5/Experts/forexAgent`.
3. Open `PriceActionHybridEA.mq5` in MetaEditor and compile with F7.
4. Attach to the broker's XAUUSD instrument on an M5 chart.
5. Keep both trading inputs false. Allow time for the next M5 candle to open.
6. Inspect the Experts log for `SIGNAL-ONLY EA READY`, then `NO SIGNAL`, rejection messages, or `SIGNAL ONLY ... NO ORDER SENT`.

## Safety

Never enable trading for this build. A later execution release requires independent review and validation of account-currency risk calculations, broker-side protection, order lifecycle handling, and account-level lockouts.
