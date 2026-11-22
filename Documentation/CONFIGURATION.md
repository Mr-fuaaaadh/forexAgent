# Configuration

The implementation must expose inputs with safe defaults and validate them at initialization.

## Mandatory safety defaults
| Input | Default |
|---|---:|
| EnableTrading | false |
| AllowLiveTrading | false |
| RiskPerTradePercent | 0.5 |
| DailyLossLimitUSD | 75 |
| WeeklyLossLimitUSD | 200 |
| MaxTradesPerDay | 6 |
| MaxCombinedOpenRiskUSD | 50 |
| MaxConsecutiveLosses | 3 |
| StopLossCooldownMinutes | 30 |
| NormalExitCooldownMinutes | 15 |
| MinimumRewardRisk | 1.5 |
| TargetRewardRisk | 2.0 |
| TrailingStop | false |
| BreakEven | false |

## Market configuration
- H1 bias, M15 structure, M5 entry/management.
- Full day except market closure/rollover.
- Block 5 minutes before and after configured broker rollover.
- USD high-impact news: 30 minutes before/after; CPI/NFP/FOMC: 60 minutes before and 30 minutes after.
- If required calendar data is missing/stale, block new entries.
- Spread must respect configured absolute maximum and be no more than 10% of M5 ATR.
- Slippage is configurable.
- Use broker server time and DST-aware session/calendar handling.

## Account currency
USD risk reference amounts must be converted to account currency through a verified fresh conversion source. Block new entries if conversion cannot be trusted. Expose the conversion source and freshness policy in logs/configuration.

## Validation
Reject nonsensical ranges, unsupported timeframes, ambiguous symbols, invalid Magic Number, and incompatible account modes. Log effective settings at startup without exposing sensitive account information.
