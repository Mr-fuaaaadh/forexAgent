# Broker compatibility

## Scope
MT5 brokers only. No broker login/server allowlist. Initial instrument is XAUUSD; detect common variants such as `XAUUSD`, `XAUUSDm`, `XAUUSD.a`, and `GOLD`.

## Symbol resolution
Resolve by validated instrument identity and symbol properties, not substring alone. If no candidate or multiple ambiguous candidates exist, fail initialization and require explicit user selection/configuration. Validate digits, point, tick size/value, contract size, volume constraints, trade mode, and market availability.

## Broker/account adaptation
Read and adapt to:
- account currency and margin mode (hedging/netting)
- tick size/value and contract specification
- minimum/maximum volume and volume step
- stops and freeze levels
- allowed filling and execution modes
- symbol trading sessions and trade permissions

Never assume a universal contract size, tick value, fill policy, or stop distance.

## Runtime safety
Check trade return codes and actual position/deal state. Handle partial fills, requotes, rejected orders, market closure, and disconnects. Verify SL/TP after fill. If a broker does not support required protection or order behavior, block the trade.

Compatibility must be tested on each target broker/demo environment. “All MT5 brokers supported” is not a valid guarantee.
