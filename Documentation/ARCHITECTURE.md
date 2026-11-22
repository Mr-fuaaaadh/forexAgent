# Architecture

## Runtime lifecycle
- `OnInit`: validate inputs, account mode, symbol identity/specification, history availability, required calendar data, and restore persistent state.
- `OnTick`: run emergency/account checks, manage EA-owned positions, verify protection, and evaluate entries only when a new M5 candle is confirmed.
- `OnTimer`: refresh calendar/session data and persist state without blocking tick processing.
- `OnTradeTransaction`: reconcile fills, partial fills, exits, commissions, swaps, and realized P/L.
- `OnDeinit`: persist state and release indicator/timer resources.

## Logical modules
1. Symbol and broker adapter
2. Market data/history provider
3. Multi-timeframe structure and signal engine
4. Setup arbitration and idempotency
5. Risk and account safety manager
6. Order execution and protection verifier
7. Position manager and exit engine
8. News/session/spread filters
9. Persistent state and audit logging

Keep these concerns isolated even if the first implementation uses a small number of MQL5 files.

## Event and data rules
- H1: directional bias.
- M15: structure confirmation and setup context.
- M5: entry/exit confirmation.
- Only completed bars may form signals; manage existing risk on ticks.
- A new-bar detector must be restart-safe and must not replay an already processed candle.
- Setup IDs should include strategy, direction, symbol, and confirmed source-bar timestamps.

## Failure handling
Fail closed for new entries on invalid symbol resolution, insufficient history, stale required news data, unavailable conversion rates, inconsistent account state, or unverified protection. Existing positions still require defensive management and clear logs.
