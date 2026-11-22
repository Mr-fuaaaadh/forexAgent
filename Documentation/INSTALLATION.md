# Installation

## Prerequisites
- Windows or another supported MetaTrader 5 desktop environment.
- MetaTrader 5 terminal connected to a broker demo account.
- MetaEditor (installed with MT5).
- XAUUSD or an explicitly configured, validated broker symbol variant.

## Current status
The repository currently contains specifications and documentation only. There is no completed EA source to install yet.

## Planned installation after implementation
1. Clone/download the repository.
2. Open the `.mq5` source in MetaEditor.
3. Compile with strict settings and resolve all errors/warnings.
4. Copy the compiled `.ex5` into the terminal's `MQL5/Experts` directory if needed.
5. Attach to the correct XAUUSD chart and verify symbol mapping.
6. Keep trading disabled; configure demo-only settings and review the Experts/Journal logs.
7. Run Strategy Tester scenarios and forward-test on demo before considering any live deployment.

Never install an unreviewed binary from an unknown source. Do not enable live trading based solely on a successful compile.
