# Agent instructions

## Project identity
Build MT5 Price Action Hybrid EA v1.2 in MQL5. Initial instrument is XAUUSD; timeframes are H1 bias, M15 structure, M5 entry and management. Read this file and the relevant documents in `Documentation/` before editing.

## Non-negotiable safety invariants
- Defaults: `EnableTrading=false`, `AllowLiveTrading=false`. Never weaken these defaults.
- Never send an order unless trading is explicitly enabled, account mode is permitted, symbol/data are validated, risk checks pass, and a valid broker-side SL/TP can be attached or verified.
- Manage only EA-owned positions identified by Magic Number.
- Calculate volume from monetary risk with `OrderCalcProfit()`; round down to volume step and recalculate. Reject if minimum volume exceeds risk budget.
- Use closed candles only. No lookahead, repainting, bar-zero signal, or future data.
- Required stale/missing data (including news/calendar data when the filter is enabled) fails closed for new entries.
- Respect daily/weekly loss limits, trade caps, position caps, cooldowns, and persistent lockouts.
- Never claim profitability, compile success, Strategy Tester success, or universal broker compatibility without recorded evidence.

## Strategy order
1. Liquidity sweep + CHoCH + FVG
2. BOS + order-block retest
3. Breakout + retest
4. Trend continuation + pullback

Conflicting active directions mean no trade. A setup identifier must prevent duplicate orders.

## Architecture and specifications
Read `Documentation/ARCHITECTURE.md`, `STRATEGY_RULES.md`, `RISK_MANAGEMENT.md`, `BROKER_COMPATIBILITY.md`, `CONFIGURATION.md`, and `TESTING.md` as applicable. Do not silently alter approved thresholds. If a requirement is ambiguous or contradictory, document it and ask before changing behavior.

## MQL5 engineering rules
- Use strict compilation and explicit types; check every trade/API return value and log actionable errors.
- Use `CopyRates`/time-series APIs with explicit shifts; confirm sufficient history before analysis.
- Separate signal detection, risk calculation, broker validation, execution, position management, persistence, and logging.
- Use closed-bar timestamps and deterministic setup IDs.
- Handle partial fills, rejected orders, restart recovery, disconnections, and hedging/netting differences.
- Avoid blocking loops and unbounded work in `OnTick`.
- Keep secrets, account credentials, and personal data out of source control and logs.

## Agent workflow
1. Inspect repository and current tests before edits.
2. State the requirement and the smallest safe implementation plan.
3. Make one coherent change at a time.
4. Add or update tests and test fixtures.
5. Run available static checks; if MetaEditor/Strategy Tester is unavailable, say so explicitly.
6. Update docs and `CHANGELOG.md`.
7. Review diff for safety regressions, unintended files, and claims unsupported by evidence.
8. Summarize files changed, checks actually run, results, and remaining risks.

## Definition of done
A change is done only when requirements are met, safety invariants remain intact, tests are added, relevant docs/changelog are updated, and all executed checks are reported honestly. No live-trading enablement without explicit user authorization and a separate safety review.

## Scope boundary
MT5/MQL5 only for the initial release. Do not add MiroFish, BettaFish, other trading platforms, external execution services, or unrequested integrations.
