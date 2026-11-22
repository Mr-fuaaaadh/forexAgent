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

## Daily guard

- Baseline is account equity captured during the first minute (00:00-00:01) of each broker-server calendar day.
- Baseline day and equity are persisted in terminal global variables.
- If no baseline exists and the EA is initialized after 00:01 server time, initialization is blocked for that day rather than substituting mid-session equity.
- Current equity includes floating P/L; equity drawdown of 2% or more locks entries and requests closure of managed positions.
- Missing or uncalculable protective SL requests closure of the affected managed position(s).
- Persistence failure fails closed.

## Idempotency

- Setup ID is hashed into a terminal-global reservation before order submission.
- A reserved setup is never automatically retried, including after an ambiguous trade-server response. This favors duplicate prevention over automatic retries.
- Broker execution results are logged; accepted status is not represented as a guaranteed fill.

## Required validation before any forward test

1. MetaEditor compile on the target MT5 build.
2. All 49 existing strategy fixtures still pass.
3. Add and run execution fixtures for demo/live/contest mode, hedging/netting mode, lot rounding, minimum-lot rejection, SL direction, 1:2 TP, max positions, aggregate risk, daily equity lock, duplicate reservation, and restart reconciliation.
4. Strategy Tester must confirm SL and TP are attached to each accepted order.
5. One-day forward test is DEMO only and is an execution-control test, not evidence of profitability.

## Known limitations requiring review

- Setup reservation is intentionally conservative and may suppress a retry after a broker rejection; manual inspection is required before any operator clears a reservation.
- The EA must be attached and running within the first minute of broker-server midnight to capture the daily baseline. If that window is missed, the execution layer fails closed until the next server day. Verify broker-server time before planning the forward test.
- The execution module requires hedging mode. Netting accounts are blocked.
- Broker fill policies, partial fills, and stop-level behavior must be verified on the target broker. No MetaEditor compiler or live MT5 terminal is available in this development environment.
