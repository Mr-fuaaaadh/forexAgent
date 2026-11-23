# XAUUSD hybrid strategy specification — frozen research baseline

> Status: **Specification frozen; implementation and validation pending.** This document defines the mechanical research baseline for the next implementation phase. It does not describe all current code as already implemented.

## 1. Scope, account, and safety

- Instrument: XAUUSD.
- Entry timeframe: M5. Context and structure: M15 + H1.
- Intended terminal: MetaTrader 5 DEMO account, HEDGING margin mode, USD 5,000 initial balance.
- Risk baseline: 0.5% equity per trade; maximum 3 EA-managed open positions; maximum aggregate open risk 1.5%.
- Guardrails: internal daily equity-loss lock 2%; static maximum loss 12%; profit target 10%.
- The dollar equivalents at the initial balance are $25 risk/trade, $75 aggregate open risk, $100 daily loss, $600 static loss and $500 target. Recalculate percentage limits against the configured reference balance/equity as specified by the risk module; do not hard-code these dollar figures as universal values.
- Execution remains DEMO + HEDGING only. `InpEnableTrading=false` remains the default. No live-account path or live enablement is in scope.

## 2. Shared data and signal timing

- Evaluate once when a new M5 bar opens, using only the just-completed M5 bar and previously completed higher-timeframe bars.
- Never use bar 0 as a signal candle. All pivots, ranges, BOS, CHoCH/MSS, FVGs, and confirmations must be based on closed bars.
- Confirmed swing pivots use three bars on each side; a pivot is unavailable until all three right-side bars have closed.
- BOS requires a completed candle close beyond a confirmed swing; wick-only breaks do not qualify.
- CHoCH/MSS requires a completed close beyond the protected internal swing against the prior structure direction.
- Use broker/server timestamps for bar identity and persisted state. Session calculations must use the timezone rules in Model D below.
- A setup is invalid after its stated expiry, if its invalidation level is breached, if the required context reverses, or if its source event has already been consumed.

## 3. Model A — trend pullback

1. H1 trend must be explicit: bullish requires a confirmed sequence of higher high and higher low; bearish requires lower low and lower high. A single BOS alone is not sufficient.
2. M15 directional structure must agree with H1.
3. Identify the M15 swing level whose completed-bar BOS established the continuation direction.
4. The pullback zone is the broken swing level ±0.15 × M15 ATR(14), measured from completed M15 data.
5. Wait for price to enter the zone. On M5 require a directional rejection candle, then a completed close breaking the rejection candle's confirming swing in the trend direction.
6. Reject if H1/M15 alignment is lost, the broken swing is structurally invalidated, or the setup expires.
7. Maximum holding period for research exits: 24 completed M5 bars after entry.

## 4. Model B — liquidity sweep reversal (two independent variants)

Both variants require a sweep of a confirmed M15 swing high/low or the previous trading day's high/low. The excursion beyond the reference must be at least max(0.05 × M15 ATR(14), 2 × current spread). The sweep must be followed by a close back inside/across the swept level. Use the same completed-bar and invalidation rules for both variants.

### B1 — staged sweep → CHoCH → FVG → retest

1. Record a qualifying sweep and its extreme.
2. A later completed M5 candle must confirm CHoCH/MSS in the reversal direction. The sweep candle itself cannot also satisfy this later-stage CHoCH.
3. Require a completed directional M5 fair-value gap (three-candle imbalance) formed after the CHoCH.
4. Wait for a subsequent retest/overlap of that FVG and a completed M5 directional confirmation. Entry trigger is the break of the confirmation candle in the reversal direction.
5. Cancel on sweep-extreme breach, FVG invalidation, opposing higher-timeframe context, or expiry.
6. Maximum holding period: 12 completed M5 bars after entry.

### B2 — sweep → fast reclaim → MSS → trigger

1. Record the same qualifying M15 swing or previous-day-level sweep.
2. Reclaim must occur on the sweep candle or within the next two completed M5 candles: a close back across the swept reference is required.
3. After reclaim, require a distinct completed M5 internal MSS/CHoCH in the reversal direction. The reclaim candle cannot also count as the MSS candle.
4. Enter only after a later completed M5 candle confirms direction and price breaks its confirmation trigger in the reversal direction.
5. Cancel if reclaim deadline is missed, sweep extreme is breached, MSS fails, context invalidates, or setup expires.
6. Maximum holding period: 12 completed M5 bars after entry.

B1 and B2 must be labelled, tested, and reported separately before any combined B-family result is reported. They are not interchangeable and must not share a setup ID.

## 5. Model C — compression breakout and retest

1. Build the range from the high and low of the 12 most recent completed M15 candles immediately before the breakout evaluation. Do not include the forming M15 candle.
2. Range width must be between 0.8 and 3.0 × M15 ATR(14), inclusive.
3. A breakout requires a completed M15 close outside the range by at least 0.10 × M15 ATR(14).
4. Within the next six completed M5 bars, price must retest the broken range boundary. A retest is an M5 bar whose range touches or crosses the boundary without closing back through the opposite side of the range.
5. Require a later completed M5 directional confirmation; entry trigger is a break of that confirmation candle in the breakout direction.
6. Cancel if price closes back inside the range beyond the boundary, the six-bar retest deadline is missed, or context invalidates.
7. Maximum holding period: 12 completed M5 bars after entry.

## 6. Model D — session range expansion

### Timezone contract

- Asian range: 00:00–06:00 UTC, fixed UTC.
- London expansion window: 07:00–10:00 Europe/London local time.
- New York expansion window: 08:00–11:00 America/New_York local time.
- London and New York windows are local wall-clock windows and therefore follow their respective daylight-saving transitions automatically. Convert each window to UTC using the IANA timezone rules for the relevant date; do not hard-code a single UTC offset. If the platform cannot reliably resolve these zones and historical DST transitions, Model D must remain disabled rather than use an approximate offset.
- The Asian range is calculated from completed M5 bars within the fixed UTC interval for the current UTC date.

### Setup rules

1. Freeze the Asian high and low after 06:00 UTC.
2. During a configured London or New York window, require a completed M5 close beyond the Asian range high or low. Wick-only breaks do not qualify.
3. Wait for a retest of the broken boundary within the next six completed M5 bars.
4. Require a later completed M5 directional confirmation and trigger break in the breakout direction.
5. Cancel if price closes back through the range boundary, the retest deadline is missed, the session window ends before confirmation, or the setup invalidates.
6. Treat London and New York as distinct session events; prevent duplicate entries from the same breakout event.
7. Maximum holding period: 18 completed M5 bars after entry.

## 7. Stop, target, and exit baseline

- Structural invalidation is model-specific: beyond the sweep extreme (B), beyond the pullback/rejection structure (A), beyond the retest structure/range invalidation (C/D).
- Place the protective stop beyond structural invalidation by a buffer:
  `buffer = max(0.10 × M5 ATR(14), 2 × current spread)`.
- Apply the buffer on the correct side of the invalidation level. Reject a trade if the resulting stop is invalid, violates broker stop/freeze constraints, or cannot be sized within the risk budget.
- Baseline take-profit is fixed 2R, where R is the entry-to-stop distance at the executable fill. No trailing stop, partial close, or break-even move in the baseline experiment.
- Compare 1.5R and 2.5R as separate research variants; do not mix their results with the 2R baseline.
- Apply the model-specific maximum holding periods above as a time exit if neither stop nor target has executed.
- Spread, commission, swap, slippage, and actual fill price must be included in net performance and risk calculations.

## 8. Hybrid regime router and conflict policy

The future router must classify a single completed-bar market state before selecting an eligible model. Precedence is:
1. **Session expansion:** if a valid Model D window is active and an Asian-range breakout event qualifies, Model D is eligible.
2. **Compression/expansion:** otherwise, if the 12-bar Model C range criteria are satisfied and breakout conditions qualify, Model C is eligible.
3. **Trend:** otherwise, if explicit H1 structure and M15 alignment qualify, Model A is eligible.
4. **Range/liquidity:** otherwise, Model B1/B2 may qualify from a valid sweep event.
5. If none qualifies, do not trade.

This is an eligibility router, not permission to force a trade. No model may enter when its own conditions are incomplete. If simultaneously qualified candidates point in opposing directions, reject the decision. If multiple same-direction candidates remain eligible, choose only one using the precedence above; do not open duplicate trades from one market event. B1 and B2 are separate experiments; the production selection between them is deferred until independent results exist.

## 9. Filters and controls for the first comparison

- News filter: disabled for the first controlled model comparison so it does not confound the baseline. Evaluate a separately documented high-impact USD news filter later; do not infer that disabled means news risk is absent.
- No additional discretionary indicators or manual overrides.
- Existing portfolio risk limits remain unchanged. Enforce the 0.5% per-trade and 1.5% aggregate open-risk limits across all models together, not per model.
- The first research comparison must use identical data, cost assumptions, and risk sizing across A, B1, B2, C, D, and the hybrid.

## 10. Research acceptance boundary

Test each model independently before hybrid routing. Development: 2018–2022; validation: 2023–2024; untouched out-of-sample: 2025 through October 2026 (subject to verified data availability). Do not tune on validation or OOS data.

Research gates: OOS profit factor ≥1.20, positive net expectancy, max drawdown ≤8% preferred, ideally 100+ OOS trades per model, majority of tested years positive, positive expectancy under 1.5× spread stress, and robustness across nearby parameter values. These are screening criteria, not performance promises or guarantees. Report any model with insufficient sample size as inconclusive rather than passing.
