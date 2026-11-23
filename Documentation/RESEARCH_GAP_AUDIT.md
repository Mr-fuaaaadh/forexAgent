# Research-to-code gap audit

## Scope and safety

This audit compares current repository source with the frozen XAUUSD hybrid research baseline. The specification is frozen in `STRATEGY_RULES.md`; this does not mean the rules are implemented or validated. This update is documentation-only; no MQL5 behavior is changed. Execution remains false-by-default and restricted to DEMO + HEDGING.

## Frozen target configuration

- Instrument: XAUUSD; M5 entries; H1 + M15 context.
- Account target: USD 5,000 demo, hedging.
- Risk: 0.5% per trade; max 3 managed positions; max aggregate open risk 1.5%.
- Daily internal loss lock: 2%; static max loss: 12%; profit target: 10%.
- Models A, B1, B2, C, D; balanced-frequency hybrid objective.
- Stop buffer: max(0.10 × M5 ATR(14), 2 × spread); baseline TP 2R; compare 1.5R and 2.5R separately.
- Initial controlled model comparison has news filter disabled.
- Live trading is out of scope; current execution checks remain DEMO + HEDGING only.

## Frozen model definitions versus current repository

| Model | Frozen research definition | Current repository | Status |
|---|---|---|---|
| A — trend pullback | H1 HH/HL or LL/LH; M15 aligned; pullback to broken swing ±0.15 × M15 ATR; M5 rejection and later continuation break; 24-bar time exit | Implemented signal path: two confirmed H1 highs/lows checked for HH/HL or LL/LH; M15 BOS freezes the ±0.15 ATR band; M5 rejection must be followed by a separate close beyond the rejection candle. Post-entry 24-bar time exit remains pending. | Signal generation implemented; compile/fixture execution and time exit pending |
| B1 — staged liquidity reversal | M15 swing/previous-day sweep; minimum excursion; later M5 CHoCH; post-CHoCH FVG; later retest/confirmation; 12-bar time exit | Primary path stages sweep → later CHoCH → directional FVG → retest/confirmation. Previous-day references and exact frozen sweep threshold require verification. | Partial / closest |
| B2 — fast-reclaim reversal | Sweep; reclaim on sweep candle or next 2 M5 bars; distinct later MSS; later confirmation/trigger; 12-bar time exit | Implemented as an independent persisted state machine using confirmed M15 swing / previous completed D1 sweep references, bounded reclaim, distinct MSS, later confirmation and trigger. | Signal generation implemented; compile/fixture execution and 12-bar position time exit pending |
| C — compression breakout | 12 completed M15 bars; range 0.8–3.0 × M15 ATR; close outside by ≥0.10 ATR; M5 retest within 6 bars; later confirmation; 12-bar time exit | Existing secondary breakout uses aligned M15 BOS with body >0.5 × M15 ATR and M5 retest/confirmation; full range/compression formula and deadline are absent. | Partial / differs |
| D — session expansion | Asian 00:00–06:00 UTC; London 07:00–10:00 Europe/London; New York 08:00–11:00 America/New_York; DST-safe; breakout/retest/confirmation; 18-bar time exit | No session expansion model found in current root/runtime/secondary modules. | Missing |

## Hybrid routing

Frozen router precedence: session expansion D → compression/expansion C → trend A → range/liquidity B. Opposing qualified directions reject the decision; same-direction simultaneous candidates select one only; no qualifying regime means no trade. Current implementation uses fixed priority arbitration: primary sweep/CHoCH/FVG, BOS/OB, breakout/retest, trend pullback. It rejects any same-decision direction conflict. This is not the frozen regime-aware router.

## Execution and risk comparison

### Present in source (as previously inspected)

- `InpEnableTrading=false` by default; DEMO account and HEDGING margin mode required.
- Terminal connection and account/expert trading permissions checked.
- Risk-based volume uses `OrderCalcProfit()`, rounds down to broker volume step, and recalculates.
- 0.5% per-trade risk, 3 managed positions, 1.5% aggregate open risk.
- Internal daily equity-loss guard 2%, additional challenge daily threshold 4%, static loss 12%, target 10%.
- Challenge initial balance is required and persisted; day-start equity baseline is required before execution activates.
- Broker minimum stop distance, margin availability, and `OrderCheck()` are checked.
- Setup ID reservation prevents automatic duplicate resubmission.
- Managed-position guard checks missing/uncomputable SL and attempts to close managed positions.

### Frozen requirements still requiring implementation or verification

1. **Stop buffer:** frozen as max(0.10 × M5 ATR(14), 2 × spread). Current execution was observed to use raw signal invalidation.
2. **Spread filter:** no explicit absolute max spread or spread/M5-ATR cap in the order path.
3. **Post-fill verification:** actual fill price, filled volume, broker-side SL/TP, and realized initial risk are not reconciled after fill/partial fill.
4. **Trade lifecycle:** ambiguous outcomes are fail-closed by keeping setup reserved, but a complete transaction/recovery state machine is not present.
5. **Account currency and contract:** challenge amounts are interpreted in account currency; no explicit USD account-currency validation/conversion layer is present.
6. **Challenge day count:** current marker records an EA-owned entry day and minimum-day predicate checks marker existence; it is not a distinct-day counter.
7. **Time exits:** frozen model-specific holding limits are not confirmed implemented.
8. **Session timezone:** Model D requires IANA timezone/DST handling and must fail closed if unavailable.
9. **News filter:** disabled only for initial controlled comparison; no conclusion about news exposure or later filter design.
10. **Other controls:** no verified weekly loss, trades/day cap, consecutive-loss pause, cooldown, rollover filter, or slippage-quality filter in the current execution path.
11. **TP research:** current target is fixed 2R; 1.5R and 2.5R are separate comparison runs, not yet evidenced.

## Validation gaps

- Current code/fixtures need strict MetaEditor compilation and fixture execution on the target terminal.
- Prior user-reported compile evidence belongs to an earlier source snapshot and is not proof for the current revision.
- Supplied Strategy Tester run had incomplete history and generated ticks; it is inconclusive.
- Test A, B1, B2, C, and D independently before hybrid portfolio testing.
- Preserve final out-of-sample data; perform walk-forward, parameter sensitivity, cost stress, Monte Carlo, and DEMO forward tests.

## Research acceptance boundary

Initial data split: development 2018–2022, validation 2023–2024, untouched OOS 2025–October 2026, subject to verified history availability. Research gates are screening criteria, not guarantees: OOS PF ≥1.20, positive net expectancy, max DD ≤8% preferred, ideally 100+ OOS trades/model, majority years positive, and positive expectancy under 1.5× spread stress. Report inadequate sample sizes as inconclusive. No model is currently claimed profitable or validated.


### Model B2 implementation update
- Added independent B2 sweep/reclaim/MSS/confirmation/trigger state machine.
- Sweep references: latest confirmed M15 swing and previous completed D1 high/low.
- Reclaim deadline: sweep candle or next two completed M5 candles.
- MSS, confirmation and trigger require later completed candles.
- B2 accepts aligned or explicit neutral-reversal directional context; other secondary continuation models retain strict alignment.
- MetaEditor compile, fixture execution and backtesting remain pending; implementation is not evidence of profitability.
