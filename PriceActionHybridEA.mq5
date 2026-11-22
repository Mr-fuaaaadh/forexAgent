//+------------------------------------------------------------------+
//| PriceActionHybridEA.mq5                                          |
//| Signal-only integration of the closed-bar price-action engine.  |
//| No order execution is implemented in this build.                  |
//+------------------------------------------------------------------+
#property strict
#property version   "1.30"
#property description "XAUUSD Price Action Hybrid EA - signal-only integration."

#include "Include/M5EntrySignal.mqh"
#include "Include/M5SetupPersistence.mqh"

input bool   InpEnableTrading    = false;
input bool   InpAllowLiveTrading = false;
input long   InpMagicNumber      = 120026;
input double InpRiskPercent      = 0.5;
input int    InpHistoryBars      = 500;
input int    InpSwingLookback    = 80;
input int    InpMaximumSetupBars = 12;

string              g_symbol = "";
datetime            g_last_m5_open_time = 0;
PA_StructureState   g_h1_structure;
PA_StructureState   g_m15_structure;
PA_StructureState   g_m5_structure;
PA_M5SetupState     g_m5_setup;
bool                g_runtime_ready = false;

bool PA_IsSupportedGoldSymbol(const string symbol)
  {
   string base_currency = SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE);
   string profit_currency = SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);

   // Symbol names may have broker suffixes (XAUUSDm, XAUUSD.a, etc.).
   // Currency metadata is authoritative; ambiguous metadata fails closed.
   if(base_currency != "XAU" || profit_currency != "USD")
     {
      PrintFormat("INIT BLOCKED: expected XAU/USD instrument metadata; %s reports base=%s profit=%s",
                  symbol,base_currency,profit_currency);
      return false;
     }
   return true;
  }

bool PA_LoadRuntimeState()
  {
   PA_ResetStructureState(g_h1_structure);
   PA_ResetStructureState(g_m15_structure);
   PA_ResetStructureState(g_m5_structure);
   PA_ResetM5SetupState(g_m5_setup);

   PA_LoadStructureState(g_symbol,PERIOD_H1,InpMagicNumber,g_h1_structure);
   PA_LoadStructureState(g_symbol,PERIOD_M15,InpMagicNumber,g_m15_structure);
   PA_LoadStructureState(g_symbol,PERIOD_M5,InpMagicNumber,g_m5_structure);
   PA_LoadM5SetupState(g_symbol,InpMagicNumber,g_m5_setup);
   return true;
  }

bool PA_RefreshHigherTimeframeContext(PA_MultiTimeframeSnapshot &context)
  {
   PA_StructureSnapshot h1_snapshot;
   PA_StructureSnapshot m15_snapshot;

   const bool h1_ok = PA_UpdateTimeframeState(
      g_symbol,PERIOD_H1,InpMagicNumber,InpHistoryBars,
      InpSwingLookback,g_h1_structure,h1_snapshot);
   const bool m15_ok = PA_UpdateTimeframeState(
      g_symbol,PERIOD_M15,InpMagicNumber,InpHistoryBars,
      InpSwingLookback,g_m15_structure,m15_snapshot);

   if(!h1_ok || !m15_ok)
     {
      context.context = PA_CONTEXT_UNAVAILABLE;
      context.h1_direction = g_h1_structure.direction;
      context.m15_direction = g_m15_structure.direction;
      context.h1_last_break = g_h1_structure.last_break_type;
      context.m15_last_break = g_m15_structure.last_break_type;
      context.h1_bar_time = g_h1_structure.last_processed_bar_time;
      context.m15_bar_time = g_m15_structure.last_processed_bar_time;
      context.m15_confirmed_reversal_time = g_m15_structure.confirmed_reversal_time;
      PrintFormat("CONTEXT UNAVAILABLE: H1 update=%s M15 update=%s",
                  h1_ok ? "OK" : "FAILED",m15_ok ? "OK" : "FAILED");
      return false;
     }

   if(!PA_BuildMultiTimeframeSnapshot(g_h1_structure,g_m15_structure,context))
     {
      Print("CONTEXT UNAVAILABLE: snapshot construction failed.");
      return false;
     }
   return true;
  }

void PA_ProcessNewM5Bar()
  {
   MqlRates m5_rates[];
   ArraySetAsSeries(m5_rates,true);
   const int copied = CopyRates(g_symbol,PERIOD_M5,0,InpHistoryBars,m5_rates);
   if(copied < 40)
     {
      PrintFormat("SIGNAL BLOCKED: M5 history insufficient (%d bars).",copied);
      return;
     }

   PA_MultiTimeframeSnapshot context;
   if(!PA_RefreshHigherTimeframeContext(context))
      return;

   const double bid = SymbolInfoDouble(g_symbol,SYMBOL_BID);
   const double ask = SymbolInfoDouble(g_symbol,SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
     {
      Print("SIGNAL BLOCKED: invalid bid/ask quote.");
      return;
     }
   const double spread_price = ask - bid;

   PA_M5Signal signal;
   const bool evaluated = PA_EvaluateM5EntrySignal(
      g_symbol,m5_rates,copied,spread_price,context,
      g_m5_structure,g_m5_setup,signal,InpMaximumSetupBars);

   // Persist both state machines before reporting a qualified signal.
   const bool structure_saved = PA_SaveStructureState(
      g_symbol,PERIOD_M5,InpMagicNumber,g_m5_structure);
   const bool setup_saved = PA_SaveM5SetupState(
      g_symbol,InpMagicNumber,g_m5_setup);

   if(!structure_saved || !setup_saved)
     {
      PrintFormat("SIGNAL BLOCKED: persistence failure (structure=%s setup=%s).",
                  structure_saved ? "OK" : "FAILED",
                  setup_saved ? "OK" : "FAILED");
      return;
     }

   if(!evaluated)
     {
      PrintFormat("M5 bar %s not evaluated: %s",
                  TimeToString(m5_rates[1].time,TIME_DATE|TIME_MINUTES),
                  signal.rejection_reason);
      return;
     }

   if(signal.signal == PA_ENTRY_BUY || signal.signal == PA_ENTRY_SELL)
     {
      PrintFormat("SIGNAL ONLY | %s | strategy=SWEEP_CHOCH_FVG | symbol=%s | bar=%s | setup=%s | entry-zone=[%.*f,%.*f] | invalidation=%.*f | context=%s | NO ORDER SENT",
         signal.signal == PA_ENTRY_BUY ? "BUY" : "SELL",
         g_symbol,
         TimeToString(signal.signal_bar_time,TIME_DATE|TIME_MINUTES),
         signal.setup_id,
         (int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS),signal.fvg_lower,
         (int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS),signal.fvg_upper,
         (int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS),signal.sweep_extreme,
         EnumToString(context.context));
     }
   else
     {
      PrintFormat("NO SIGNAL | bar=%s | context=%s | reason=%s",
         TimeToString(m5_rates[1].time,TIME_DATE|TIME_MINUTES),
         EnumToString(context.context),signal.rejection_reason);
     }
  }

int OnInit()
  {
   if(InpMagicNumber <= 0 || InpRiskPercent <= 0.0 ||
      InpRiskPercent > 0.5 || InpHistoryBars < 100 ||
      InpSwingLookback < 4 || InpMaximumSetupBars < 3)
     {
      Print("INIT FAILED: invalid input parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   // This release is deliberately signal-only. Refuse unsafe input toggles.
   if(InpEnableTrading || InpAllowLiveTrading)
     {
      Print("INIT FAILED: this build is signal-only; both trading inputs must remain false.");
      return INIT_PARAMETERS_INCORRECT;
     }

   g_symbol = _Symbol;
   if(!PA_IsSupportedGoldSymbol(g_symbol))
      return INIT_FAILED;

   if(!SymbolSelect(g_symbol,true))
     {
      PrintFormat("INIT FAILED: could not select symbol %s.",g_symbol);
      return INIT_FAILED;
     }

   PA_LoadRuntimeState();

   // Prime H1/M15 history and state. Do not replay the latest closed M5 bar
   // immediately on attachment; wait for the next newly opened M5 candle.
   PA_MultiTimeframeSnapshot initial_context;
   if(!PA_RefreshHigherTimeframeContext(initial_context))
     {
      Print("INIT FAILED: H1/M15 history is not ready. Load history and reattach.");
      return INIT_FAILED;
     }

   g_last_m5_open_time = iTime(g_symbol,PERIOD_M5,0);
   if(g_last_m5_open_time <= 0)
     {
      Print("INIT FAILED: M5 current-bar timestamp unavailable.");
      return INIT_FAILED;
     }

   g_runtime_ready = true;
   PrintFormat("SIGNAL-ONLY EA READY | symbol=%s | H1=%d | M15=%d | context=%s | trading=false | live=false",
      g_symbol,g_h1_structure.direction,g_m15_structure.direction,
      EnumToString(initial_context.context));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_runtime_ready)
     {
      PA_SaveStructureState(g_symbol,PERIOD_H1,InpMagicNumber,g_h1_structure);
      PA_SaveStructureState(g_symbol,PERIOD_M15,InpMagicNumber,g_m15_structure);
      PA_SaveStructureState(g_symbol,PERIOD_M5,InpMagicNumber,g_m5_structure);
      PA_SaveM5SetupState(g_symbol,InpMagicNumber,g_m5_setup);
      GlobalVariablesFlush();
     }
   PrintFormat("Signal-only EA deinitialized. Reason=%d",reason);
  }

void OnTick()
  {
   if(!g_runtime_ready)
      return;

   const datetime current_m5_open = iTime(g_symbol,PERIOD_M5,0);
   if(current_m5_open <= 0 || current_m5_open == g_last_m5_open_time)
      return;

   g_last_m5_open_time = current_m5_open;
   PA_ProcessNewM5Bar();
  }
