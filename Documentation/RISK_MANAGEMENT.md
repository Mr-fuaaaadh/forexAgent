# Risk management: current demo execution

## Scope and hard account restriction
The execution module is intended for MetaTrader DEMO accounts in HEDGING mode only. It also checks terminal connection and account/expert trading permissions. The root EA has `InpEnableTrading=false` by default. If execution is disabled or the day-start baseline is pending, signals may be logged but no order is sent. There is no live-account enable path in this build.

Do not interpret these safeguards as proof that the execution path is fully hardened. Keep `InpEnableTrading=false` until all required demo validation is recorded.

## Current configured limits
| Control | Current source value | Meaning |
|---|---:|---|
| Risk per trade | 0.5% | Current account equity |
| Maximum EA-owned positions | 3 | Same symbol + Magic Number; hedging account |
| Combined open risk | 1.5% | Current account equity |
| Internal daily loss | 2% | From captured broker-server day-start equity |
| Additional challenge daily threshold | 4% | Checked as a second ceiling; 2% internal lock is stricter |
| Static maximum loss | 12% | Below configured challenge initial balance |
| Profit target | 10% | Above configured challenge initial balance, checked against balance |
| Reward/risk | 2R | Fixed target multiple |

For the user's intended $5,000 USD demo challenge, 0.5% is initially $25, 1.5% is $75, 2% is $100, 4% is $200, 12% is $600, and 10% is $500. These dollar examples apply only when the account currency is USD and the configured initial balance is exactly 5,000.

## Position sizing
- Uses `OrderCalcProfit()` to estimate one-lot loss between executable entry and proposed SL.
- Calculates volume from equity × risk percentage.
- Floors volume to broker volume step and recalculates estimated cash risk.
- Rejects if minimum volume is too large for the risk budget or calculation fails.
- Checks estimated margin availability before sending.

## Order submission
- Builds a market order with SL and TP attached in the request.
- Checks broker minimum stop distance and calls `OrderCheck()`.
- Reserves a setup ID before sending to prevent automatic duplicate submissions.
- Accepts the documented trade result retcodes and logs the result.

Important gap: after a successful/partial fill, the current source logs the order result but does not yet reconcile the actual filled position's volume, price, SL, TP, and realized initial risk. A reserved setup may remain consumed after an ambiguous/rejected result; this is intentional fail-closed behavior but needs operational handling and tests.

## Position/risk guard
- Counts and evaluates positions matching the configured symbol and Magic Number.
- Estimates open risk from each managed position's open price to SL with `OrderCalcProfit()`.
- Blocks new orders if a managed position has missing/uncomputable SL, if the three-position cap is reached, or if aggregate estimated open risk would exceed 1.5%.
- On missing protection or a triggered daily/static/target lock, attempts to close managed positions and blocks entries.

## Challenge baseline and lockouts
- A positive challenge initial balance must be supplied before execution can initialize.
- The value is persisted and a different value is rejected on later initialization.
- If a valid current-day baseline is not already persisted, activation waits for broker server time 00:00–00:01; until then the EA remains attached but signal-only.
- Daily loss is measured against captured day-start equity and includes floating equity movement by virtue of using `ACCOUNT_EQUITY`.
- Static loss uses current equity; profit target uses current balance.
- A marker is recorded when an EA-owned entry deal is seen. The current minimum-trading-day check is a simple existence check for that marker, not a verified count of distinct trading days.

## Controls not currently implemented or not proven
- No explicit maximum-spread filter or spread/ATR cap in the order path.
- No extra ATR/spread buffer is added to the structural invalidation SL.
- No verified post-fill SL/TP/volume/price reconciliation or robust partial-fill lifecycle manager.
- No weekly loss limit, maximum trades/day, consecutive-loss pause, or cooldown controls from older documentation.
- No full account-currency validation or broker contract compatibility matrix for challenge amounts.
- No calendar/news filter, rollover/session filter, or slippage-quality gate.
- No recorded automated fixture coverage for all execution failure modes.

Risk controls reduce exposure but cannot eliminate slippage, gaps, broker outages, or software failures.
