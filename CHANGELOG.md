# Changelog

All notable project changes are recorded here.

## Unreleased\n- Added pending-setup invalidation when H1/M15 context flips, price closes through the sweep extreme, or the FVG is invalidated.\n- Added a synthetic fixture for opposite higher-timeframe direction invalidation.
- Added M5 primary entry signal state machine: sweep, later CHoCH, directional FVG, then FVG retest confirmation.
- Added persistent M5 setup state and restart-safe emitted setup ID hash marker.
- Added M5 runtime wrapper and synthetic bullish and bearish sequence fixtures; MT5 execution remains pending.
- Fixed structure state advancement so candles without newly confirmed pivots do not stall the closed-bar state machine.
- Added H1/M15 context evaluation with strict directional conflict rejection and neutral-H1 CHoCH-then-BOS reversal qualification.
- Added terminal Global Variable persistence for timeframe structure state, keyed by account, Magic Number, symbol, and timeframe.
- Added chronological timeframe history reconstruction and missed-closed-bar advancement.
- Added synthetic multi-timeframe arbitration and persistence fixture; MT5 execution remains pending.
- Added protected-swing BOS/CHoCH state tracking with a duplicate closed-bar guard.
- Added `Tests/MarketStructureFixture.mq5` synthetic test script for both directional BOS/CHoCH transitions; execution in MT5 is pending.
- Added initial closed-bar market-structure primitives in `Include/MarketStructure.mqh`.
- Added market-structure engine documentation and deterministic test cases.
- MetaEditor compilation and MT5 Strategy Tester validation remain pending.
- Initialized project specification and AI-agent workflow.
- Documented strategy, risk, broker compatibility, installation, configuration, testing, troubleshooting, and roadmap.
- EA implementation and validation are not yet complete.
