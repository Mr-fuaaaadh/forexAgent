# Agent instructions

## Project identity
Build MT5 Price Action Hybrid EA v1.3 in MQL5. Initial instrument is XAUUSD; timeframes are H1 bias, M15 structure, and M5 entry/management. Read this file and the relevant documents in `Documentation/` before editing.

## Non-negotiable safety invariants
- `InpEnableTrading=false` by default. Never change this default.
- The current execution module must remain DEMO + HEDGING only. Do not add a live-account execution path.
- Never send an order unless execution is explicitly enabled, account mode and permissions are validated, symbol/data are valid, all risk checks pass, and SL/TP are attached.
- Manage only EA-owned positions identified by symbol and Magic Number.
- Calculate volume from monetary risk with `OrderCalcProfit()`; round down to volume step and recalculate. Reject if minimum volume exceeds risk budget.
- Use closed candles only. No lookahead, repainting, bar-zero signal, or future data.
- Required stale/missing data must fail closed for new entries.
- Preserve daily/static loss limits, position caps, aggregate risk caps, and persistent duplicate protection.
- Never claim profitability, compile success, Strategy Tester success, fixture success, or universal broker compatibility without recorded evidence.

## Strategy order
1. Liquidity sweep + CHoCH + FVG
2. BOS + order-block retest
3. Breakout + retest
4. Trend continuation + pullback

Conflicting active directions mean no trade. A setup identifier must prevent duplicate orders. The current fixed priority is not a regime router; consult `Documentation/RESEARCH_GAP_AUDIT.md`.

## Architecture and specifications
Read `Documentation/ARCHITECTURE.md`, `STRATEGY_RULES.md`, `RISK_MANAGEMENT.md`, `BROKER_COMPATIBILITY.md`, `CONFIGURATION.md`, `TESTING.md`, and `RESEARCH_GAP_AUDIT.md` as applicable. Do not silently alter approved thresholds. If a requirement is ambiguous or contradictory, document it and ask before changing behavior.

## MQL5 engineering rules
- Use strict compilation and explicit types; check every trade/API return value and log actionable errors.
- Use `CopyRates`/time-series APIs with explicit shifts; confirm sufficient history before analysis.
- Separate signal detection, risk calculation, broker validation, execution, position management, persistence, and logging.
- Use closed-bar timestamps and deterministic setup IDs.
- Handle partial fills, rejected orders, restart recovery, disconnections, and broker hedging constraints.
- Avoid blocking loops and unbounded work in `OnTick`.
- Keep secrets, account credentials, and personal data out of source control and logs.

## Agent workflow
1. Inspect repository and current tests before edits.
2. State the requirement and smallest safe implementation plan.
3. Make one coherent change at a time.
4. Add or update tests and fixtures.
5. Run available static checks; if MetaEditor/Strategy Tester is unavailable, say so explicitly.
6. Update docs and `CHANGELOG.md`.
7. Review the diff for safety regressions, unintended files, and unsupported claims.
8. Summarize files changed, checks actually run, results, and remaining risks.

## Definition of done
A change is done only when requirements are met, safety invariants remain intact, tests are added, relevant docs/changelog are updated, and all executed checks are reported honestly. Live trading is outside this project's scope.

## Scope boundary
MT5/MQL5 only. Do not add MiroFish, BettaFish, other trading platforms, external execution services, or unrequested integrations.
