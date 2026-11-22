//+------------------------------------------------------------------+
//| UnifiedStrategyIntegrationFixture.mq5                           |
//| Tests the root-level primary/secondary arbitration contract.     |
//| No orders are ever sent.                                          |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "..\\Include\\SecondaryStrategyRuntime.mqh"

int g_passed=0;
int g_failed=0;

void Check(const string name,const bool condition)
  {
   if(condition)
     {
      g_passed++;
      Print("PASS: ",name);
     }
   else
     {
      g_failed++;
      Print("FAIL: ",name);
     }
  }

void OnStart()
  {
   PA_M5Signal primary;
   PA_ResetM5Signal(primary);
   PA_StrategySignal secondary[1];
   PA_ResetStrategySignal(secondary[0]);
   PA_StrategySignal selected;

   // Primary-only decision.
   primary.signal=PA_ENTRY_BUY;
   primary.direction=1;
   primary.signal_bar_time=D'2026.01.01 10:00';
   primary.sweep_time=D'2026.01.01 09:45';
   primary.sweep_extreme=2300.0;
   primary.fvg_lower=2301.0;
   primary.fvg_upper=2302.0;
   primary.setup_id="PRIMARY-BUY-001";
   Check("primary sweep signal passes unified arbiter",
      PA_ArbitrateAllStrategies(primary,secondary,0,selected) &&
      selected.strategy==PA_STRATEGY_SWEEP_CHOCH_FVG &&
      selected.direction==1);

   // Same-direction lower-priority secondary signal.
   secondary[0].strategy=PA_STRATEGY_BOS_OB_RETEST;
   secondary[0].direction=1;
   secondary[0].signal_bar_time=primary.signal_bar_time;
   secondary[0].source_event_time=primary.sweep_time;
   secondary[0].reference_level=2301.5;
   secondary[0].invalidation_level=2299.0;
   secondary[0].zone_low=2300.5;
   secondary[0].zone_high=2301.5;
   secondary[0].setup_id="SECONDARY-BUY-001";
   Check("primary strategy outranks same-direction secondary",
      PA_ArbitrateAllStrategies(primary,secondary,1,selected) &&
      selected.strategy==PA_STRATEGY_SWEEP_CHOCH_FVG);

   // Opposing qualified signals must reject the complete decision.
   secondary[0].direction=-1;
   Check("opposite primary and secondary directions reject all",
      !PA_ArbitrateAllStrategies(primary,secondary,1,selected) &&
      selected.rejection_reason=="CONFLICTING_QUALIFIED_STRATEGY_DIRECTIONS");

   // Secondary-only decision remains selectable.
   PA_ResetM5Signal(primary);
   secondary[0].direction=1;
   Check("secondary-only BOS/OB signal passes unified arbiter",
      PA_ArbitrateAllStrategies(primary,secondary,1,selected) &&
      selected.strategy==PA_STRATEGY_BOS_OB_RETEST &&
      selected.direction==1);

   // No qualified signal must remain a no-signal result.
   PA_ResetStrategySignal(secondary[0]);
   Check("empty strategy set produces no signal",
      !PA_ArbitrateAllStrategies(primary,secondary,0,selected) &&
      selected.strategy==PA_STRATEGY_NONE);

   PrintFormat("Unified strategy integration fixtures complete. Passed=%d Failed=%d",
      g_passed,g_failed);
  }
