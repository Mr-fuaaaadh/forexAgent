//+------------------------------------------------------------------+
//| PriceActionHybridEA.mq5                                          |
//| Demo-only execution of the closed-bar price-action engine.       |
//| Live-account execution is permanently blocked.                   |
//+------------------------------------------------------------------+
#property strict
#property version   "1.30"
#property description "XAUUSD Price Action Hybrid EA - demo-only challenge controls."

#include "Include/M5EntrySignal.mqh"
#include "Include/M5SetupPersistence.mqh"
#include "Include/SecondaryStrategyRuntime.mqh"
#include "Include/DemoExecution.mqh"

input bool   InpEnableTrading    = false;
input long   InpMagicNumber      = 120026;
input double InpRiskPercent      = 0.5;
input int    InpMaximumPositions = 3;
input double InpMaximumOpenRisk  = 1.5;
input double InpDailyLossLimit   = 2.0;
input double InpRiskRewardRatio  = 2.0;
input double InpChallengeInitialBalance = 0.0; // Exact challenge starting balance.
input int    InpHistoryBars      = 500;
input int    InpSwingLookback    = 80;
input int    InpMaximumSetupBars = 12;

string              g_symbol = "";
datetime            g_last_m5_open_time = 0;
PA_StructureState   g_h1_structure;
PA_StructureState   g_m15_structure;
PA_StructureState   g_m5_structure;
PA_M5SetupState     g_m5_setup;
PA_SecondaryStrategyState g_secondary_state;
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
   PA_ResetSecondaryStrategyState(g_secondary_state);

   PA_LoadStructureState(g_symbol,PERIOD_H1,InpMagicNumber,g_h1_structure);
   PA_LoadStructureState(g_symbol,PERIOD_M15,InpMagicNumber,g_m15_structure);
   PA_LoadStructureState(g_symbol,PERIOD_M5,InpMagicNumber,g_m5_structure);
   PA_LoadM5SetupState(g_symbol,InpMagicNumber,g_m5_setup);
   if(!PA_LoadSecondaryStrategyState(g_symbol,InpMagicNumber,g_secondary_state))
      PA_ResetSecondaryStrategyState(g_secondary_state);
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

   // Build the current closed-M5 structure snapshot on a copy. The primary
   // evaluator below advances the real state exactly once; secondary
   // confirmations consume this same-bar snapshot without double-updating it.
   PA_StructureState m5_preview_state = g_m5_structure;
   PA_StructureSnapshot m5_snapshot;
   PA_ResetStructureSnapshot(m5_snapshot);
   PA_UpdateStructureState(m5_rates,copied,40,m5_preview_state,m5_snapshot);

   PA_M5Signal primary_signal;
   const bool primary_evaluated = PA_EvaluateM5EntrySignal(
      g_symbol,m5_rates,copied,spread_price,context,
      g_m5_structure,g_m5_setup,primary_signal,InpMaximumSetupBars);

   // Save primary state before any signal can be reported.
   const bool structure_saved = PA_SaveStructureState(
      g_symbol,PERIOD_M5,InpMagicNumber,g_m5_structure);
   const bool setup_saved = PA_SaveM5SetupState(
      g_symbol,InpMagicNumber,g_m5_setup);
   if(!structure_saved || !setup_saved)
     {
      PrintFormat("SIGNAL BLOCKED: primary persistence failure (structure=%s setup=%s).",
                  structure_saved ? "OK" : "FAILED",
                  setup_saved ? "OK" : "FAILED");
      return;
     }

   // Secondary setups are driven by the latest completed M15 BOS and the
   // same completed M5 candle used by the primary strategy.
   MqlRates m15_rates[];
   ArraySetAsSeries(m15_rates,true);
   const int m15_copied = CopyRates(g_symbol,PERIOD_M15,0,InpHistoryBars,m15_rates);

   PA_StrategySignal secondary_signal;
   PA_ResetStrategySignal(secondary_signal);
   bool secondary_evaluated = false;
   if(m15_copied >= 20)
     {
      secondary_evaluated = PA_RunSecondaryStrategies(
         g_symbol,InpMagicNumber,m15_rates,m15_copied,g_m15_structure,
         context,m5_rates,copied,spread_price,m5_snapshot,
         g_secondary_state,secondary_signal);
     }
   else
      secondary_signal.rejection_reason = "M15_HISTORY_INSUFFICIENT_FOR_SECONDARY";

   // One arbitration point for every strategy on this closed M5 bar.
   PA_StrategySignal secondary_candidates[1];
   PA_ResetStrategySignal(secondary_candidates[0]);
   int secondary_count = 0;
   if(secondary_evaluated)
     {
      secondary_candidates[0] = secondary_signal;
      secondary_count = 1;
     }

   PA_StrategySignal selected;
   const bool has_signal = PA_ArbitrateAllStrategies(
      primary_signal,secondary_candidates,secondary_count,selected);

   if(has_signal)
     {
      const int digits = (int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS);
      if(g_pa_demo_execution_ready)
         PA_ExecuteSelectedDemoSignal(selected);
      else
         PrintFormat("SIGNAL ONLY | %s | strategy=%s | symbol=%s | bar=%s | setup=%s | zone=[%.*f,%.*f] | invalidation=%.*f | context=%s | NO ORDER SENT",
         selected.direction > 0 ? "BUY" : "SELL",
         PA_StrategyName(selected.strategy),
         g_symbol,
         TimeToString(selected.signal_bar_time,TIME_DATE|TIME_MINUTES),
         selected.setup_id,
         digits,selected.zone_low,
         digits,selected.zone_high,
         digits,selected.invalidation_level,
         EnumToString(context.context));
      return;
     }

   string arbitration_reason = selected.rejection_reason;
   if(arbitration_reason == "")
      arbitration_reason = secondary_signal.rejection_reason;
   if(arbitration_reason == "")
      arbitration_reason = primary_signal.rejection_reason;
   if(arbitration_reason == "")
      arbitration_reason = primary_evaluated ? "NO_QUALIFIED_STRATEGY" : "PRIMARY_EVALUATION_SKIPPED";

   PrintFormat("NO SIGNAL | bar=%s | context=%s | reason=%s | primary=%s | secondary=%s",
      TimeToString(m5_rates[1].time,TIME_DATE|TIME_MINUTES),
      EnumToString(context.context),
      arbitration_reason,
      primary_signal.rejection_reason,
      secondary_signal.rejection_reason);
  }

int OnInit()
  {
   if(InpMagicNumber <= 0 || InpRiskPercent <= 0.0 ||
      InpRiskPercent > 0.5 || InpMaximumPositions != 3 ||
      InpMaximumOpenRisk != 1.5 || InpDailyLossLimit != 2.0 ||
      InpRiskRewardRatio != 2.0 || InpHistoryBars < 100 ||
      InpSwingLookback < 4 || InpMaximumSetupBars < 3)
     {
      Print("INIT FAILED: invalid input parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   // Live execution has no user-configurable switch. The execution module
   // independently rejects every account except DEMO + HEDGING.

   g_symbol = _Symbol;
   if(!PA_IsSupportedGoldSymbol(g_symbol))
      return INIT_FAILED;

   if(!SymbolSelect(g_symbol,true))
     {
      PrintFormat("INIT FAILED: could not select symbol %s.",g_symbol);
      return INIT_FAILED;
     }

   if(!PA_InitDemoExecution(g_symbol,InpMagicNumber,InpEnableTrading,
                            InpRiskPercent,InpMaximumPositions,
                            InpMaximumOpenRisk,InpDailyLossLimit,
                            InpRiskRewardRatio,InpChallengeInitialBalance))
     {
      Print("INIT FAILED: demo execution safety initialization failed.");
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
   EventSetTimer(1); // Keep daily-baseline capture alive even during quiet market periods.
   PrintFormat("PRICE ACTION EA READY | symbol=%s | H1=%d | M15=%d | context=%s | execution=%s | live=false",
      g_symbol,g_h1_structure.direction,g_m15_structure.direction,
      EnumToString(initial_context.context),g_pa_demo_execution_ready ? "DEMO" : "SIGNAL_ONLY");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_runtime_ready)
     {
      PA_SaveStructureState(g_symbol,PERIOD_H1,InpMagicNumber,g_h1_structure);
      PA_SaveStructureState(g_symbol,PERIOD_M15,InpMagicNumber,g_m15_structure);
      PA_SaveStructureState(g_symbol,PERIOD_M5,InpMagicNumber,g_m5_structure);
      PA_SaveM5SetupState(g_symbol,InpMagicNumber,g_m5_setup);
      PA_SaveSecondaryStrategyState(g_symbol,InpMagicNumber,g_secondary_state);
      GlobalVariablesFlush();
     }
   PrintFormat("Demo-only EA deinitialized. Reason=%d",reason);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
      PA_RecordChallengeTradingDay(trans.deal);
  }

void OnTimer()
  {
   if(!g_runtime_ready)
      return;

   // If attached after the broker-day baseline window, activate only when
   // the timer reaches the next valid server-day opening minute.
   if(InpEnableTrading && g_pa_demo_execution_pending)
      PA_TryActivateDemoExecution();

   if(g_pa_demo_execution_ready)
      PA_EnforceDemoRiskGuards();
  }

void OnTick()
  {
   if(!g_runtime_ready)
      return;

   if(InpEnableTrading && g_pa_demo_execution_pending)
      PA_TryActivateDemoExecution();

   // Manage demo positions and enforce daily loss / protective-SL guards
   // on every tick, not only when a new M5 candle opens.
   PA_EnforceDemoRiskGuards();

   const datetime current_m5_open = iTime(g_symbol,PERIOD_M5,0);
   if(current_m5_open <= 0 || current_m5_open == g_last_m5_open_time)
      return;

   g_last_m5_open_time = current_m5_open;
   PA_ProcessNewM5Bar();
  }
