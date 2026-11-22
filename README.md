# MT5 Price Action Hybrid EA

**Project:** Price Action Hybrid EA v1.2  
**Platform:** MetaTrader 5 (MQL5)  
**Initial instrument:** XAUUSD and broker-validated XAUUSD/GOLD symbol variants  
**Development status:** Specification and documentation scaffold — not production-ready.

> **Risk warning:** Automated trading can lose money rapidly. This repository is an engineering project, not financial advice or a promise of profitability. Run in Strategy Tester and on a demo account before considering live use. Live trading must remain explicitly disabled by default.

## Project goal

Build a deterministic, testable MT5 Expert Advisor that combines multi-timeframe price action with strict execution and account-level risk controls. The EA will initially target XAUUSD and use H1 for directional bias, M15 for structure, and M5 for entries and position management.

## Safety defaults

- `EnableTrading=false`
- `AllowLiveTrading=false`
- No order may be sent unless trading is explicitly enabled and all safety checks pass.
- Position sizing must use broker/account-calculated monetary risk; never fixed-lot assumptions.
- Every position must have verified broker-side stop-loss protection.
- Only positions owned by this EA's Magic Number may be managed.
- Unavailable or stale required data must fail closed for new entries.

## Strategy priority

1. Liquidity sweep + CHoCH + FVG
2. BOS + order-block retest
3. Breakout + retest
4. Trend continuation + pullback

Signals use closed candles only. H1/M15/M5 alignment, setup identity, and duplicate-order prevention are mandatory.

## Documentation

Read [AGENTS.md](AGENTS.md) before making code changes.

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
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)

## Repository status

The repository currently contains the engineering specification, initial price-action primitives, protected-swing state machine, H1/M15 context, M5 sweep/CHoCH/FVG signal engine, persistence modules, and synthetic MT5 fixture scripts. It does **not** contain a completed or validated trading EA. MetaEditor compilation and MT5 Strategy Tester execution remain pending. No compile, backtest, or broker-compatibility claim is valid until the corresponding test has actually been run and its evidence recorded.

## License

See [LICENSE](LICENSE).