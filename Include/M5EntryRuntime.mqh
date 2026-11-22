//+------------------------------------------------------------------+
//| M5EntryRuntime.mqh                                                |
//| Persistence wrapper for the M5 signal engine. No trade execution. |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_M5_ENTRY_RUNTIME_MQH
#define FOREX_AGENT_M5_ENTRY_RUNTIME_MQH

#include "M5SetupPersistence.mqh"

// Call once per M5 candle from the EA's new-bar dispatcher.
// H1/M15 context must already be refreshed and valid for this decision.
// State restoration failures initialize a clean state; the caller should
// log the first-run/rebuild condition and block if market history is short.
bool PA_RunPersistentM5Signal(const string symbol,
                              const long magic_number,
                              const MqlRates &m5_rates[],
                              const int m5_count,
                              const double spread_price,
                              const PA_MultiTimeframeSnapshot &context,
                              PA_StructureState &m5_structure,
                              PA_M5SetupState &m5_setup,
                              PA_M5Signal &signal,
                              const int maximum_setup_bars=12)
  {
   if(symbol=="" || magic_number<=0 || m5_count<20)
     {
      PA_ResetM5Signal(signal);
      signal.rejection_reason="INVALID_RUNTIME_INPUT";
      return false;
     }

   if(m5_structure.last_processed_bar_time<=0)
     {
      if(!PA_LoadStructureState(symbol,PERIOD_M5,magic_number,m5_structure))
         PA_ResetStructureState(m5_structure);
     }

   if(m5_setup.last_processed_bar_time<=0)
     {
      if(!PA_LoadM5SetupState(symbol,magic_number,m5_setup))
         PA_ResetM5SetupState(m5_setup);
     }

   const bool evaluated=PA_EvaluateM5EntrySignal(
      symbol,m5_rates,m5_count,spread_price,context,
      m5_structure,m5_setup,signal,maximum_setup_bars);

   // Persist even a no-signal decision so the last candle is not replayed.
   const bool structure_saved=PA_SaveStructureState(
      symbol,PERIOD_M5,magic_number,m5_structure);
   const bool setup_saved=PA_SaveM5SetupState(
      symbol,magic_number,m5_setup);

   if(!structure_saved || !setup_saved)
     {
      signal.signal=PA_ENTRY_NONE;
      signal.setup_id="";
      signal.rejection_reason="STATE_PERSISTENCE_FAILED_FAIL_CLOSED";
      return false;
     }
   return evaluated;
  }

#endif // FOREX_AGENT_M5_ENTRY_RUNTIME_MQH
