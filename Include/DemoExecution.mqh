//+------------------------------------------------------------------+
//| DemoExecution.mqh                                                |
//| Fail-closed DEMO-only execution, risk sizing and position guard.  |
//| Live-account execution is intentionally impossible in this build.|
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_DEMO_EXECUTION_MQH
#define FOREX_AGENT_DEMO_EXECUTION_MQH

#include <Trade/Trade.mqh>

#define PA_DEMO_MAX_POSITIONS 3
#define PA_DEMO_MAX_RISK_PERCENT 1.5
#define PA_DEMO_DAILY_LOSS_PERCENT 2.0
#define PA_DEMO_RISK_PER_TRADE_PERCENT 0.5
#define PA_DEMO_RR 2.0

CTrade g_pa_trade;
bool   g_pa_demo_execution_ready=false;
bool   g_pa_daily_locked=false;
double g_pa_day_start_equity=0.0;
int    g_pa_server_day_key=0;
string g_pa_exec_symbol="";
long   g_pa_exec_magic=0;

int PA_DayKey(const datetime value)
  {
   MqlDateTime parts;
   TimeToStruct(value,parts);
   return parts.year*10000+parts.mon*100+parts.day;
  }

uint PA_ExecutionHash(const string value)
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(value);i++)
     {
      hash^=(uint)StringGetCharacter(value,i);
      hash=(uint)(hash*16777619);
     }
   return hash;
  }

string PA_ExecutionPrefix()
  {
   return StringFormat("PADEMO.%I64d.%I64d.%s",
      AccountInfoInteger(ACCOUNT_LOGIN),g_pa_exec_magic,g_pa_exec_symbol);
  }

bool PA_IsDemoHedgingAccount()
  {
   if((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)
     {
      Print("DEMO SAFETY BLOCK: account is not a MetaTrader DEMO account.");
      return false;
     }
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("DEMO SAFETY BLOCK: hedging account required for independent multi-position mode.");
      return false;
     }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      Print("DEMO SAFETY BLOCK: terminal/account trading permissions unavailable.");
      return false;
     }
   return true;
  }

bool PA_InitDemoExecution(const string symbol,const long magic,const bool enabled,
                          const bool live_input,const double risk_percent,
                          const int max_positions,const double max_open_risk,
                          const double daily_loss_limit,const double rr)
  {
   g_pa_demo_execution_ready=false;
   g_pa_exec_symbol=symbol;
   g_pa_exec_magic=magic;

   // The live switch is a permanent hard stop, not a permission flag.
   if(live_input)
     {
      Print("INIT BLOCKED: live trading is permanently disabled in this build.");
      return false;
     }
   if(risk_percent!=PA_DEMO_RISK_PER_TRADE_PERCENT ||
      max_positions!=PA_DEMO_MAX_POSITIONS ||
      max_open_risk!=PA_DEMO_MAX_RISK_PERCENT ||
      daily_loss_limit!=PA_DEMO_DAILY_LOSS_PERCENT ||
      rr!=PA_DEMO_RR)
     {
      Print("INIT BLOCKED: execution inputs differ from the reviewed safety specification.");
      return false;
     }
   if(!enabled)
     {
      Print("DEMO EXECUTION DISABLED: EA remains signal-only.");
      return true;
     }
   if(!PA_IsDemoHedgingAccount())
      return false;

   g_pa_trade.SetExpertMagicNumber((ulong)magic);
   g_pa_trade.SetAsyncMode(false);
   g_pa_trade.SetTypeFillingBySymbol(symbol);
   g_pa_trade.SetDeviationInPoints(30);

   const int today=PA_DayKey(TimeTradeServer());
   const string day_key=PA_ExecutionPrefix()+".day";
   const string equity_key=PA_ExecutionPrefix()+".equity";
   if(GlobalVariableCheck(day_key) && GlobalVariableCheck(equity_key) &&
      (int)GlobalVariableGet(day_key)==today)
     {
      g_pa_server_day_key=today;
      g_pa_day_start_equity=GlobalVariableGet(equity_key);
     }
   else
     {
      // The true daily baseline can only be captured at the start of the
      // broker-server day. If the EA was not running then and no baseline
      // was persisted, fail closed rather than substituting mid-session equity.
      MqlDateTime server_now;
      TimeToStruct(TimeTradeServer(),server_now);
      if(server_now.hour!=0 || server_now.min>1)
        {
         Print("INIT BLOCKED: today's start-of-server-day equity baseline is missing. Attach at server midnight or wait for the next server day.");
         return false;
        }
      g_pa_server_day_key=today;
      g_pa_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
      if(g_pa_day_start_equity<=0.0 ||
         GlobalVariableSet(day_key,(double)today)==0 ||
         GlobalVariableSet(equity_key,g_pa_day_start_equity)==0)
        {
         Print("INIT BLOCKED: cannot persist start-of-day equity baseline.");
         return false;
        }
      GlobalVariablesFlush();
     }
   if(g_pa_day_start_equity<=0.0)
      return false;

   g_pa_daily_locked=false;
   g_pa_demo_execution_ready=true;
   PrintFormat("DEMO EXECUTION READY | symbol=%s | risk=%.2f%% | max_positions=%d | aggregate_risk=%.2f%% | daily_loss=%.2f%% | RR=1:2 | live=false",
      symbol,risk_percent,max_positions,max_open_risk,daily_loss_limit);
   return true;
  }

ENUM_ORDER_TYPE_FILLING PA_GetSymbolFillingMode(const string symbol)
  {
   const long modes=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
   if((modes & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((modes & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

bool PA_CalculateStops(const int direction,const double entry,const double invalidation,
                       const double rr,double &sl,double &tp)
  {
   sl=0.0;
   tp=0.0;
   if((direction!=1 && direction!=-1) || entry<=0.0 || invalidation<=0.0 || rr!=2.0)
      return false;
   const double distance=direction>0 ? entry-invalidation : invalidation-entry;
   if(distance<=0.0)
      return false;
   sl=invalidation;
   tp=direction>0 ? entry+distance*rr : entry-distance*rr;
   return (tp>0.0 && MathIsValidNumber(tp));
  }

double PA_FloorVolume(const string symbol,const double requested)
  {
   const double min_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   const double max_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   const double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   if(step<=0.0 || min_volume<=0.0 || max_volume<min_volume)
      return 0.0;
   double volume=MathMin(requested,max_volume);
   volume=MathFloor((volume+1e-10)/step)*step;
   int digits=0;
   double scaled=step;
   while(digits<8 && MathAbs(scaled-MathRound(scaled))>1e-8)
     {
      scaled*=10.0;
      digits++;
     }
   volume=NormalizeDouble(volume,digits);
   if(volume<min_volume || volume>max_volume)
      return 0.0;
   return volume;
  }

bool PA_CalculateRiskVolume(const string symbol,const int direction,
                            const double entry,const double sl,
                            const double risk_percent,double &volume,
                            double &cash_risk)
  {
   volume=0.0;
   cash_risk=0.0;
   if(entry<=0.0 || sl<=0.0 || risk_percent<=0.0 ||
      (direction!=1 && direction!=-1))
      return false;
   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const double risk_budget=equity*risk_percent/100.0;
   if(equity<=0.0 || risk_budget<=0.0)
      return false;

   double one_lot_result=0.0;
   const ENUM_ORDER_TYPE order_type=direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(order_type,symbol,1.0,entry,sl,one_lot_result))
     {
      PrintFormat("RISK BLOCKED: OrderCalcProfit failed, error=%d",GetLastError());
      return false;
     }
   const double one_lot_loss=MathAbs(one_lot_result);
   if(one_lot_loss<=0.0 || !MathIsValidNumber(one_lot_loss))
      return false;

   const double raw_volume=risk_budget/one_lot_loss;
   volume=PA_FloorVolume(symbol,raw_volume);
   if(volume<=0.0)
      return false;
   double actual_result=0.0;
   if(!OrderCalcProfit(order_type,symbol,volume,entry,sl,actual_result))
      return false;
   cash_risk=MathAbs(actual_result);
   // Never round up through broker volume steps and exceed the risk budget.
   if(cash_risk>risk_budget+0.01)
     {
      volume=PA_FloorVolume(symbol,volume-SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP));
      if(volume<=0.0 ||
         !OrderCalcProfit(order_type,symbol,volume,entry,sl,actual_result))
         return false;
      cash_risk=MathAbs(actual_result);
     }
   return (volume>0.0 && cash_risk<=risk_budget+0.01);
  }

bool PA_GetManagedPositionRisk(double &risk_cash,int &position_count,
                               bool &missing_protection)
  {
   risk_cash=0.0;
   position_count=0;
   missing_protection=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_pa_exec_symbol ||
         (long)PositionGetInteger(POSITION_MAGIC)!=g_pa_exec_magic)
         continue;
      position_count++;
      const double sl=PositionGetDouble(POSITION_SL);
      const double open=PositionGetDouble(POSITION_PRICE_OPEN);
      const double volume=PositionGetDouble(POSITION_VOLUME);
      const ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(sl<=0.0)
        {
         missing_protection=true;
         continue;
        }
      double pnl_at_sl=0.0;
      const ENUM_ORDER_TYPE order_type=type==POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcProfit(order_type,g_pa_exec_symbol,volume,open,sl,pnl_at_sl))
        {
         missing_protection=true;
         continue;
        }
      // A stop beyond breakeven locks profit and contributes zero open risk.
      risk_cash+=MathMax(0.0,-pnl_at_sl);
     }
   return true;
  }

bool PA_IsSetupAlreadyConsumed(const string setup_id)
  {
   if(setup_id=="")
      return true;
   const string key=PA_ExecutionPrefix()+".s."+StringFormat("%I64d",(long)PA_ExecutionHash(setup_id));
   return GlobalVariableCheck(key);
  }

bool PA_ReserveSetup(const string setup_id)
  {
   if(setup_id=="")
      return false;
   const string key=PA_ExecutionPrefix()+".s."+StringFormat("%I64d",(long)PA_ExecutionHash(setup_id));
   if(!GlobalVariableCheck(key))
     {
      if(GlobalVariableSet(key,0.0)==0)
         return false;
      GlobalVariablesFlush();
     }
   // Atomic compare-and-set prevents two EA instances reserving the same setup.
   if(!GlobalVariableSetOnCondition(key,(double)TimeTradeServer(),0.0))
      return false;
   GlobalVariablesFlush();
   return true;
  }

bool PA_DailyLossTriggered()
  {
   if(g_pa_day_start_equity<=0.0)
      return true;
   const int today=PA_DayKey(TimeTradeServer());
   if(today!=g_pa_server_day_key)
     {
      // Never silently reset the baseline during an active session.
      const string day_key=PA_ExecutionPrefix()+".day";
      const string equity_key=PA_ExecutionPrefix()+".equity";
      MqlDateTime server_now;
      TimeToStruct(TimeTradeServer(),server_now);
      if(server_now.hour!=0 || server_now.min>1)
        {
         Print("DAILY GUARD LOCKED: start-of-day equity baseline was not captured at server midnight.");
         return true;
        }
      const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity<=0.0 || GlobalVariableSet(day_key,(double)today)==0 ||
         GlobalVariableSet(equity_key,equity)==0)
         return true;
      GlobalVariablesFlush();
      g_pa_server_day_key=today;
      g_pa_day_start_equity=equity;
      g_pa_daily_locked=false;
     }
   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   return (equity<=g_pa_day_start_equity*(1.0-PA_DEMO_DAILY_LOSS_PERCENT/100.0));
  }

void PA_EnforceDemoRiskGuards()
  {
   if(!g_pa_demo_execution_ready)
      return;
   if(PA_DailyLossTriggered())
      g_pa_daily_locked=true;

   double open_risk=0.0;
   int positions=0;
   bool missing_sl=false;
   PA_GetManagedPositionRisk(open_risk,positions,missing_sl);

   if(missing_sl || g_pa_daily_locked)
     {
      const string reason=g_pa_daily_locked ? "DAILY_LOSS_LIMIT" : "MISSING_OR_UNCALCULABLE_SL";
      PrintFormat("DEMO EMERGENCY GUARD: %s; closing managed positions and blocking entries.",reason);
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         const ulong ticket=PositionGetTicket(i);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)==g_pa_exec_symbol &&
            (long)PositionGetInteger(POSITION_MAGIC)==g_pa_exec_magic)
            g_pa_trade.PositionClose(ticket);
        }
     }
  }

bool PA_ExecuteSelectedDemoSignal(const PA_StrategySignal &signal)
  {
   if(!g_pa_demo_execution_ready || g_pa_daily_locked ||
      signal.strategy==PA_STRATEGY_NONE || signal.setup_id=="" ||
      (signal.direction!=1 && signal.direction!=-1))
      return false;
   if(!PA_IsDemoHedgingAccount())
      return false;
   if(PA_IsSetupAlreadyConsumed(signal.setup_id))
     {
      PrintFormat("DEMO ORDER BLOCKED: duplicate setup %s",signal.setup_id);
      return false;
     }

   const double ask=SymbolInfoDouble(g_pa_exec_symbol,SYMBOL_ASK);
   const double bid=SymbolInfoDouble(g_pa_exec_symbol,SYMBOL_BID);
   const double entry=signal.direction>0 ? ask : bid;
   const double point=SymbolInfoDouble(g_pa_exec_symbol,SYMBOL_POINT);
   const int digits=(int)SymbolInfoInteger(g_pa_exec_symbol,SYMBOL_DIGITS);
   double sl=0.0,tp=0.0;
   if(ask<=0.0 || bid<=0.0 || ask<bid ||
      !PA_CalculateStops(signal.direction,entry,signal.invalidation_level,
                         PA_DEMO_RR,sl,tp))
     {
      Print("DEMO ORDER BLOCKED: invalid quote or invalidation-based SL.");
      return false;
     }
   sl=NormalizeDouble(sl,digits);
   tp=NormalizeDouble(tp,digits);
   const long stops_level=SymbolInfoInteger(g_pa_exec_symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(point<=0.0 ||
      (signal.direction>0 && (entry-sl<stops_level*point || tp-entry<stops_level*point)) ||
      (signal.direction<0 && (sl-entry<stops_level*point || entry-tp<stops_level*point)))
     {
      Print("DEMO ORDER BLOCKED: broker minimum stop distance not satisfied.");
      return false;
     }

   double volume=0.0,cash_risk=0.0;
   if(!PA_CalculateRiskVolume(g_pa_exec_symbol,signal.direction,entry,sl,
                             PA_DEMO_RISK_PER_TRADE_PERCENT,volume,cash_risk))
     {
      Print("DEMO ORDER BLOCKED: risk sizing failed or minimum lot exceeds 0.5% budget.");
      return false;
     }

   double existing_risk=0.0;
   int existing_positions=0;
   bool missing_sl=false;
   PA_GetManagedPositionRisk(existing_risk,existing_positions,missing_sl);
   if(missing_sl || existing_positions>=PA_DEMO_MAX_POSITIONS ||
      existing_risk+cash_risk>
         AccountInfoDouble(ACCOUNT_EQUITY)*PA_DEMO_MAX_RISK_PERCENT/100.0+0.01)
     {
      PrintFormat("DEMO ORDER BLOCKED: position/risk cap. positions=%d risk=%.2f proposed=%.2f",
                  existing_positions,existing_risk,cash_risk);
      return false;
     }

   double margin=0.0;
   const ENUM_ORDER_TYPE order_type=signal.direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(order_type,g_pa_exec_symbol,volume,entry,margin) ||
      margin<=0.0 || margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      Print("DEMO ORDER BLOCKED: margin calculation/availability check failed.");
      return false;
     }

   MqlTradeRequest request;
   MqlTradeCheckResult check;
   ZeroMemory(request);
   ZeroMemory(check);
   request.action=TRADE_ACTION_DEAL;
   request.symbol=g_pa_exec_symbol;
   request.magic=(ulong)g_pa_exec_magic;
   request.volume=volume;
   request.type=signal.direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price=entry;
   request.sl=sl;
   request.tp=tp;
   request.deviation=30;
   request.type_filling=PA_GetSymbolFillingMode(g_pa_exec_symbol);
   request.comment="PADEMO:"+StringFormat("%I64d",(long)PA_ExecutionHash(signal.setup_id));
   if(!OrderCheck(request,check) ||
      (check.retcode!=TRADE_RETCODE_DONE && check.retcode!=TRADE_RETCODE_PLACED))
     {
      PrintFormat("DEMO ORDER BLOCKED: OrderCheck retcode=%u comment=%s",
                  check.retcode,check.comment);
      return false;
     }

   // Reserve before sending. If terminal/network state becomes ambiguous,
   // the same setup is never submitted a second time automatically.
   if(!PA_ReserveSetup(signal.setup_id))
      return false;

   bool sent=false;
   if(signal.direction>0)
      sent=g_pa_trade.Buy(volume,g_pa_exec_symbol,0.0,sl,tp,request.comment);
   else
      sent=g_pa_trade.Sell(volume,g_pa_exec_symbol,0.0,sl,tp,request.comment);

   const uint retcode=g_pa_trade.ResultRetcode();
   if(!sent || (retcode!=TRADE_RETCODE_DONE &&
                retcode!=TRADE_RETCODE_DONE_PARTIAL &&
                retcode!=TRADE_RETCODE_PLACED))
     {
      PrintFormat("DEMO ORDER RESULT UNCERTAIN/REJECTED | sent=%s retcode=%u description=%s | setup remains reserved",
                  sent?"true":"false",retcode,g_pa_trade.ResultRetcodeDescription());
      return false;
     }

   PrintFormat("DEMO ORDER ACCEPTED | %s | ticket=%I64u | volume=%.2f | entry=%.*f | SL=%.*f | TP=%.*f | risk=%.2f | setup=%s",
      signal.direction>0?"BUY":"SELL",g_pa_trade.ResultOrder(),volume,
      digits,entry,digits,sl,digits,tp,cash_risk,signal.setup_id);
   return true;
  }

#endif // FOREX_AGENT_DEMO_EXECUTION_MQH
