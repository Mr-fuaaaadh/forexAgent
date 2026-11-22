# Troubleshooting

## EA does not initialize
Check symbol resolution, broker trade mode, account mode, available history on H1/M15/M5, input ranges, and required calendar/conversion data. Read the initialization error code and journal message.

## No trades
This may be correct. Verify `EnableTrading`, direction alignment, closed-bar confirmations, spread/ATR threshold, rollover/news blocks, cooldowns, daily/weekly lockouts, trade limits, symbol permissions, and risk sizing. Do not loosen safety filters merely to force trades.

## Invalid stops or volume
Inspect symbol tick size, stops/freeze levels, volume minimum/maximum/step, execution mode, and actual fill price. Normalize prices to tick size and volumes to step; revalidate monetary risk after rounding.

## Duplicate or missed signals
Inspect new-M5-bar timestamp, persisted last-processed candle, setup identifier, and trade transaction reconciliation. Restart must not replay an already processed candle.

## Position not protected
Treat this as critical. Check broker retcodes and position state; attempt emergency SL/TP modification. If protection cannot be verified, close the EA-owned exposure and record the event.

## Logs
Logs should include timestamp, symbol, strategy/setup ID, decision/rejection reason, risk estimate, order/deal/position identifiers, and broker retcode. Never log credentials or sensitive account data.
