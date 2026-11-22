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
- [x] Initial closed-bar primitives: confirmed swings, BOS/CHoCH candidates, sweep, and FVG.
- [x] Initial protected-swing state machine and duplicate-bar guard.
- [ ] Review protected-swing semantics against additional synthetic and historical fixtures.
- [ ] Complete strategy-level CHoCH validation.
- [x] Add deterministic synthetic MT5 fixture script.
- [ ] Run fixture in MT5 and record MetaEditor/terminal build evidence.
- [x] H1/M15 directional arbitration with conflict rejection and neutral-H1 reversal sequence.
- [x] Terminal persistence for timeframe structure state.
- [ ] Validate persistence/replay and arbitration fixtures in MT5.
- [x] M5 sweep → later CHoCH → FVG → retest signal state machine (primary strategy only).\n- [x] M5 setup persistence and setup-ID duplicate marker.\n- [x] Add bullish and bearish M5 sequence fixtures.\n- [ ] Add more edge-case fixtures and run all fixtures in MT5.\n- [ ] Setup IDs and duplicate prevention for all four strategy modules.
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
