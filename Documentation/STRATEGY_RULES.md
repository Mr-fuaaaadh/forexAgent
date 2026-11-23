# Strategy rules: current implementation and research target

## Shared timeframe and signal timing
- H1: directional context.
- M15: market structure and secondary setup creation.
- M5: entry confirmation and decision timing.
- Evaluate on a newly opened M5 candle using the just-completed M5 candle. Bar 0 must not be used as a signal candle.
- Structure pivots use 3 bars on each side and become confirmed only after the right-side bars close.
- BOS requires a completed candle close beyond a confirmed swing; wick-only breaks do not qualify.
- CHoCH requires a completed close beyond the protected swing against the prior structure direction.

## Current primary strategy — liquidity sweep / CHoCH / FVG (Model B family)
The primary signal engine stages a sweep, a later CHoCH, a completed directional FVG, and a subsequent FVG retest/confirmation. It uses confirmed swing references and rejects stale/invalidated setups. Sweep and FVG minimum-size checks use spread/ATR thresholds as implemented in the M5 signal module.

The current primary path is not identical to the research alternative that explicitly requires reclaim within the sweep candle or next two M5 bars, then MSS/CHoCH and trigger confirmation. The two variants must be separately labelled and compared in research; do not silently claim equivalence.

## Current secondary modules

### BOS + order-block retest
Capture the nearest opposing M15 candle among the preceding eight bars before an aligned M15 BOS. Freeze the zone. Wait for a later M5 retest/overlap and directional close/confirmation. Current expiry is 36 M5 bars.

### Breakout + retest (Model C family)
Require an aligned M15 BOS whose body exceeds 0.5 × M15 ATR(14), then a later M5 retest of the broken level and directional confirmation. Current expiry is 36 M5 bars.

Research target still requires an explicit 12-completed-M15-candle range/compression definition, range width of 0.8–3.0 × M15 ATR, close outside by at least 0.10 × ATR, and retest within six M5 bars. Those conditions are not currently represented as the full Model C specification.

### Trend continuation + pullback (Model A family)
Require aligned H1/M15 direction and an M15 BOS; use the broken swing reference as the pullback level, then require a later M5 pullback and higher-low/lower-high continuation confirmation. Current expiry is 48 M5 bars.

Research target additionally calls for explicit H1 HH/HL or LL/LH trend qualification and a defined pullback zone around the broken swing using ±0.15 × M15 ATR. Those precise conditions are not fully implemented in the current module.

### Session expansion (Model D)
Not implemented. Research target defines an Asian range (UTC 00:00–06:00), London expansion window (UTC 07:00–10:00), and New York expansion window (UTC 13:00–16:00), with timezone/DST-safe conversion, breakout, retest, and confirmation. Do not represent Model D as active.

## Arbitration
- The root EA evaluates the primary and secondary runtime on one closed-M5 decision and passes qualified candidates through unified arbitration.
- Any simultaneously qualified opposing directions reject the decision.
- Otherwise strategy priority is: sweep/CHoCH/FVG, BOS/OB, breakout/retest, trend pullback.
- This is fixed priority arbitration, not a full market-regime router. A future router must classify trend/range/compression/session expansion before selecting eligible models.

## Stops, targets, and execution mismatch
- Strategy signals provide a structural invalidation level.
- The current demo execution code places SL at that raw invalidation level and TP at fixed 2R from the executable quote.
- The research target calls for an additional invalidation buffer, at least max(0.05 × ATR, 2 × spread); earlier strategy notes mention 0.10 × M5 ATR. This discrepancy must be resolved and frozen before changing code.
- The current code does not enforce the research minimum 1.5R after spread/commission modelling; it uses a fixed 2R target.
- Broker minimum stop distance is checked before order submission.

## Non-repainting and state requirements
Use explicit completed-bar timestamps. Persist setup state and duplicate markers. Restart/replay behavior still requires MT5 fixture and terminal restart evidence. A successful compile alone is not proof of deterministic replay or profitable signals.

## Research acceptance boundary
Models A/B/C/D and their router are not research-validated merely because similarly named signal modules exist. Each model must be independently tested, then tested as a hybrid portfolio on separated development, validation, and untouched out-of-sample data. See `RESEARCH_GAP_AUDIT.md` and `TESTING.md`.
