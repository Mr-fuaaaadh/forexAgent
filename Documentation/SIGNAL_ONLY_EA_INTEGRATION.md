# Signal-only EA integration

## Scope
The root `PriceActionHybridEA.mq5` now wires the existing H1/M15 structure context to the primary M5 liquidity-sweep → CHoCH → FVG → retest signal engine.

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

## Installation and first test
1. Update the repository branch `feature/signal-only-ea-integration`.
2. Copy the repository contents while preserving the root `Include` folder into the MT5 data folder under `MQL5/Experts/forexAgent`.
3. Open `PriceActionHybridEA.mq5` in MetaEditor and compile with F7.
4. Attach to the broker's XAUUSD instrument on an M5 chart.
5. Keep both trading inputs false. Allow time for the next M5 candle to open.
6. Inspect the Experts log for `SIGNAL-ONLY EA READY`, then `NO SIGNAL`, rejection messages, or `SIGNAL ONLY ... NO ORDER SENT`.

## Known limitations / not yet implemented
- Secondary BOS/OB, breakout/retest, and trend-pullback modules are not yet wired into the EA runtime arbitration.
- No order execution, monetary lot sizing, SL/TP placement, position management, daily/weekly loss controls, news calendar, rollover, spread/ATR filter, or slippage control.
- The symbol check uses currency metadata and is not a complete broker contract compatibility adapter.
- Existing structure-state persistence has not yet been validated through restart/replay tests on the user's terminal.
- The runtime does not prove signal profitability. Strategy Tester and demo forward validation are still required.
- The MetaQuotes-Demo history previously observed by the user begins in June 2024; this EA cannot backtest unavailable 2010–2024 history.

## Safety
Never enable trading for this build. A later execution release requires independent review and validation of account-currency risk calculations, broker-side protection, order lifecycle handling, and account-level lockouts.