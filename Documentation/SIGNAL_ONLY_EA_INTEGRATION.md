# Root EA runtime integration

## Scope
The root `PriceActionHybridEA.mq5` integrates H1/M15 context, the primary M5 sweep/CHoCH/FVG signal engine, three secondary signal modules, unified arbitration, and an optional DEMO-only execution path.

This is not a signal-only-only architecture: when `InpEnableTrading=true), initialization succeeds, the account is DEMO + HEDGING, permissions are available, and a valid broker-day baseline is ready, the selected signal can be submitted through `DemoExecution.mqh`. The default remains false. No live-account execution path is provided.

## Runtime sequence
1. Validate fixed safety inputs and XAUUSD symbol metadata (base XAU, profit USD).
2. Initialize the demo execution module; if disabled, remain signal-only.
3. If enabled, require a positive persisted challenge initial balance and DEMO + HEDGING account.
4. If today's broker-server day-start equity baseline is missing, remain attached in pending/signal-only mode until server time 00:00–00:01.
5. Restore H1, M15, M5 structure and primary/secondary setup state.
6. Update H1/M15 context from completed bars.
7. On each newly opened M5 candle, evaluate the just-completed M5 bar.
8. Evaluate primary and secondary strategy candidates, persist state, and arbitrate once.
9. If a signal is selected, execute only when the demo execution module is ready; otherwise log signal-only with no order sent.
10. Enforce daily/static/target and missing-protection guards on ticks while execution is ready.

## Current public inputs
See `CONFIGURATION.md`. `InpEnableTrading` defaults false. There is no live trading toggle.

## Current validation boundary
The current source path is present, but the evidence log does not yet prove the current revision compiles, all fixtures pass, execution lifecycle is correct, or any model is profitable. Keep execution disabled while validating signals. Any execution test must use a dedicated DEMO + HEDGING account and verify actual post-fill protection and risk.

## Known limitations
- A valid broker-day baseline is required; mid-session attachment may remain pending until the next server-day opening minute.
- The order path uses structural invalidation directly and does not yet add the research stop buffer.
- No explicit max-spread/spread-to-ATR filter.
- No post-fill reconciliation of actual volume, fill price, SL/TP, and monetary risk.
- No full partial-fill/retry/recovery lifecycle.
- Account currency and full broker contract compatibility are not comprehensively validated.
- No session/news/rollover filters or complete A/B/C/D regime router.
