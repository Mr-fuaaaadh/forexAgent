# Demo execution safety specification

This document defines the acceptance contract for the demo-only execution layer.

## Immutable controls

- DEMO account mode only; real and contest accounts are rejected.
- Hedging margin mode required to support three independent XAUUSD positions.
- Live execution is permanently disabled; setting the live input true must fail initialization.
- Default execution input remains disabled. The EA must be explicitly enabled by the operator on a demo account.
- XAUUSD only, with XAU base and USD profit currency metadata.

## Risk rules

- Risk per entry: 0.5% of current equity, measured with OrderCalcProfit at the intended stop.
- Fixed reward:risk = 2:1, with stop derived from the selected signal invalidation level.
- Maximum three managed positions.
- Aggregate initial stop risk for managed positions plus proposed entry must not exceed 1.5% of current equity.
- Volume is rounded down to broker volume step. If minimum volume exceeds the risk budget, reject.
- No entry without valid stop-loss and take-profit.

## Challenge controls

- One profit target only: 10% of the explicitly configured challenge starting balance. The target is evaluated against account balance.
- Firm daily equity-loss ceiling: 4% of start-of-server-day equity. A stricter 2% internal equity-loss lock is retained and should stop entries first.
- Static maximum loss: 12% of the explicitly configured challenge starting balance; current equity must remain above 88% of that baseline.
- Minimum trading days: one server-calendar day with at least one EA-managed opening deal. The marker is persisted in terminal global variables.
- `InpChallengeInitialBalance` must be set to the exact challenge starting balance. Zero or a value different from the persisted baseline blocks demo execution.
- The single 10% target replaces the two-phase 10% / 8% target model.

## Daily guard

- Baseline is account equity captured during the first minute (00:00-00:01) of each broker-server calendar day.
- Baseline day and equity are persisted in terminal global variables.
- If no baseline exists and the EA is initialized after 00:01 server time, initialization is blocked for that day rather than substituting mid-session equity.
- Current equity includes floating P/L; the 2% internal drawdown lock blocks entries and requests closure of managed positions, before the firm 4% daily limit is reached.
- Missing or uncalculable protective SL requests closure of the affected managed position(s).
- Persistence failure fails closed.

## Idempotency

- Setup ID is hashed into a terminal-global reservation before order submission.
- A reserved setup is never automatically retried, including after an ambiguous trade-server response. This favors duplicate prevention over automatic retries.
- Broker execution results are logged; accepted status is not represented as a guaranteed fill.

## Required validation before any forward test

1. MetaEditor compile on the target MT5 build.
2. All 49 existing strategy fixtures still pass.
3. Run the expanded deterministic fixtures for stop/target arithmetic, static-loss floor, 10% single target, and 2% internal daily equity threshold.
4. Add/run broker/account-dependent checks for demo/live/contest mode, hedging/netting mode, lot rounding, minimum-lot rejection, max positions, aggregate risk, daily equity lock, duplicate reservation, minimum-day persistence, and restart reconciliation.
5. Strategy Tester must confirm SL and TP are attached to each accepted order.
6. One-day forward test is DEMO only and is an execution-control test, not evidence of profitability.

## Known limitations requiring review

- Setup reservation is intentionally conservative and may suppress a retry after a broker rejection; manual inspection is required before any operator clears a reservation.
- The EA must be attached and running within the first minute of broker-server midnight to capture the daily baseline. If that window is missed, the execution layer fails closed until the next server day. Verify broker-server time before planning the forward test.
- The minimum-day marker currently counts an EA-managed opening deal only; manual trades and other EAs are not reconciled. Confirm the firm counting convention before relying on this tracker.
- The static-loss baseline must be entered manually as the exact challenge starting balance; do not infer it from mid-challenge equity.
- The execution module requires hedging mode. Netting accounts are blocked.
- Broker fill policies, partial fills, and stop-level behavior must be verified on the target broker. No MetaEditor compiler or live MT5 terminal is available in this development environment.
