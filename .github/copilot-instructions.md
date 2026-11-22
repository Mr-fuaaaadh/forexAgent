# Copilot instructions

Read the repository-root `AGENTS.md` first. Then read the relevant documents in `Documentation/` before modifying code.

This is an MT5/MQL5 XAUUSD price-action EA. Preserve all safety invariants: trading disabled by default, live trading disabled by default, closed candles only, Magic Number ownership, monetary risk sizing through `OrderCalcProfit()`, broker-side SL/TP verification, fail-closed required data, persistent loss lockouts, and no duplicate setup execution.

Do not invent test results or claim MetaEditor/Strategy Tester validation unless it was run. Keep changes small, add tests, update documentation and changelog, and report exact validation evidence. Do not add MiroFish or non-MT5 integrations.
