//+------------------------------------------------------------------+
//| M5EntrySignalFixture.mq5                                         |
//| Synthetic sweep -> CHoCH -> FVG -> retest integration fixture.   |
//| This script emits signals only and never sends trade orders.      |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "..\Include\M5SetupPersistence.mqh"

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

void BuildFixtureRates(MqlRates &rates[],const datetime latest_closed_time)
  {
   ArrayResize(rates,60);
   ArraySetAsSeries(rates,true);
   for(int i=0;i<60;i++)
     {
      rates[i].time=latest_closed_time-(datetime)((i-1)*300);
      rates[i].open=20.0;
      rates[i].high=25.0;
      rates[i].low=12.0;
      rates[i].close=20.0;
      rates[i].tick_volume=100;
      rates[i].spread=5;
      rates[i].real_volume=100;
     }
   // A single confirmed swing high/low, with three newer and three older
   // candles on each side. Shift 5 is safely confirmed by closed bars.
   rates[5].high=30.0;
   rates[5].low=10.0;
   rates[5].open=20.0;
   rates[5].close=20.0;
  }

void OnStart()
  {
   MqlRates rates[];
   PA_StructureState structure;
   PA_M5SetupState setup;
   PA_M5Signal signal;
   PA_MultiTimeframeSnapshot context;
   PA_ResetStructureState(structure);
   PA_ResetM5SetupState(setup);

   context.context=PA_CONTEXT_BULLISH_ALIGNED;
   context.h1_direction=1;
   context.m15_direction=1;
   context.h1_bar_time=TimeCurrent()-3600;
   context.m15_bar_time=TimeCurrent()-900;
   context.m15_confirmed_reversal_time=0;
   context.h1_last_break=PA_BREAK_BOS_BULLISH;
   context.m15_last_break=PA_BREAK_BOS_BULLISH;

   const datetime base=TimeCurrent();
   const datetime pivot_time=base-1500;
   structure.direction=-1;
   structure.latest_swing_high=30.0;
   structure.latest_swing_low=10.0;
   structure.latest_swing_high_time=pivot_time;
   structure.latest_swing_low_time=pivot_time;
   structure.protected_high=30.0;
   structure.protected_high_time=pivot_time;
   structure.last_structure_event_time=pivot_time;
   structure.last_processed_bar_time=base-600;

   // Step 1: bullish sweep. It closes back above the swing low but below
   // protected high, so sweep and CHoCH are separate completed candles.
   BuildFixtureRates(rates,base-300);
   rates[1].low=9.0;
   rates[1].open=13.0;
   rates[1].close=11.0;
   rates[1].high=25.0;
   const bool sweep_call=PA_EvaluateM5EntrySignal(_Symbol,rates,ArraySize(rates),
      0.05,context,structure,setup,signal,12);
   Check("bullish sweep captured and waits for later CHoCH",
         sweep_call && setup.stage==PA_SETUP_WAIT_CHOCH &&
         setup.direction==1 && signal.signal==PA_ENTRY_NONE);

   // Restart simulation: persisted setup resumes at WAIT_CHOCH.
   const long test_magic=99004567;
   PA_M5SetupState restored_setup;
   const bool saved=PA_SaveM5SetupState(_Symbol,test_magic,setup);
   const bool loaded=PA_LoadM5SetupState(_Symbol,test_magic,restored_setup);
   Check("in-progress sweep state survives persistence round-trip",
         saved && loaded && restored_setup.stage==PA_SETUP_WAIT_CHOCH &&
         restored_setup.direction==1 &&
         restored_setup.sweep_time==setup.sweep_time);
   setup=restored_setup;

   // Step 2: close above protected high creates bullish CHoCH.
   BuildFixtureRates(rates,base);
   rates[1].open=29.0;
   rates[1].low=28.0;
   rates[1].high=32.0;
   rates[1].close=31.0;
   const bool choch_call=PA_EvaluateM5EntrySignal(_Symbol,rates,ArraySize(rates),
      0.05,context,structure,setup,signal,12);
   Check("later bullish CHoCH advances setup to FVG stage",
         choch_call && setup.stage==PA_SETUP_WAIT_FVG &&
         setup.choch_time==rates[1].time);

   // Step 3: completed bullish three-candle gap after the CHoCH.
   BuildFixtureRates(rates,base+300);
   rates[3].high=20.0;
   rates[1].open=22.0;
   rates[1].low=21.0;
   rates[1].high=25.0;
   rates[1].close=23.0;
   const bool fvg_call=PA_EvaluateM5EntrySignal(_Symbol,rates,ArraySize(rates),
      0.05,context,structure,setup,signal,12);
   Check("completed bullish FVG advances setup to retest stage",
         fvg_call && setup.stage==PA_SETUP_WAIT_RETEST &&
         setup.fvg_lower==20.0 && setup.fvg_upper==21.0);

   // Step 4: subsequent candle retests the upper edge and closes bullish
   // back above the zone. This emits a signal only, never an order.
   BuildFixtureRates(rates,base+600);
   rates[1].open=21.5;
   rates[1].low=20.5;
   rates[1].high=24.0;
   rates[1].close=22.0;
   const bool retest_call=PA_EvaluateM5EntrySignal(_Symbol,rates,ArraySize(rates),
      0.05,context,structure,setup,signal,12);
   Check("bullish FVG retest emits BUY signal without placing an order",
         retest_call && signal.signal==PA_ENTRY_BUY &&
         signal.direction==1 && signal.setup_id!="" &&
         signal.rejection_reason=="SIGNAL_READY_NO_ORDER_SENT");

   Check("signal setup ID includes sweep, CHoCH and FVG timestamps",
         StringFind(signal.setup_id,_Symbol)==0 &&
         signal.sweep_time>0 && signal.choch_time>signal.sweep_time &&
         signal.fvg_time>signal.choch_time);

   // Duplicate completed bar must never emit the same signal again.
   Check("same M5 candle cannot be evaluated twice",
         !PA_EvaluateM5EntrySignal(_Symbol,rates,ArraySize(rates),0.05,
                                   context,structure,setup,signal,12));

   // A conflicting H1/M15 context fails closed.
   PA_ResetM5SetupState(setup);
   PA_ResetStructureState(structure);
   structure.direction=-1;
   structure.latest_swing_high=30.0;
   structure.latest_swing_low=10.0;
   structure.latest_swing_high_time=pivot_time;
   structure.latest_swing_low_time=pivot_time;
   structure.protected_high=30.0;
   structure.protected_high_time=pivot_time;
   structure.last_structure_event_time=pivot_time;
   structure.last_processed_bar_time=base+600;
   context.context=PA_CONTEXT_NO_TRADE;
   BuildFixtureRates(rates,base+900);
   rates[1].low=9.0;
   rates[1].close=11.0;
   const bool blocked=PA_EvaluateM5EntrySignal(_Symbol,rates,ArraySize(rates),
      0.05,context,structure,setup,signal,12);
   Check("conflicting timeframe context blocks sweep setup",
         blocked && setup.stage==PA_SETUP_IDLE &&
         signal.signal==PA_ENTRY_NONE &&
         signal.rejection_reason=="H1_M15_CONTEXT_NOT_ALIGNED");

   // An opposite but otherwise valid higher-timeframe direction must also
   // invalidate an already pending setup.
   PA_ResetM5SetupState(setup);
   setup.stage=PA_SETUP_WAIT_CHOCH;
   setup.direction=1;
   setup.sweep_time=base+600;
   setup.sweep_extreme=9.0;
   setup.swept_level=10.0;
   setup.last_processed_bar_time=base+900;
   PA_ResetStructureState(structure);
   structure.direction=-1;
   structure.latest_swing_high=30.0;
   structure.latest_swing_low=10.0;
   structure.latest_swing_high_time=pivot_time;
   structure.latest_swing_low_time=pivot_time;
   structure.protected_high=30.0;
   structure.protected_high_time=pivot_time;
   structure.last_structure_event_time=pivot_time;
   structure.last_processed_bar_time=base+900;
   context.context=PA_CONTEXT_BEARISH_ALIGNED;
   context.h1_direction=-1;
   context.m15_direction=-1;
   BuildFixtureRates(rates,base+1200);
   const bool context_flip=PA_EvaluateM5EntrySignal(_Symbol,rates,
      ArraySize(rates),0.05,context,structure,setup,signal,12);
   Check("opposite aligned H1/M15 context invalidates pending BUY",
         context_flip && setup.stage==PA_SETUP_IDLE &&
         signal.signal==PA_ENTRY_NONE &&
         signal.rejection_reason=="CONTEXT_DIRECTION_CHANGED");

   // Mirror the complete sequence for SELL.
   PA_ResetM5SetupState(setup);
   PA_ResetStructureState(structure);
   context.context=PA_CONTEXT_BEARISH_ALIGNED;
   context.h1_direction=-1;
   context.m15_direction=-1;
   const datetime sell_base=base+1800;
   const datetime sell_pivot=sell_base-1500;
   structure.direction=1;
   structure.latest_swing_high=30.0;
   structure.latest_swing_low=10.0;
   structure.latest_swing_high_time=sell_pivot;
   structure.latest_swing_low_time=sell_pivot;
   structure.protected_low=10.0;
   structure.protected_low_time=sell_pivot;
   structure.last_structure_event_time=sell_pivot;
   structure.last_processed_bar_time=sell_base-600;

   BuildFixtureRates(rates,sell_base-300);
   rates[1].open=28.0;
   rates[1].high=31.0;
   rates[1].low=20.0;
   rates[1].close=29.0;
   const bool sell_sweep_call=PA_EvaluateM5EntrySignal(_Symbol,rates,
      ArraySize(rates),0.05,context,structure,setup,signal,12);
   Check("bearish sweep captured and waits for later CHoCH",
         sell_sweep_call && setup.stage==PA_SETUP_WAIT_CHOCH &&
         setup.direction==-1 && signal.signal==PA_ENTRY_NONE);

   BuildFixtureRates(rates,sell_base);
   rates[1].open=10.0;
   rates[1].high=11.0;
   rates[1].low=8.0;
   rates[1].close=9.0;
   const bool sell_choch_call=PA_EvaluateM5EntrySignal(_Symbol,rates,
      ArraySize(rates),0.05,context,structure,setup,signal,12);
   Check("later bearish CHoCH advances SELL setup to FVG stage",
         sell_choch_call && setup.stage==PA_SETUP_WAIT_FVG &&
         setup.choch_time==rates[1].time);

   BuildFixtureRates(rates,sell_base+300);
   rates[3].low=20.0;
   rates[1].open=18.8;
   rates[1].high=19.0;
   rates[1].low=17.0;
   rates[1].close=18.5;
   const bool sell_fvg_call=PA_EvaluateM5EntrySignal(_Symbol,rates,
      ArraySize(rates),0.05,context,structure,setup,signal,12);
   Check("completed bearish FVG advances SELL setup to retest stage",
         sell_fvg_call && setup.stage==PA_SETUP_WAIT_RETEST &&
         setup.fvg_lower==19.0 && setup.fvg_upper==20.0);

   BuildFixtureRates(rates,sell_base+600);
   rates[1].open=19.2;
   rates[1].high=19.5;
   rates[1].low=17.5;
   rates[1].close=18.5;
   const bool sell_retest_call=PA_EvaluateM5EntrySignal(_Symbol,rates,
      ArraySize(rates),0.05,context,structure,setup,signal,12);
   Check("bearish FVG retest emits SELL signal without placing an order",
         sell_retest_call && signal.signal==PA_ENTRY_SELL &&
         signal.direction==-1 && signal.setup_id!="" &&
         signal.rejection_reason=="SIGNAL_READY_NO_ORDER_SENT");

   Print("M5 entry fixtures complete. Passed=",g_passed,
         " Failed=",g_failed);
  }
