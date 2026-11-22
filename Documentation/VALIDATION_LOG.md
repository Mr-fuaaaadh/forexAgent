# MT5 validation log

## Session date

2026-11-22 (user-reported terminal output; timestamps below are broker/terminal log times).

## Environment and configuration

- Platform: MetaTrader 5 / MetaEditor, broker demo environment.
- Instrument: XAUUSD.
- EA: `PriceActionHybridEA.mq5`.
- Trading inputs: `InpEnableTrading=false`, `InpAllowLiveTrading=false`.
- Other reported inputs: Magic Number 120026; RiskPercent 0.5; HistoryBars 500; SwingLookback 80; MaximumSetupBars 12.
- No order execution is implemented in the current root EA.

## MetaEditor compilation

User-reported compile output:

```text
PriceActionHybridEA.mq5
M5EntrySignal.mqh
MultiTimeframeContext.mqh
MarketStructure.mqh
StructurePersistence.mqh
M5SetupPersistence.mqh
code generated 0
0 errors, 0 warnings
```

Result: **PASS — compile**, based on user-provided MetaEditor output. The exact terminal build number was not included in the supplied evidence.

## XAUUSD chart initialization and context arbitration

User-reported Experts log included:

```text
SIGNAL-ONLY EA READY | symbol=XAUUSD | H1=-1 | M15=1 | context=PA_CONTEXT_NO_TRADE | trading=false | live=false
Signal-only EA deinitialized. Reason=3
```

The EA initialized on XAUUSD chart instances. H1 direction -1 and M15 direction +1 are conflicting, so `PA_CONTEXT_NO_TRADE` is the expected fail-closed outcome. The terminal log also reported timeframe changes and deinitialization reason 3 (chart change); this is not, by itself, an EA runtime error.

Result: **PASS — initialization observed; conflicting HTF context blocked**.

No qualified BUY/SELL signal was present in the supplied chart log. A sustained sequence of closed-M5-bar evaluations has not yet been evidenced.

## Strategy Tester data limitations

User-reported tester settings:
- Requested date interval: 2024-01-01 to 2026-11-21.
- Symbol/timeframe: XAUUSD M5.
- Both trading toggles false.
- Modelling: generated ticks because the log stated no real ticks were available.

Observed data constraints:
- Synchronized history was reported from 2024-06-21 through 2026-07-27, not the full requested interval.
- Initial cache report showed only 276 M5 bars for 2024-06-21 01:00 through 23:55, 23 H1 bars, and 92 M15 bars.
- Tester log reported `no real ticks, every tick generation used`.
- One observed decision was `NO SIGNAL` with reason `NO_QUALIFIED_LIQUIDITY_SWEEP`. This is a normal no-setup outcome, not a failure.

Result: **INCONCLUSIVE — not a valid full-period strategy backtest**. Do not infer profitability, strategy quality, or complete historical coverage from this run.

## Not yet validated

- MT5 execution of all synthetic fixture scripts.
- Primary signal generation on a confirmed live/demo closed M5 sequence.
- Secondary BOS/OB, breakout/retest, and trend-pullback runtime integration (these modules are not called by the root EA yet).
- Unified primary + secondary arbitration in the actual EA runtime.
- Restart/replay and persistence recovery.
- Full Strategy Tester run with adequate history and documented modelling/cost assumptions.
- Broker contract compatibility, risk sizing, execution, SL/TP, position management, calendar/session filters, and demo forward performance.

## Safety conclusion

Keep `InpEnableTrading=false` and `InpAllowLiveTrading=false`. This build is signal-only and not production-ready. Compilation and initialization evidence does not authorize order execution or demonstrate profitability.
