# MT5 Price Action Hybrid EA

**Project:** Price Action Hybrid EA v1.3  
**Platform:** MetaTrader 5 (MQL5)  
**Initial instrument:** XAUUSD and broker-validated XAUUSD/GOLD symbol variants  
**Development status:** Signal-only primary strategy runtime; strict MetaEditor compile and chart initialization verified on 2026-11-22. Secondary strategy modules are implemented but not wired into the root EA. Not production-ready.

> **Risk warning:** Automated trading can lose money rapidly. This repository is an engineering project, not financial advice or a promise of profitability. Run the full Strategy Tester suite and demo forward tests before considering live use. Live trading must remain explicitly disabled by default.

## Project goal

Build a deterministic, testable MT5 Expert Advisor that combines multi-timeframe price action with strict execution and account-level risk controls. The EA will initially target XAUUSD and use H1 for directional bias, M15 for structure, and M5 for entries and position management.

## Safety defaults

- `EnableTrading=false`
- `AllowLiveTrading=false`
- This signal-only build refuses initialization if either trading toggle is enabled.
- The current root EA does not submit, modify, or close orders.
- Future position sizing must use broker/account-calculated monetary risk; never fixed-lot assumptions.
- Every future position must have verified broker-side stop-loss protection.
- Only positions owned by this EA's Magic Number may be managed.
- Unavailable or stale required data must fail closed for new entries.

## Strategy priority

1. Liquidity sweep + CHoCH + FVG
2. BOS + order-block retest
3. Breakout + retest
4. Trend continuation + pullback

Signals use closed candles only. H1/M15/M5 alignment, setup identity, and duplicate-signal prevention are mandatory.

## Current runtime boundary

The root `PriceActionHybridEA.mq5` currently calls only the primary M5 sweep → CHoCH → FVG → retest signal engine. BOS/OB, breakout/retest, trend-pullback, secondary persistence, and arbitration modules exist in `Include/`, but are not yet connected to the root EA runtime. Do not treat those modules as active EA strategies until integration and fixture validation are complete.

## Validation evidence

See [MT5 validation log](Documentation/VALIDATION_LOG.md). On 2026-11-22 the user reported:
- MetaEditor strict compile: 0 errors, 0 warnings.
- XAUUSD chart attachment: `SIGNAL-ONLY EA READY` observed on chart timeframes; H1 bearish and M15 bullish produced `PA_CONTEXT_NO_TRADE`, as expected for conflicting context.
- Strategy Tester ran, but the requested 2024-01-01 to 2026-11-21 interval was not fully covered by available history. The log reported history beginning 2024-06-21, ending synchronization at 2026-07-27, and no real ticks (generated ticks used).

These checks establish compilation and initialization only. They do not establish signal profitability, full historical coverage, fixture correctness, restart/replay correctness, or production readiness.

## Documentation

Read [AGENTS.md](AGENTS.md) before making code changes.

- [Signal-only EA integration](Documentation/SIGNAL_ONLY_EA_INTEGRATION.md)
- [Secondary strategy modules](Documentation/SECONDARY_STRATEGIES.md)
- [Secondary strategy fixture](Tests/SecondaryStrategiesFixture.mq5)
- [M5 entry signal engine](Documentation/M5_ENTRY_SIGNAL_ENGINE.md)
- [Multi-timeframe context engine](Documentation/MULTI_TIMEFRAME_CONTEXT.md)
- [Market structure engine](Documentation/MARKET_STRUCTURE_ENGINE.md)
- [Synthetic MT5 fixture](Tests/MarketStructureFixture.mq5)
- [Architecture](Documentation/ARCHITECTURE.md)
- [Strategy rules](Documentation/STRATEGY_RULES.md)
- [Risk management](Documentation/RISK_MANAGEMENT.md)
- [Broker compatibility](Documentation/BROKER_COMPATIBILITY.md)
- [Installation](Documentation/INSTALLATION.md)
- [Configuration](Documentation/CONFIGURATION.md)
- [Testing and validation](Documentation/TESTING.md)
- [Troubleshooting](Documentation/TROUBLESHOOTING.md)
- [Development roadmap](Documentation/DEVELOPMENT_ROADMAP.md)
- [Validation evidence](Documentation/VALIDATION_LOG.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)

## Repository status

The repository contains the engineering specification, price-action primitives, H1/M15 context, primary M5 sweep/CHoCH/FVG signal engine, secondary signal modules, arbitration, persistence, fixtures, and a signal-only EA runtime integration. The EA does **not** place trades and is not production-ready. Secondary strategy runtime integration, fixture execution, persistence/replay validation, complete historical testing, broker compatibility, risk controls, and demo forward validation remain outstanding.

## License

See [LICENSE](LICENSE).
