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

## M5 signal engine scenarios
- Bullish and bearish sweeps followed by later directional CHoCH, completed directional FVG, and subsequent directional FVG retest emit signals only.
- Sweep and CHoCH on the same candle must not satisfy the staged setup.
- Higher-timeframe conflict invalidates a pending setup and never emits a signal.
- An opposite but otherwise aligned H1/M15 context invalidates a pending directional setup.
- A close through the sweep extreme or FVG far boundary invalidates the setup.
- Duplicate/old M5 bar timestamps never emit a second signal.
- Pending setup state and last emitted setup ID survive terminal restart.
- Setup expiry and opposite M5 CHoCH invalidate pending setup.

## Secondary strategy scenarios
- New M15 BOS captures the nearest opposing candle as a frozen order-block zone.
- The same M15 BOS event is never captured twice.
- Order-block retest requires overlap and directional M5 confirmation; structural invalidation cancels the setup.
- Breakout requires M15 body greater than 0.5 ATR, then a later M5 retest and confirmation.
- Trend continuation requires a later pullback, higher low/lower high, and close beyond the prior M5 extreme.
- A secondary setup cannot trigger on the M5 candle that closes the M15 BOS; it must wait for a later M5 candle.
- Secondary pending setups expire and invalidate on structural failure or H1/M15 context flip.
- Same-direction signals resolve by priority; any opposing qualified direction blocks all signals.
- Primary sweep/CHoCH/FVG signal outranks every secondary signal.

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
