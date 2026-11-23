# Development roadmap

## Phase 0 — specification and source audit

- [x] Establish project scope and demo-only safety requirements.
- [x] Implement primary M5 sweep/CHoCH/FVG signal engine.
- [x] Implement BOS/OB, breakout/retest, and trend-pullback signal modules.
- [x] Integrate primary + secondary candidates into one root EA arbitration point.
- [x] Add a DEMO + HEDGING-only execution path behind a false-by-default input.
- [x] Reconcile documentation with the current source and identify research gaps.
- [x] Freeze mechanical A/B1/B2/C/D research baseline, stop buffer, exits, router precedence, and fixture requirements (documentation only).

## Phase 1 — strategy completeness (implementation pending)

- [x] Model A signal generation: explicit H1 HH/HL or LL/LH qualification, ±0.15 × M15 ATR pullback zone, M5 directional rejection, and a later confirmation break.
- [ ] Model A post-entry 24-M5-bar time exit in the position manager (separate from pending-setup expiry).
- [ ] Model B1: preserve and independently test staged sweep → later CHoCH → FVG → retest.
- [x] Model B2 signal generation: independent persisted sweep → reclaim within 2 M5 bars → later MSS → confirmation/trigger path; MetaEditor compile, fixture execution and backtest still pending.
- [ ] Model C: implement 12-completed-M15-bar range, 0.8–3.0 ATR width, ≥0.10 ATR breakout displacement, and six-M5-bar retest deadline.
- [ ] Model D: implement Asian UTC range and London/New York local-time expansion windows with IANA DST-safe conversion; fail closed if timezone conversion is unavailable.
- [ ] Build regime router with precedence D → C → A → B and explicit no-trade state.
- [ ] Prevent same-event duplication and validate model coexistence.

## Phase 2 — execution hardening (DEMO only)

- [x] Risk sizing with `OrderCalcProfit()` and volume-step flooring.
- [x] Position cap and aggregate open-risk check.
- [x] Internal daily, static maximum-loss, and profit-target guards.
- [ ] Add explicit maximum spread and spread/ATR checks.
- [ ] Implement the frozen structural stop buffer: max(0.10 × M5 ATR(14), 2 × spread).
- [ ] Verify actual filled volume, fill price, SL, TP, and initial monetary risk after every fill/partial fill.
- [ ] Harden trade transaction lifecycle, retries, ambiguous outcomes, and reservation recovery.
- [ ] Validate account currency, symbol contract, tick/volume properties, and broker stop/freeze rules.
- [ ] Persist and test lockout states across restart and broker-day rollover.
- [ ] Add approved challenge-specific distinct trading-day counter and verify target/lockout semantics.

## Phase 3 — filters and exits

- [ ] Implement frozen model time exits: A 24, B1/B2 12, C 12, D 18 completed M5 bars.
- [ ] Evaluate a separately specified high-impact USD news filter after baseline model comparison; it is disabled in the initial comparison.
- [ ] Add slippage and spread-quality controls.
- [ ] Complete structural/price-action exits and reason-code logging.

## Phase 4 — deterministic testing

- [ ] Compile exact current revision with strict MetaEditor settings.
- [ ] Run all synthetic fixtures and record build/output.
- [ ] Test closed-bar determinism, restart/replay, and duplicate setup prevention.
- [ ] Add execution fixtures for order rejection, partial fill, missing SL, stop-level rejection, spread spike, disconnect, and rollover.
- [ ] Validate on target broker XAUUSD contract and DEMO + HEDGING account.
- [ ] Verify London/New York DST conversions against known transition dates.

## Phase 5 — strategy research and performance validation

- [ ] Obtain sufficient M1/M5/M15/H1 historical data with realistic spread, commission, swap, and tick assumptions.
- [ ] Test A, B1, B2, C, and D independently.
- [ ] Tune only on development data; use validation data for selection.
- [ ] Preserve final out-of-sample period untouched.
- [ ] Run hybrid portfolio, walk-forward, parameter sensitivity, execution stress, and Monte Carlo tests.
- [ ] Record net expectancy, profit factor, drawdown, trade count, cost sensitivity, and yearly distribution.
- [ ] Run a sustained DEMO forward test.

## Frozen research defaults

- XAUUSD; M5 entries; H1/M15 context; DEMO + HEDGING only.
- Risk 0.5% per trade; max 3 managed positions; max aggregate open risk 1.5%; daily loss lock 2%; static max loss 12%; profit target 10%.
- Stop buffer max(0.10 × M5 ATR(14), 2 × spread); baseline TP 2R; compare 1.5R and 2.5R separately.
- Initial comparison news filter disabled.
- See `STRATEGY_RULES.md` for exact mechanical definitions and `TESTING.md` for fixture matrix.

## Safety boundary

Execution remains false by default and DEMO + HEDGING only. No live-trading implementation or enablement is in scope.
