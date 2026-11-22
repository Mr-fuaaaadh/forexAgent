# Development roadmap

## Phase 0 — specification scaffold
- [x] Establish project scope, safety invariants, and agent workflow.
- [x] Document strategy, risk, broker compatibility, and validation.
- [ ] Review unresolved implementation details before coding.

## Phase 1 — MQL5 foundation
- [ ] Strict EA skeleton and safe input validation.
- [ ] Symbol resolver and broker/account adapter.
- [ ] Closed-bar data provider and restart-safe new-bar detector.
- [ ] Structured logging and persistent state.

## Phase 2 — deterministic price-action engine
- [ ] Confirmed swings, BOS, CHoCH, sweep, and FVG.
- [ ] H1/M15 directional arbitration.
- [ ] Setup IDs and duplicate prevention.
- [ ] Deterministic tests/fixtures.

## Phase 3 — execution and risk
- [ ] Monetary lot sizing via OrderCalcProfit.
- [ ] Daily/weekly risk accounting and lockouts.
- [ ] Broker-side SL/TP verification.
- [ ] Partial-fill/rejection/disconnection handling.
- [ ] Hedging and netting position management.

## Phase 4 — strategy modules
- [ ] Sweep + CHoCH + FVG.
- [ ] BOS + order-block retest.
- [ ] Breakout + retest.
- [ ] Trend continuation + pullback.
- [ ] Priority arbitration and conflict rejection.

## Phase 5 — filters and exits
- [ ] Spread/ATR and slippage filters.
- [ ] Rollover/session handling.
- [ ] USD news calendar fail-closed integration.
- [ ] Structural and price-action exits.

## Phase 6 — validation
- [ ] MetaEditor strict compile.
- [ ] Strategy Tester suite and reproducible reports.
- [ ] Hedging/netting and broker compatibility matrix.
- [ ] Demo forward test and documented limitations.

Live trading is outside the initial development target and requires separate explicit authorization and review.
