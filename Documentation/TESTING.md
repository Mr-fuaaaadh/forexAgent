# Testing and validation

## Evidence policy
Never claim a compile or backtest passed unless it was actually run. Record terminal/build version, broker/demo server, symbol specification, date range, modelling mode, spread/commission assumptions, and report artifact.

## Test layers
1. Static review: strict types, return-value checks, no bar-zero signals, no lookahead.
2. Unit-style deterministic tests for pivots, BOS, CHoCH, sweeps, FVG, setup arbitration, lot rounding, risk caps, and setup IDs.
3. Strategy Tester: every strategy separately, then combined priority mode.
4. Execution scenarios: partial fills, rejected orders, spread spikes, stop-level constraints, market closure, disconnect/restart.
5. Account modes: hedging and netting.
6. Demo forward test across different sessions and broker symbol variants.

## Required scenarios
- Wick crosses swing but candle does not close beyond: no BOS.
- Pivot has fewer than 3 right-side closed bars: not confirmed.
- Missing/stale calendar: no new entries.
- Risk conversion unavailable/stale: no new entries.
- Minimum lot exceeds risk budget: reject.
- Duplicate setup candle/restart: no duplicate order.
- Daily/weekly limits reached: lockout behavior and EA-owned order handling.
- Conflicting directions: no trade.
- SL/TP not verified after fill: emergency protection/close path.
- Manual positions with another Magic Number: never modified.

## Performance reporting
Report net profit, profit factor, expected payoff, max drawdown (equity and balance), trade count, win/loss distribution, average R, exposure, costs, and out-of-sample results. Include sensitivity and walk-forward analysis. Historical results do not guarantee future performance.
