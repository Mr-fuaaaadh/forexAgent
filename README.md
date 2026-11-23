# MT5 Price Action Hybrid EA

**Project:** Price Action Hybrid EA v1.3  
**Platform:** MetaTrader 5 (MQL5)  
**Instrument:** XAUUSD (broker suffixes are accepted only when symbol metadata reports base XAU and profit USD)  
**Runtime:** Signal-only by default; optional execution is restricted in code to DEMO + HEDGING accounts  
**Development status:** Strategy signal modules and root runtime arbitration are integrated. A demo-only order path and challenge risk guards are present. This is an experimental engineering build, not a validated trading system.

> **Risk warning:** Automated trading can lose money rapidly. A compile, chart attachment, accepted demo order, or historical test does not establish profitability or production readiness. Keep execution disabled until the separate demo validation checklist is completed. Live-account execution is intentionally blocked by the execution module.

## Project goal

Build a deterministic, testable MT5 Expert Advisor using H1 context, M15 structure, and M5 entry decisions. The current source combines a primary liquidity-sweep strategy with three secondary signal modules and one arbitration point.

## Safety defaults and account restrictions

- `InpEnableTrading=false` by default.
- There is no user-configurable live-trading enable switch in this build.
- The execution module accepts only a MetaTrader DEMO account in HEDGING mode and checks terminal/account/expert trading permissions.
- If execution is disabled, the EA remains signal-only.
- If execution is enabled but a valid broker-server day-start equity baseline is unavailable, the EA remains attached in signal-only/pending mode and sends no orders.
- Risk sizing uses `OrderCalcProfit()`; volume is rounded down to broker volume steps.
- Only positions matching this EA's symbol and Magic Number are counted/managed.
- Do not treat the presence of execution code as permission to use a live account.

## Current strategy runtime

1. Primary: liquidity sweep → later CHoCH → directional FVG → retest/confirmation.
2. Secondary: BOS + order-block retest.
3. Secondary: M15 BOS breakout + retest.
4. Secondary: H1/M15 trend continuation + pullback.

The root EA evaluates the primary and secondary signal paths on the same newly closed M5 decision, then calls unified arbitration. Opposing qualified directions reject the decision. The selected signal is sent to the demo execution module only when its safety initialization is ready; otherwise it is logged as signal-only.

These are the current implemented mechanical modules, not a completed implementation of every research model A/B/C/D. See [Research-to-code gap audit](Documentation/RESEARCH_GAP_AUDIT.md).

## Current execution controls

- Risk per trade: 0.5% of current equity.
- Maximum EA-owned positions: 3 (hedging account required).
- Maximum combined open risk: 1.5% of current equity.
- Internal daily equity-loss lock: 2% from the captured broker-server day-start equity.
- Additional challenge daily threshold: 4%; the 2% internal threshold is stricter and normally triggers first.
- Static maximum loss: 12% below configured challenge initial balance.
- Profit target: 10% above configured challenge initial balance, evaluated against balance; completion also checks the recorded minimum-trading-day marker.
- Risk/reward: fixed 2R.
- Challenge initial balance must be explicitly configured before execution can initialize.

Important gaps remain: no explicit maximum-spread filter, no research-specified ATR/spread stop buffer in the order path, no verified post-fill SL/TP reconciliation, and no complete broker-currency/contract compatibility matrix. Read [Risk management](Documentation/RISK_MANAGEMENT.md).

## Validation status

Compilation and chart initialization have been user-reported, but the current source revision must be recompiled and all fixtures must be run on the user's MT5 terminal after updating. The previously supplied Strategy Tester run had incomplete history and generated ticks; it is not a valid full-period real-tick backtest. See [Validation log](Documentation/VALIDATION_LOG.md).

## Documentation

- [Research-to-code gap audit](Documentation/RESEARCH_GAP_AUDIT.md)
- [Root EA runtime integration](Documentation/SIGNAL_ONLY_EA_INTEGRATION.md)
- [Secondary strategy modules](Documentation/SECONDARY_STRATEGIES.md)
- [Strategy rules](Documentation/STRATEGY_RULES.md)
- [Risk management](Documentation/RISK_MANAGEMENT.md)
- [Configuration](Documentation/CONFIGURATION.md)
- [Testing and validation](Documentation/TESTING.md)
- [Development roadmap](Documentation/DEVELOPMENT_ROADMAP.md)
- [Validation evidence](Documentation/VALIDATION_LOG.md)
- [Agent workflow](AGENTS.md)
- [Changelog](CHANGELOG.md)

## Repository status

The repository includes closed-bar structure/context processing, primary and secondary strategy signal modules, persistence, unified arbitration, demo-only order submission, risk sizing, and account/challenge guards. It is **not yet validated for live or profitable use**. Demo execution should remain disabled until source compilation, fixture execution, risk/execution edge cases, adequate historical tests, and forward demo tests are recorded.

## License

See [LICENSE](LICENSE).
