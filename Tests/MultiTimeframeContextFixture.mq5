//+------------------------------------------------------------------+
//| MultiTimeframeContextFixture.mq5                                 |
//| Synthetic arbitration and persistence tests. No trading.         |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "..\Include\MultiTimeframeContext.mqh"

int g_passed = 0;
int g_failed = 0;

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
   PA_StructureState h1,m15,loaded;
   PA_ResetStructureState(h1);
   PA_ResetStructureState(m15);

   h1.direction = 1;
   h1.last_processed_bar_time = TimeCurrent()-3600;
   m15.direction = 1;
   m15.last_processed_bar_time = TimeCurrent()-900;
   Check("H1 bullish + M15 bullish permits bullish context",
         PA_ResolveMultiTimeframeContext(h1,m15)==PA_CONTEXT_BULLISH_ALIGNED);

   m15.direction = -1;
   Check("H1 bullish + M15 bearish is blocked",
         PA_ResolveMultiTimeframeContext(h1,m15)==PA_CONTEXT_NO_TRADE);

   h1.direction = -1;
   Check("H1 bearish + M15 bearish permits bearish context",
         PA_ResolveMultiTimeframeContext(h1,m15)==PA_CONTEXT_BEARISH_ALIGNED);

   h1.direction = 0;
   m15.direction = 1;
   m15.reversal_candidate_direction = 1;
   m15.reversal_choch_time = TimeCurrent()-1800;
   m15.confirmed_reversal_direction = 0;
   Check("Neutral H1 with CHoCH only is blocked",
         PA_ResolveMultiTimeframeContext(h1,m15)==PA_CONTEXT_NO_TRADE);

   m15.confirmed_reversal_direction = 1;
   m15.confirmed_reversal_time = TimeCurrent()-900;
   Check("Neutral H1 with CHoCH then subsequent BOS qualifies",
         PA_ResolveMultiTimeframeContext(h1,m15)==PA_CONTEXT_NEUTRAL_REVERSAL_BULLISH);

   m15.confirmed_reversal_time = m15.reversal_choch_time;
   Check("Reversal BOS must occur after CHoCH",
         PA_ResolveMultiTimeframeContext(h1,m15)==PA_CONTEXT_NO_TRADE);

   // Persistence round-trip with an isolated Magic Number namespace.
   PA_ResetStructureState(h1);
   h1.direction = -1;
   h1.latest_swing_high = 2450.5;
   h1.latest_swing_low = 2430.25;
   h1.latest_swing_high_time = TimeCurrent()-7200;
   h1.latest_swing_low_time = TimeCurrent()-3600;
   h1.protected_high = 2450.5;
   h1.protected_high_time = h1.latest_swing_high_time;
   h1.last_processed_bar_time = TimeCurrent()-60;
   h1.last_structure_event_time = TimeCurrent()-120;
   h1.last_break_type = PA_BREAK_BOS_BEARISH;
   h1.reversal_candidate_direction = 1;
   h1.reversal_choch_time = TimeCurrent()-180;
   h1.confirmed_reversal_direction = 1;
   h1.confirmed_reversal_time = TimeCurrent()-120;

   const long test_magic = 9900123;
   const bool saved = PA_SaveStructureState(_Symbol,PERIOD_H1,test_magic,h1);
   const bool restored = PA_LoadStructureState(_Symbol,PERIOD_H1,test_magic,loaded);
   Check("Structure state saves and restores",saved && restored);
   Check("Restored direction and protected swing match",
         loaded.direction==-1 &&
         MathAbs(loaded.protected_high-2450.5)<0.000001 &&
         loaded.last_processed_bar_time==h1.last_processed_bar_time);
   Check("Restored reversal sequence matches",
         loaded.reversal_candidate_direction==1 &&
         loaded.confirmed_reversal_direction==1 &&
         loaded.confirmed_reversal_time==h1.confirmed_reversal_time);

   Print("Multi-timeframe fixtures complete. Passed=",g_passed,
         " Failed=",g_failed);
  }
