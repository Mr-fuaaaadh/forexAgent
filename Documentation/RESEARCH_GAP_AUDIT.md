# Research-to-code gap audit

## Scope and safety
This audit compares current repository source with the agreed XAUUSD hybrid research target. It is a documentation/source-inspection exercise only; no MQL5 behavior is changed here. Execution remains false-by-default and the order path is restricted to DEMO + HEDGING.

## Target configuration
- Instrument: XAUUSD; M5 entries; H1 + M15 context.
- Account target: USD 5,000 demo, hedging.
- Risk: 0.5% per trade; max 3 managed positions; max aggregate open risk 1.5%.
- Daily internal loss lock: 2%; static max loss: 12%; profit target: 10%.
- Models A/B/C/D; hybrid frequency target balanced.
- Live trading is out of scope and blocked by current execution account checks.

## Model-by-model comparison

| Model | Research definition | Current repository | Status |
|---|---|---|---|
| A — trend pullback | H1 HH/HL or LL/LH; M15 aligned; pullback to broken swing within ±0.15 × M15 ATR; M5 rejection and continuation break | H1/M15 alignment + M15 BOS + broken swing pullback reference + M5 higher-low/lower-high continuation. Explicit H1 swing-sequence qualification and exact M15 ATR band are not fully implemented. | Partial |
| B — liquidity sweep reversal | Sweep of M15 swing or prior-day high/low; minimum sweep distance; reclaim in sweep candle or next 2 M5 bars; M5 MSS/CHoCH and trigger confirmation | Primary stages sweep → later CHoCH → directional FVG → FVG retest/confirmation. Related but different variant; prior-day levels and two-bar reclaim are not established as equivalent. | Partial / variant differs |
| C — compression breakout | Range from 12 completed M15 candles; width 0.8–3.0 × M15 ATR; close outside by ≥0.10 × ATR; retest within 6 M5 bars | Secondary breakout requires aligned M15 BOS and BOS body >0.5 × M15 ATR, then M5 retest/confirmation; expiry is 36 M5 bars. Full range/compression definition and six-bar deadline are absent. | Partial |
| D — session expansion | Asian range UTC 00:00–06:00; London 07:00–10:00; New York 13:00–16:00; breakout/retest; DST-safe timezone handling | No session expansion model found in current root/runtime/secondary modules. | Missing |

## Hybrid selection logic
Current implementation uses fixed priority arbitration: primary sweep/CHoCH/FVG, BOS/OB, breakout/retest, trend pullback. It rejects any same-decision direction conflict. This is not the requested regime-aware router. The research target calls for eligibility based on trend, range/liquidity, compression/expansion, and session-expansion regimes. Model D and the router are separate missing deliverables.

## Execution and risk comparison

### Present in source
- `InpEnableTrading=false` by default; DEMO account and HEDGING margin mode required.
- Terminal connection and account/expert trading permissions checked.
- Risk-based volume uses `OrderCalcProfit()`, rounds down to broker volume step, and recalculates.
- 0.5% per-trade risk, 3 managed positions, 1.5% aggregate open risk.
- Internal daily equity-loss guard 2%, additional challenge daily threshold 4%, static loss 12%, target 10%.
- Challenge initial balance is required and persisted; day-start equity baseline is required before execution activates.
- Broker minimum stop distance, margin availability, and `OrderCheck()` are checked.
- Setup ID reservation prevents automatic duplicate resubmission.
- Managed-position guard checks missing/uncomputable SL and attempts to close managed positions.

### Gaps requiring hardening
1. **Stop buffer conflict:** research notes specify at least max(0.05 × ATR, 2 × spread), while an earlier note uses 0.10 × M5 ATR. Current execution sets SL at raw signal invalidation. Freeze one formula before coding.
2. **Spread filter:** no explicit absolute max spread or spread/M5-ATR cap in the order path.
3. **Post-fill verification:** actual fill price, filled volume, broker-side SL/TP, and realized initial risk are not reconciled after fill/partial fill.
4. **Trade lifecycle:** ambiguous outcomes are fail-closed by keeping setup reserved, but a complete transaction/recovery state machine is not present.
5. **Account currency and contract:** challenge amounts are interpreted in account currency; no explicit USD account-currency validation/conversion layer is present. Validate currency and XAUUSD contract metadata before execution.
6. **Challenge day count:** current marker records an EA-owned entry day and the minimum-day predicate checks marker existence; it is not a distinct-day counter.
7. **Daily guard:** internal 2% limit is stricter than the separate 4% challenge threshold, so 4% is a secondary ceiling.
8. **Other controls:** no verified weekly loss, trades/day cap, consecutive-loss pause, cooldown, news filter, rollover/session filter, or slippage-quality filter in the current execution path.
9. **SL/TP policy:** current target is fixed 2R; cost-aware minimum-R and alternative 1.5R/2.5R comparisons remain research tasks.

## Validation gaps
- Current code/fixtures need strict MetaEditor compilation and fixture execution on the target terminal.
- Prior user-reported compile evidence belongs to an earlier source snapshot and is not proof for the current revision.
- Supplied Strategy Tester run had incomplete history and generated ticks; it is inconclusive.
- Test each model independently before hybrid portfolio testing.
- Preserve final out-of-sample data; perform walk-forward, parameter sensitivity, cost stress, Monte Carlo, and demo forward tests.

## Recommended implementation order after specification freeze
1. Freeze model definitions, including B1/B2 choice, C range formula, D timezone/DST policy, and SL buffer.
2. Implement model-specific rule changes with deterministic fixtures; keep strategy and execution changes separate.
3. Add regime router and duplicate/correlation controls.
4. Harden execution: spread, stop buffer, post-fill verification, transaction lifecycle, currency/contract checks, and persisted challenge state.
5. Run reproducible historical, out-of-sample, stress, and demo-forward validation.

## Acceptance boundary
This audit does not claim any model is profitable, the hybrid is complete, or execution is ready for live use. Live trading remains out of scope.
