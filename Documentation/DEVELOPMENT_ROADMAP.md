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
- [x] M5 sweep → later CHoCH → FVG → retest signal state machine (primary strategy only).
- [x] M5 setup persistence and setup-ID duplicate marker.
- [x] Add bullish and bearish M5 sequence fixtures.
- [x] Add H1/M15 direction-flip invalidation fixture.
- [ ] Add sweep/FVG invalidation edge-case fixtures and run all fixtures in MT5.
- [x] BOS + order-block retest signal module.
- [x] Breakout + retest signal module.
- [x] Trend continuation + pullback signal module.
- [x] Unified priority arbitration and conflicting-direction rejection.
- [x] Secondary strategy state persistence and new-bar runtime dispatcher.
- [x] Synthetic fixtures for M15 BOS capture, all three secondary modules, priority and persistence.
- [ ] Validate all strategy fixtures in MetaEditor/MT5 and add additional historical edge cases.

## Phase 3 — execution and risk
- [ ] Monetary lot sizing via OrderCalcProfit.
- [ ] Daily/weekly risk accounting and lockouts.
- [ ] Broker-side SL/TP verification.
- [ ] Partial-fill/rejection/disconnection handling.
- [ ] Hedging and netting position management.

## Phase 4 — strategy modules
- [x] Sweep + CHoCH + FVG signal module (MT5 execution validation pending).
- [x] BOS + order-block retest signal module (MT5 execution validation pending).
- [x] Breakout + retest signal module (MT5 execution validation pending).
- [x] Trend continuation + pullback signal module (MT5 execution validation pending).
- [x] Priority arbitration and conflict rejection.
- [ ] Wire all four strategy signals into the root EA runtime and verify one shared arbitration decision per closed M5 bar.

## Phase 5 — filters and exits
- [ ] Spread/ATR and slippage filters.
- [ ] Rollover/session handling.
- [ ] USD news calendar fail-closed integration.
- [ ] Structural and price-action exits.

## Phase 6 — validation
- [x] MetaEditor strict compile: user-reported 0 errors and 0 warnings on 2026-11-22.
- [x] XAUUSD chart initialization: user-reported `SIGNAL-ONLY EA READY` on 2026-11-22.
- [ ] Validate closed-M5-bar signal processing over a sustained demo forward run.
- [ ] Run all synthetic fixtures in MetaEditor/MT5 and record PASS/FAIL output.
- [ ] Validate persistence/replay after EA and terminal restart.
- [ ] Strategy Tester suite with sufficient broker history and reproducible reports.
- [ ] Hedging/netting and broker compatibility matrix.
- [ ] Demo forward test across sessions and documented limitations.

## Current evidence limitations

The 2026-11-22 Strategy Tester log requested 2024-01-01 through 2026-11-21, while the reported synchronized history began 2024-06-21 and ended 2026-07-27. The log also reported no real ticks and generated tick modelling. This is not a complete-period or real-tick validation. See `VALIDATION_LOG.md`.

Live trading is outside the initial development target and requires separate explicit authorization and review.
