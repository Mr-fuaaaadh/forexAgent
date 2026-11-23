# MT5 validation log

## Evidence policy
This file records only evidence supplied or actually executed. Do not infer profitability from compilation, chart attachment, tester initialization, or accepted demo orders.

## User-reported session: 2026-11-22
Environment: MetaTrader 5 / MetaEditor, broker demo environment, XAUUSD.

User-reported inputs included Magic Number 120026, risk 0.5%, history bars 500, swing lookback 80, maximum setup bars 12, and both trading/execution toggles disabled at the time of the supplied log.

### MetaEditor compilation
User-reported strict compile output listed the primary signal, multi-timeframe context, market structure, and persistence modules and reported:
`code generated 0; 0 errors, 0 warnings`.

Result: **PASS — user-reported compile for the then-tested source snapshot only**. This is not proof that the current branch/revision compiles.

### Chart initialization and context arbitration
User-reported Experts output included a ready message with H1 direction -1, M15 direction +1, and `PA_CONTEXT_NO_TRADE`. Conflicting higher-timeframe directions were rejected as intended.

Result: **PASS — initialization/context observation for the then-tested snapshot**.

### Strategy Tester limitations
User-reported tester interval: 2024-01-01 to 2026-11-21, XAUUSD M5. Logs showed:
- Synchronized history beginning 2024-06-21 and ending 2026-07-27, not the complete requested interval.
- Initial cache contained only a small number of M5/M15/H1 bars.
- No real ticks were available; generated tick modelling was used.
- One no-signal reason was `NO_QUALIFIED_LIQUIDITY_SWEEP`, which is a normal no-setup outcome.

Result: **INCONCLUSIVE — not a complete-period, real-tick, strategy-performance backtest**.

## Current source status (source inspection, not terminal test evidence)
The current root source includes primary + secondary strategy arbitration and a demo-only execution path. This corrects older logs/docs that described the root as signal-only. However, no current-revision MetaEditor compile or fixture execution result is recorded in this repository update.

## Required next validation evidence
1. Compile the exact current commit in MetaEditor; record MT5 build and compiler output.
2. Run every synthetic fixture script and save Experts output.
3. Confirm root EA processes closed M5 bars once and that persistence/restart does not replay signals.
4. Keep `InpEnableTrading=false) while validating signal behavior.
5. Obtain adequate XAUUSD M1/M5/M15/H1 history and real-tick modelling where available; record broker, server, date range, modelling mode, spread, commission, swap, and report artifact.
6. Test each strategy separately before hybrid portfolio tests; preserve untouched out-of-sample data.
7. Only after separate approval, test execution on a dedicated DEMO + HEDGING account with the exact challenge balance. Verify order lifecycle, SL/TP after fill, volume, actual risk, spread, and all lockouts.
8. Complete a sustained demo forward test across the defined sessions.

## Safety conclusion
The repository contains a demo execution implementation, but its full execution lifecycle and strategy performance have not been validated by the evidence recorded here. Keep execution disabled by default. Never use a live account.
