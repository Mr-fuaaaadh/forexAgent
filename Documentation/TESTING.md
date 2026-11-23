# Testing and validation

## Evidence policy

Never claim a compile, fixture, backtest, or demo execution test passed unless it was actually run. Record MT5 build, broker/demo server, symbol specification, date range, modelling mode, spread/commission/swap assumptions, and report artifacts. This document defines required tests; it is not evidence that they have passed.

## Frozen strategy baseline

The mechanical research baseline is in `STRATEGY_RULES.md`. Test A, B1, B2, C, D independently before hybrid routing. Use closed bars only, identical costs, and identical risk sizing. The baseline target is 2R; 1.5R and 2.5R are separate experiments. Stop buffer is max(0.10 × M5 ATR(14), 2 × spread). News filter is disabled for the initial comparison.

## Model A — trend pullback fixtures

- Bullish H1 HH/HL + bullish M15 alignment qualifies; bearish LL/LH + bearish M15 alignment qualifies.
- Missing H1 swing sequence, mixed H1/M15 direction, or unconfirmed pivot rejects.
- The last two confirmed H1 highs and lows must independently form HH/HL or LL/LH; a direction flag or single BOS is insufficient.
- Model A setup zone is frozen from the broken M15 swing ±0.15 × M15 ATR(14), calculated from completed M15 candles.
- Pullback must overlap the frozen zone and the touch candle must be a directional M5 rejection.
- A separate later completed M5 candle must close beyond the rejection candle high/low in the trend direction.
- Same-bar touch-and-break is prohibited; zone invalidation and context loss cancel the setup. A defensive 48-bar pending-setup expiry is separate from the specified 24-bar post-entry holding limit.
- Verify the stop invalidation is the rejection extreme and execution applies the separately frozen stop buffer.
- Post-entry 24-M5-bar time exit is not part of this signal-module change; test it when the position manager is implemented.

## Model B1 — staged sweep/CHoCH/FVG/retest fixtures

- Bullish and bearish sweeps of M15 swing and previous-day levels.
- Sweep excursion just below, exactly at, and just above max(0.05 × M15 ATR, 2 × spread).
- Reclaim, later CHoCH, post-CHoCH FVG, later retest, and confirmation in the required order.
- Sweep and CHoCH on the same candle must fail.
- FVG formed before CHoCH, FVG invalidation, sweep-extreme breach, context conflict, stale setup, and expiry must fail closed.
- B1 setup identity must not collide with B2.

## Model B2 — fast-reclaim/MSS fixtures

- Reclaim on sweep candle and on each of the next two completed M5 bars qualifies; reclaim after that deadline fails.
- No close back across swept level fails reclaim.
- Reclaim candle cannot also satisfy the later MSS requirement.
- MSS must precede a separate confirmation/trigger candle.
- Sweep-extreme breach, context invalidation, duplicate event, and expiry cancel.
- Test bullish/bearish directions and both M15 swing and previous-day references.
- B2 setup identity must not collide with B1.

## Model C — compression breakout fixtures

- Range uses exactly 12 completed M15 candles; forming bar 0 is excluded.
- Range width below 0.8 ATR, above 3.0 ATR, and at each boundary.
- Breakout close displacement below 0.10 ATR, exactly at threshold, and above threshold.
- Wick-only break fails.
- Retest on M5 bars 1 and 6 qualifies; bar 7 fails.
- Close back inside through the broken boundary invalidates.
- Later confirmation and trigger ordering; 12-bar time exit.

## Model D — session expansion fixtures

- Asian range includes only bars from 00:00 inclusive to 06:00 UTC exclusive and is frozen after 06:00.
- London local 07:00–10:00 and New York local 08:00–11:00 windows map correctly to UTC before and after DST changes.
- Test UK and US DST transition weeks independently, including weeks where transition dates differ.
- Missing/invalid timezone conversion disables Model D; no fixed-offset fallback.
- Breakout close, retest within six M5 bars, later confirmation, session-end cancellation, duplicate session event, and 18-bar time exit.

## Shared signal and router fixtures

- Every model uses completed bars only; a forming bar cannot create a signal.
- Confirmed pivots are not available before three right-side bars close.
- BOS is close-based; wick-only BOS fails.
- Setup timestamps and IDs remain deterministic after terminal restart/replay.
- Router precedence is D → C → A → B. If no regime qualifies, no trade.
- Simultaneous opposite-direction candidates block the decision.
- Same-direction candidates select one model only; one source event cannot create duplicate entries.
- B1/B2 are independently switchable for experiments; their trades and statistics remain separately attributable.

## Stop, target, and risk fixtures

- Stop buffer equals max(0.10 × M5 ATR(14), 2 × spread) for each direction and instrument quote precision.
- Stop is placed beyond structural invalidation; incorrect-side or invalid stops reject.
- Baseline target is 2R from actual executable fill; separate test runs use 1.5R and 2.5R.
- No trailing, partial close, or break-even logic in baseline.
- Model time exits: A 24, B1/B2 12, C 12, D 18 completed M5 bars.
- Risk sizing uses OrderCalcProfit(); volume floors to broker step and never exceeds 0.5% per-trade risk.
- Maximum three EA-managed positions and 1.5% combined open risk across all models.
- Missing/uncomputable SL on a managed position blocks new entries and triggers the emergency close path.
- Daily 2%, static 12%, and target 10% lockouts block entries and invoke managed-position close behavior.
- Broker minimum stop distance, freeze level, and OrderCheck rejection are handled.
- Partial fills, order rejections, post-fill SL/TP, actual risk, disconnect/restart, spread spikes, and broker rollover require dedicated DEMO tests.

## Root runtime and execution safety

- Verify root EA evaluates the newly closed M5 bar once.
- Verify primary and secondary paths consume the same decision bar without advancing live M5 structure state twice.
- Verify all qualified outputs reach one arbitration point.
- Verify no order is submitted when `InpEnableTrading=false`, on a non-DEMO account, on a non-HEDGING account, or when terminal/account/expert permissions are absent.
- Verify missing day-start baseline keeps the EA attached but signal-only/pending until the permitted server-day opening window.
- REAL, CONTEST, netting, exchange, or unavailable-permission accounts must never send orders.
- Validate XAUUSD digits, tick size/value, contract size, volume min/max/step, filling mode, stops level, freeze level, and account currency.
- Other Magic Numbers and manual positions must not be modified.

## Performance and data protocol

- Use M1/M5/M15/H1 history with real-tick modelling where available; verify data completeness and broker symbol specification.
- Development: 2018–2022. Validation: 2023–2024. Untouched OOS: 2025–October 2026, subject to data availability. Record gaps; never silently substitute synthetic ticks for missing real ticks.
- Report net profit, profit factor, expected payoff, equity and balance drawdown, trade count, win/loss distribution, average R, exposure, spread/commission/swap, slippage, and year-by-year/OOS results.
- Run 1.5× spread stress, parameter sensitivity, walk-forward, Monte Carlo, and hybrid portfolio tests.
- Historical results do not guarantee future performance.


### Model B2 fixture coverage
The secondary-strategy fixture now covers M15 swing sweep capture, reclaim sequencing, distinct MSS, later directional confirmation, trigger break and B2 persistence. Run in MetaEditor/Strategy Tester before enabling demo execution.
