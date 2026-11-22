# Strategy rules

## Timeframes and signal timing
H1 bias, M15 structure, M5 entries/exits. Evaluate entries only on a new M5 candle. Use closed candles exclusively; bar 0 is never a signal source.

## Structure primitives
- Swing high/low: a pivot with 3 bars to the left and 3 bars to the right. Confirm only after all 3 right-side bars close.
- BOS: completed candle closes beyond a confirmed swing. Wick-only breaks are invalid.
- CHoCH: completed candle closes beyond the last protected swing against the prior structure direction.
- Bullish liquidity sweep: wick trades below a confirmed swing low and candle closes back above it. Sweep distance must be at least `max(2 × spread, 0.05 × ATR(14))`; bearish is inverse.
- Bullish FVG across completed candles A/B/C: `Low(C) > High(A)`. Bearish: `High(C) < Low(A)`. Gap must be at least `max(2 × spread, 0.05 × ATR(14))`.

## Priority 1: liquidity sweep + CHoCH + FVG
BUY requires bullish H1 bias; M15 bullish structure or an explicitly permitted reversal; M5 sweep below confirmed swing low; bullish CHoCH close; completed bullish FVG/retest; and all risk/execution filters passing. SELL is inverse. Entry is at the next executable quote after confirmation.

## Priority 2: BOS + order-block retest
Identify the last opposing candle before the displacement leg that causes a confirmed BOS. Freeze the zone after confirmation. Require a retest plus M5 rejection/CHoCH confirmation.

## Priority 3: breakout + retest
Require M15 close beyond a confirmed swing, breakout body greater than 0.5 × ATR, then a retest and M5 confirmation.

## Priority 4: trend continuation + pullback
Require H1 direction, M15 BOS, pullback to confirmed support/order block, and M5 higher-low/lower-high plus continuation close.

## Direction arbitration
- If active qualified setups disagree in direction, do not trade.
- H1 bullish + M15 bearish does not authorize a short unless higher-timeframe bias has transitioned or a defined neutral-bias reversal condition is satisfied.
- Neutral H1 reversal requires M15 CHoCH followed by a subsequent M15 BOS.
- Strategy priority selects among compatible setups; it must not override a directional conflict.

## Stops and targets
- Sweep setup BUY SL below sweep low; SELL SL above sweep high.
- Buffer: `max(0.10 × ATR(14) M5, 2 × spread)`.
- Other setups use structural invalidation.
- Reject invalid, too-close, or too-wide stops.
- Default TP is 2R; minimum accepted reward/risk is 1.5R, accounting for execution costs.

## Exit behavior
A reversal exit requires M5 CHoCH followed by M15 BOS/qualifying confirmation against the position. M5 CHoCH alone is insufficient. Log standardized exit reasons as defined in risk management.

## Non-repainting requirements
Use explicit shifts and completed candle timestamps. Never use ZigZag/future-dependent pivots as confirmed signals. Restart must not reprocess the last processed M5 candle.


## Root EA runtime integration
The root `PriceActionHybridEA.mq5` evaluates the primary sweep/CHoCH/FVG state machine and the three secondary strategies on the same newly closed M5 candle. The secondary dispatcher receives the latest M15 structure state, H1/M15 context, completed M15/M5 rate series, and a same-bar M5 structure snapshot generated from a copy of the M5 state. This avoids advancing the live M5 structure state twice.

All qualified outputs pass through `PA_ArbitrateAllStrategies` once per M5 decision. Any opposing qualified directions reject the entire decision; otherwise the configured strategy priority selects one signal. Secondary state is restored at initialization, persisted during each secondary evaluation, and saved again at deinitialization. The root log reports the selected strategy and its signal zone/invalidation. This remains signal-only: no order API is called, and both trading inputs must remain false.

Validation boundary: fixture tests validate the strategy modules and arbitration behavior, but the root EA integration still requires MetaEditor compilation, fixture execution, and XAUUSD demo-chart observation. A successful compile is not evidence of trading profitability.
