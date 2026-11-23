# Testing and validation

## Evidence policy
Never claim a compile, fixture, backtest, or demo execution test passed unless it was actually run. Record MT5 build, broker/demo server, symbol specification, date range, modelling mode, spread/commission/swap assumptions, and report artifacts.

## Strategy signal fixtures
### Primary sweep / CHoCH / FVG
- Bullish and bearish sweep followed by a later directional CHoCH, completed directional FVG, and later retest.
- Sweep and CHoCH on the same candle must not satisfy the staged setup.
- HTF conflict, direction flip, sweep-extreme breach, FVG invalidation, expiry, and duplicate timestamp must fail closed.
- Pending setup and emitted setup ID must survive restart without duplicate signal.

### Secondary BOS/OB, breakout, and trend pullback
- M15 BOS captures the nearest opposing candle once.
- OB retest requires overlap and directional M5 confirmation; invalidation cancels.
- Breakout body threshold and later M5 retest/confirmation are deterministic.
- Trend pullback waits for a later pullback and continuation confirmation.
- Secondary setups expire and invalidate on structural failure/context flip.
- Same M15 BOS event is not captured twice.
- Same-direction qualified candidates resolve by priority; opposing qualified directions block all signals.
- Primary strategy outranks secondary strategies.

## Root runtime integration
- Verify the root EA evaluates the newly closed M5 bar once.
- Verify primary and secondary paths consume the same decision bar without advancing live M5 structure state twice.
- Verify all qualified outputs reach one arbitration point.
- Verify a selected signal is only logged when execution is disabled or pending.
- Verify no order is submitted when `InpEnableTrading=false), on a non-DEMO account, on a non-HEDGING account, or when terminal/account/expert permissions are absent.
- Verify day-start baseline absence keeps the EA attached but signal-only until the permitted server-day opening window.

## Execution and risk scenarios (DEMO only)
- Position sizing uses `OrderCalcProfit()`; volume floors to broker step and never exceeds risk budget.
- Minimum volume greater than risk budget rejects the order.
- Maximum three EA-owned positions and 1.5% combined open risk are enforced.
- Missing/uncomputable SL on a managed position blocks new entries and triggers the emergency close path.
- Daily 2%, static 12%, and target 10% lockouts block entries and invoke managed-position close behavior.
- Broker minimum stop distance and `OrderCheck()` rejection are handled.
- Duplicate setup reservation prevents resubmission after ambiguous outcomes.
- Partial fills, order rejections, post-fill SL/TP, actual risk, disconnect/restart, spread spikes, and broker rollover require dedicated tests.

## Required account and broker cases
- DEMO + HEDGING accepted only when all permissions are present.
- REAL, CONTEST, netting, exchange, or unavailable-permission accounts must never send orders.
- Validate XAUUSD symbol metadata, digits, tick size/value, contract size, volume min/max/step, filling mode, stops level, freeze level, and account currency.
- Other Magic Numbers and manual positions must not be modified.

## Performance reporting
Report net profit, profit factor, expected payoff, equity and balance drawdown, trade count, win/loss distribution, average R, exposure, spread/commission/swap, and out-of-sample results. Include sensitivity, walk-forward, and Monte Carlo analysis. Historical results do not guarantee future performance.
