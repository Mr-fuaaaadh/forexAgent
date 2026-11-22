# Risk management

## Baseline policy
Reference equity is USD 5,000. Risk per trade is 0.5% of equity (USD 25 at the reference balance). Daily loss limit USD 75; weekly loss limit USD 200. Maximum 6 trades/day; maximum 2 EA-owned positions on hedging accounts or 1 aggregated position on netting accounts. Combined open risk cap USD 50. Pause after 3 consecutive losses. Stop-loss cooldown 30 minutes; normal exit cooldown 15 minutes.

These USD reference limits must be converted to account currency using a verified, fresh conversion rate. If conversion is unavailable or stale, block new entries. Do not silently interpret USD values as account-currency amounts.

## Position sizing
- Calculate loss for candidate volume and SL using `OrderCalcProfit()`.
- Round volume down to broker volume step.
- Recalculate risk after rounding.
- Reject if minimum permitted volume exceeds the risk budget.
- Never use a hardcoded lot size or assume contract size/tick value.

## Loss accounting and lockouts
Daily/weekly P&L includes closed and floating P&L, commissions, swaps, and other costs. Persist counters and lockout state across terminal restarts. At daily/weekly limit: block new entries, cancel EA-owned pending orders, and close EA-owned positions according to the emergency lock policy. Log the reason and reconcile actual execution outcomes.

## Protection
Every live EA position must have broker-side SL/TP. Verify after fill. Handle partial fills and trade transactions. If protection cannot be confirmed, attempt emergency modification; if still unprotected, close the position and record the failure. Never represent a client-side virtual stop as equivalent protection.

## Trade and position controls
- Hedging: maximum 2 EA-owned positions.
- Netting: maximum 1 aggregated EA-owned position; account for shared symbol exposure before acting.
- Manage only the configured Magic Number.
- Enforce maximum trades/day, combined open risk, cooldowns, and consecutive-loss pause.

## Initial disabled features
Trailing stop and breakeven are disabled initially. They require separate specification and validation before activation.

## Exit reason codes
`SL_HIT`, `TP_HIT`, `PRICE_ACTION_REVERSAL`, `DAILY_RISK_LOCK`, `WEEKLY_RISK_LOCK`, `ACCOUNT_SAFETY_FAILURE`, `MANUAL_CLOSE`.

Risk controls reduce exposure but cannot eliminate slippage, gaps, execution failures, or loss.
