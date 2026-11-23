# Configuration: current root EA inputs

The following are the current public inputs in `PriceActionHybridEA.mq5`. Execution defaults to disabled. Do not change fixed safety values without updating the specification, implementation, fixtures, and review.

| Input | Default | Current validation / purpose |
|---|---:|---|
| `InpEnableTrading` | `false` | Enables the demo execution initialization path; DEMO + HEDGING account is mandatory |
| `InpMagicNumber` | `120026` | Positive identifier for EA-owned orders and persistent state |
| `InpRiskPercent` | `0.5` | Must equal the reviewed 0.5% risk setting |
| `InpMaximumPositions` | `3` | Must equal the reviewed three-position cap |
| `InpMaximumOpenRisk` | `1.5` | Must equal the reviewed 1.5% aggregate risk cap |
| `InpDailyLossLimit` | `2.0` | Must equal the reviewed 2% internal daily limit |
| `InpRiskRewardRatio` | `2.0` | Must equal the fixed 2R target |
| `InpChallengeInitialBalance` | `0.0` | Must be set to the exact challenge starting balance before execution is enabled |
| `InpHistoryBars` | `500` | Requested history depth |
| `InpSwingLookback` | `80` | Confirmed swing search depth |
| `InpMaximumSetupBars` | `12` | Primary setup age limit |

## Safety and account validation
- Leave `InpEnableTrading=false while testing signals and compiling.
- There is no user input that permits live trading; the execution module independently requires DEMO + HEDGING.
- Symbol metadata must report base currency XAU and profit currency USD.
- Terminal connection, account trading permission, and expert trading permission must be available for execution.
- A challenge initial balance is persisted and cannot silently change for the same account/Magic/symbol namespace.
- A valid broker-server day-start equity baseline is required before orders can be sent. If unavailable, the EA remains attached in signal-only pending mode.

## Important omissions
The current root input list does not expose configurable max spread, session windows, news windows, slippage threshold, stop buffer, or alternative R targets. These are research/implementation gaps, not hidden configurable options.
