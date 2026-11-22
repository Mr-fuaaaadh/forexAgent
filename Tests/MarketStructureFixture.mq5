//+------------------------------------------------------------------+
//| MarketStructureFixture.mq5                                       |
//| Deterministic synthetic fixtures for MarketStructure.mqh.        |
//| Run as an MT5 Script; no trades are placed.                       |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "..\Include\MarketStructure.mqh"

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

void BuildBaseSeries(MqlRates &rates[],const int size)
  {
   ArrayResize(rates,size);
   ArraySetAsSeries(rates,true);
   const datetime now = TimeCurrent();
   for(int i=0;i<size;i++)
     {
      rates[i].time = now - (datetime)(i*60);
      rates[i].open = 7.0;
      rates[i].high = 10.0;
      rates[i].low = 5.0;
      rates[i].close = 7.0;
      rates[i].tick_volume = 1;
      rates[i].spread = 1;
      rates[i].real_volume = 1;
     }
  }

void OnStart()
  {
   MqlRates rates[];
   BuildBaseSeries(rates,16);

   // Strict confirmed pivot at shift 4.
   rates[4].high = 20.0;
   rates[4].low = 1.0;
   Check("3-left/3-right swing high confirms",
         PA_IsConfirmedSwingHigh(rates,ArraySize(rates),4));
   Check("3-left/3-right swing low confirms",
         PA_IsConfirmedSwingLow(rates,ArraySize(rates),4));

   rates[3].high = 20.0;
   Check("equal neighboring high invalidates strict pivot",
         !PA_IsConfirmedSwingHigh(rates,ArraySize(rates),4));
   rates[3].high = 10.0;

   // Liquidity sweep uses the latest completed candle (shift 1).
   double extreme = 0.0;
   rates[1].low = 4.8;
   rates[1].close = 5.2;
   Check("bullish sweep pierce-close-distance",
         PA_DetectLiquiditySweep(rates,ArraySize(rates),5.0,true,
                                 0.05,2.0,extreme) && extreme==4.8);
   rates[1].low = 4.99;
   Check("undersized bullish sweep rejected",
         !PA_DetectLiquiditySweep(rates,ArraySize(rates),5.0,true,
                                  0.05,2.0,extreme));

   // Bullish FVG: C.low (shift 1) above A.high (shift 3).
   rates[3].high = 10.0;
   rates[1].low = 11.0;
   PA_Gap gap;
   Check("bullish FVG from completed bars",
         PA_DetectFairValueGap(rates,ArraySize(rates),0.05,2.0,gap) &&
         gap.valid && gap.bullish && gap.lower==10.0 && gap.upper==11.0);

   // Stateful first BOS, then a protected-low CHoCH. Use a fresh state.
   BuildBaseSeries(rates,16);
   rates[4].high = 20.0;
   rates[4].low = 1.0;
   PA_StructureState state;
   PA_StructureSnapshot snapshot;
   PA_ResetStructureState(state);
   rates[1].close = 21.0;
   Check("neutral state establishes bullish BOS",
         PA_UpdateStructureState(rates,ArraySize(rates),12,state,snapshot) &&
         snapshot.break_type==PA_BREAK_BOS_BULLISH &&
         state.direction==1 && state.protected_low==1.0);

   Check("same candle timestamp is not processed twice",
         !PA_UpdateStructureState(rates,ArraySize(rates),12,state,snapshot));

   rates[0].time += 120;
   rates[1].time += 60;
   rates[1].close = 0.5;
   Check("close through protected low creates bearish CHoCH",
         PA_UpdateStructureState(rates,ArraySize(rates),12,state,snapshot) &&
         snapshot.break_type==PA_BREAK_CHOCH_BEARISH &&
         state.direction==-1);

   // Reverse-direction fixture: initial bearish BOS, then bullish CHoCH.
   BuildBaseSeries(rates,16);
   rates[4].high = 20.0;
   rates[4].low = 1.0;
   PA_ResetStructureState(state);
   rates[1].close = 0.5;
   Check("neutral state establishes bearish BOS",
         PA_UpdateStructureState(rates,ArraySize(rates),12,state,snapshot) &&
         snapshot.break_type==PA_BREAK_BOS_BEARISH &&
         state.direction==-1 && state.protected_high==20.0);

   rates[0].time += 120;
   rates[1].time += 60;
   rates[1].close = 21.0;
   Check("close through protected high creates bullish CHoCH",
         PA_UpdateStructureState(rates,ArraySize(rates),12,state,snapshot) &&
         snapshot.break_type==PA_BREAK_CHOCH_BULLISH &&
         state.direction==1);

   Print("MarketStructure fixtures complete. Passed=",g_passed,
         " Failed=",g_failed);
  }
