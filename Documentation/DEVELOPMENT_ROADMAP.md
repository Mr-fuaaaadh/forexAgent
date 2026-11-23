# Development roadmap

## Phase 0 — specification and source audit
- [x] Establish project scope and demo-only safety requirements.
- [x] Implement primary M5 sweep/CHoCH/FVG signal engine.
- [x] Implement BOS/OB, breakout/retest, and trend-pullback signal modules.
- [x] Integrate primary + secondary candidates into one root EA arbitration point.
- [x] Add a DEMO + HEDGING-only execution path behind a false-by-default input.
- [x] Reconcile documentation with the current source and identify research gaps.
- [ ] Freeze the complete A/B/C/D mechanical strategy specification and resolve stop-buffer discrepancy.

## Phase 1 — strategy completeness
- [ ] Model A: explicit H1 HH/HL or LL/LH qualification and M15 ATR pullback zone.
- [ ] Model B: compare current sweep→CHoCH→FVG→retest with explicit sweep→reclaim→MSS alternative.
- [ ] Model C: add 12-M15-bar compression/range definition, ATR width, breakout displacement, and six-M5-bar retest deadline.
- [ ] Model D: session range expansion with UTC/DST-safe conversion and breakout/retest confirmation.
- [ ] Build regime router for trend, range/liquidity, compression/expansion, and session expansion.
- [ ] Prevent same-event strategy duplication and validate model coexistence.

## Phase 2 — execution hardening (DEMO only)
- [x] Risk sizing with `OrderCalcProfit()` and volume-step flooring.
- [x] Position cap and aggregate open-risk check.
- [x] Internal daily, static maximum-loss, and profit-target guards.
- [ ] Add explicit maximum spread and spread/ATR checks.
- [ ] Resolve and implement approved SL buffer consistently.
- [ ] Verify actual filled volume, fill price, SL, TP, and initial monetary risk after every fill/partial fill.
- [ ] Harden trade transaction lifecycle, retries, ambiguous outcomes, and reservation recovery.
- [ ] Validate account currency, symbol contract, tick/volume properties, and broker stop/freeze rules.
- [ ] Persist and test lockout states across restart and broker-day rollover.
- [ ] Add the approved challenge-specific distinct trading-day counter and verify target/lockout semantics.

## Phase 3 — filters and exits
- [ ] Define session/rollover behavior and timezone/DST policy.
- [ ] Define and integrate a fail-closed USD high-impact news filter if retained in the frozen spec.
- [ ] Add slippage and spread-quality controls.
- [ ] Complete structural/price-action exits and reason-code logging.

## Phase 4 — deterministic testing
- [ ] Compile exact current revision with strict MetaEditor settings.
- [ ] Run all synthetic fixtures and record build/output.
- [ ] Test closed-bar determinism, restart/replay, and duplicate setup prevention.
- [ ] Add execution fixtures for order rejection, partial fill, missing SL, stop-level rejection, spread spike, disconnect, and rollover.
- [ ] Validate on the target broker's XAUUSD contract and DEMO + HEDGING account.

## Phase 5 — strategy research and performance validation
- [ ] Obtain sufficient M1/M5/M15/H1 historical data with realistic spread, commission, swap, and tick assumptions.
- [ ] Test each model independently.
- [ ] Tune only on development data; use validation data for selection.
- [ ] Preserve the final out-of-sample period untouched.
- [ ] Run hybrid portfolio, walk-forward, parameter sensitivity, execution stress, and Monte Carlo tests.
- [ ] Record net expectancy, profit factor, drawdown, trade count, cost sensitivity, and yearly distribution.
- [ ] Run a sustained DEMO forward test.

## Safety boundary
Execution remains false by default and DEMO + HEDGING only. No live-trading implementation or enablement is in scope.
