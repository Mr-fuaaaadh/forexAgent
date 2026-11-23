# Changelog

All notable project changes are recorded here.

## Unreleased
- Reconciled repository documentation with the current root EA, secondary runtime, and demo execution source.
- Added a research-to-code gap audit for the A/B/C/D hybrid strategy target.
- Clarified that root EA arbitration is integrated and that a DEMO + HEDGING-only order execution path exists behind `InpEnableTrading=false`.
- Corrected outdated signal-only/no-order claims and obsolete risk/configuration values.
- Documented remaining execution-hardening gaps: maximum spread filter, stop buffer, post-fill protection verification, currency/contract validation, and incomplete challenge metrics.
- No MQL5 source behavior was changed in this documentation-only update.

## Previous work
- Added demo-only order execution, risk-based volume sizing, challenge loss/target guards, and pending day-start baseline activation.
- Added BOS/order-block retest, breakout/retest, and trend-continuation/pullback signal modules.
- Added unified strategy priority arbitration and conflicting-direction rejection.
- Added M15 BOS event capture, post-BOS M5 confirmation timing, setup expiry/invalidation, and restart persistence for secondary strategies.
- Added primary M5 sweep → CHoCH → FVG → retest state machine and setup persistence.
- Added H1/M15 context evaluation, closed-bar structure processing, and terminal Global Variable persistence.
- Added synthetic MT5 fixture source files; fixture execution evidence remains outstanding.
