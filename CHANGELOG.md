# Changelog

All notable project changes are recorded here.

## Unreleased

- Implemented Model A qualification: explicit two-pivot H1 HH/HL or LL/LH structure, M15 BOS-aligned pullback zone at ±0.15 × M15 ATR, M5 directional rejection, and a later confirmation-candle break.
- Added synthetic fixture coverage for bullish/bearish H1 swing-sequence qualification, Model A pullback rejection, later trigger ordering, and setup-zone capture. MetaEditor compilation and fixture execution remain pending; the post-entry 24-bar time exit is a separate position-manager task.
- Froze the mechanical XAUUSD A/B1/B2/C/D research baseline in `Documentation/STRATEGY_RULES.md`.
- Defined B1 and B2 as distinct, separately testable liquidity-sweep variants.
- Specified Model A trend structure and ATR pullback zone, Model C compression range and retest deadline, and Model D session windows with explicit IANA timezone/DST behavior.
- Resolved the structural stop-buffer discrepancy as max(0.10 × M5 ATR(14), 2 × spread); baseline target is 2R, with 1.5R and 2.5R as separate experiments.
- Defined hybrid eligibility precedence D → C → A → B, conflict rejection, model time exits, and initial news-filter-disabled comparison.
- Expanded deterministic fixture requirements, performance data split, and roadmap.
- Documentation/specification only: no MQL5 source, order execution behavior, or live-trading capability changed. `InpEnableTrading=false` remains the default; execution remains DEMO + HEDGING only.

## Previous work

- Reconciled repository documentation with the current root EA, secondary runtime, and demo execution source.
- Added a research-to-code gap audit for the A/B/C/D hybrid strategy target.
- Clarified that root EA arbitration is integrated and that a DEMO + HEDGING-only order execution path exists behind `InpEnableTrading=false`.
- Added demo-only order execution, risk-based volume sizing, challenge loss/target guards, and pending day-start baseline activation.
- Added BOS/order-block retest, breakout/retest, and trend-continuation/pullback signal modules.
- Added unified strategy priority arbitration and conflicting-direction rejection.
- Added M15 BOS event capture, post-BOS M5 confirmation timing, setup expiry/invalidation, and restart persistence for secondary strategies.
- Added primary M5 sweep → CHoCH → FVG → retest state machine and setup persistence.
- Added H1/M15 context evaluation, closed-bar structure processing, and terminal Global Variable persistence.
- Added synthetic MT5 fixture source files; fixture execution evidence remains outstanding.


## [Unreleased] — Model B2 fast-reclaim variant
- Added separate B2 M15/previous-day sweep, two-bar reclaim, distinct MSS, later confirmation and trigger-break logic.
- Added B2 persistence, context eligibility, arbitration and synthetic fixture coverage.
- Kept B1 unchanged and preserved demo-only execution safeguards.
- MetaEditor compilation, fixture execution and backtesting remain pending.
