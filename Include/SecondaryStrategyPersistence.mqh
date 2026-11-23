//+------------------------------------------------------------------+
//| SecondaryStrategyPersistence.mqh                                 |
//| Persists secondary strategy setup state in MT5 terminal globals.  |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_SECONDARY_STRATEGY_PERSISTENCE_MQH
#define FOREX_AGENT_SECONDARY_STRATEGY_PERSISTENCE_MQH

#include "SecondaryStrategies.mqh"

uint PA_SecondaryIdentityHash(const string symbol,const long magic_number)
  {
   const string identity=StringFormat("%I64d|%I64d|%s|SECONDARY",
      AccountInfoInteger(ACCOUNT_LOGIN),magic_number,symbol);
   uint hash=2166136261;
   for(int i=0;i<StringLen(identity);i++)
     {
      hash^=(uint)StringGetCharacter(identity,i);
      hash=(uint)(hash*16777619);
     }
   return hash;
  }

string PA_SecondaryKey(const uint hash,const string suffix)
  {
   return StringFormat("PASEC%I64d.%s",(long)hash,suffix);
  }

bool PA_SecondaryWrite(const uint hash,const string suffix,const double value)
  {
   return (GlobalVariableSet(PA_SecondaryKey(hash,suffix),value)!=0);
  }

bool PA_SecondaryRead(const uint hash,const string suffix,double &value)
  {
   const string key=PA_SecondaryKey(hash,suffix);
   if(!GlobalVariableCheck(key))
      return false;
   value=GlobalVariableGet(key);
   return MathIsValidNumber(value);
  }

bool PA_SaveOneSecondarySetup(const uint hash,const string prefix,
                              const PA_SecondarySetup &setup)
  {
   bool ok=true;
   ok=PA_SecondaryWrite(hash,prefix+"st",(double)(int)setup.stage) && ok;
   ok=PA_SecondaryWrite(hash,prefix+"di",(double)setup.direction) && ok;
   ok=PA_SecondaryWrite(hash,prefix+"ev",(double)setup.source_event_time) && ok;
   ok=PA_SecondaryWrite(hash,prefix+"ct",(double)setup.setup_created_time) && ok;
   ok=PA_SecondaryWrite(hash,prefix+"lo",setup.zone_low) && ok;
   ok=PA_SecondaryWrite(hash,prefix+"hi",setup.zone_high) && ok;
   ok=PA_SecondaryWrite(hash,prefix+"rf",setup.reference_level) && ok;
   ok=PA_SecondaryWrite(hash,prefix+"pe",setup.pullback_extreme) && ok;
   ok=PA_SecondaryWrite(hash,prefix+"bw",(double)setup.bars_waiting) && ok;
   uint id_hash=2166136261;
   if(StringFind(setup.setup_id,"HASH:")==0)
      id_hash=(uint)StringToInteger(StringSubstr(setup.setup_id,5));
   else
     {
      for(int i=0;i<StringLen(setup.setup_id);i++)
        {
         id_hash^=(uint)StringGetCharacter(setup.setup_id,i);
         id_hash=(uint)(id_hash*16777619);
        }
     }
   ok=PA_SecondaryWrite(hash,prefix+"id",(double)id_hash) && ok;
   return ok;
  }

bool PA_LoadOneSecondarySetup(const uint hash,const string prefix,
                              PA_SecondarySetup &setup)
  {
   PA_ResetSecondarySetup(setup);
   double st=0,di=0,ev=0,ct=0,lo=0,hi=0,rf=0,pe=0,bw=0,id=0;
   if(!PA_SecondaryRead(hash,prefix+"st",st) ||
      !PA_SecondaryRead(hash,prefix+"di",di) ||
      !PA_SecondaryRead(hash,prefix+"ev",ev) ||
      !PA_SecondaryRead(hash,prefix+"ct",ct) ||
      !PA_SecondaryRead(hash,prefix+"lo",lo) ||
      !PA_SecondaryRead(hash,prefix+"hi",hi) ||
      !PA_SecondaryRead(hash,prefix+"rf",rf) ||
      !PA_SecondaryRead(hash,prefix+"pe",pe) ||
      !PA_SecondaryRead(hash,prefix+"bw",bw) ||
      !PA_SecondaryRead(hash,prefix+"id",id))
      return false;

   if(st<PA_SECONDARY_IDLE || st>PA_SECONDARY_WAIT_TRIGGER ||
      MathFloor(st)!=st || di < -1 || di > 1 || MathFloor(di)!=di ||
      ev<0 || ct<0 || bw<0 || MathFloor(bw)!=bw)
      return false;

   setup.stage=(PA_SecondaryStage)(int)st;
   setup.direction=(int)di;
   setup.source_event_time=(datetime)ev;
   setup.setup_created_time=(datetime)ct;
   setup.zone_low=lo;
   setup.zone_high=hi;
   setup.reference_level=rf;
   setup.pullback_extreme=pe;
   setup.bars_waiting=(int)bw;
   setup.setup_id=StringFormat("HASH:%I64d",(long)id);
   if(setup.stage!=PA_SECONDARY_IDLE &&
      (setup.direction==0 || setup.source_event_time<=0))
     {
      PA_ResetSecondarySetup(setup);
      return false;
     }
   return true;
  }

bool PA_SaveSecondaryStrategyState(const string symbol,const long magic_number,
                                   const PA_SecondaryStrategyState &state)
  {
   if(symbol=="" || magic_number<=0 ||
      state.last_processed_m5_bar_time<0 ||
      state.last_seen_m15_event_time<0)
      return false;
   const uint hash=PA_SecondaryIdentityHash(symbol,magic_number);
   bool ok=true;
   ok=PA_SecondaryWrite(hash,"lp",(double)state.last_processed_m5_bar_time) && ok;
   ok=PA_SecondaryWrite(hash,"me",(double)state.last_seen_m15_event_time) && ok;
   ok=PA_SaveOneSecondarySetup(hash,"ob",state.order_block) && ok;
   ok=PA_SaveOneSecondarySetup(hash,"br",state.breakout) && ok;
   ok=PA_SaveOneSecondarySetup(hash,"tr",state.continuation) && ok;
   ok=PA_SaveOneSecondarySetup(hash,"b2",state.model_b2) && ok;
   uint emitted=2166136261;
   if(StringFind(state.last_emitted_setup_id,"HASH:")==0)
      emitted=(uint)StringToInteger(StringSubstr(state.last_emitted_setup_id,5));
   else
     {
      for(int i=0;i<StringLen(state.last_emitted_setup_id);i++)
        {
         emitted^=(uint)StringGetCharacter(state.last_emitted_setup_id,i);
         emitted=(uint)(emitted*16777619);
        }
     }
   ok=PA_SecondaryWrite(hash,"em",(double)emitted) && ok;
   GlobalVariablesFlush();
   return ok;
  }

bool PA_LoadSecondaryStrategyState(const string symbol,const long magic_number,
                                   PA_SecondaryStrategyState &state)
  {
   PA_ResetSecondaryStrategyState(state);
   if(symbol=="" || magic_number<=0)
      return false;
   const uint hash=PA_SecondaryIdentityHash(symbol,magic_number);
   double lp=0,me=0,em=0;
   if(!PA_SecondaryRead(hash,"lp",lp) ||
      !PA_SecondaryRead(hash,"me",me) ||
      !PA_SecondaryRead(hash,"em",em))
      return false;
   if(lp<0 || me<0)
      return false;
   if(!PA_LoadOneSecondarySetup(hash,"ob",state.order_block) ||
      !PA_LoadOneSecondarySetup(hash,"br",state.breakout) ||
      !PA_LoadOneSecondarySetup(hash,"tr",state.continuation))
      return false;
   // Backward compatibility: pre-B2 state has no B2 keys. Accept that
   // complete legacy state with an idle B2 slot; partial/corrupt B2 state
   // remains fail-closed.
   if(GlobalVariableCheck(PA_SecondaryKey(hash,"b2st")))
     {
      if(!PA_LoadOneSecondarySetup(hash,"b2",state.model_b2))
         return false;
     }
   else
      PA_ResetSecondarySetup(state.model_b2);
   state.last_processed_m5_bar_time=(datetime)lp;
   state.last_seen_m15_event_time=(datetime)me;
   state.last_emitted_setup_id=StringFormat("HASH:%I64d",(long)em);
   return true;
  }

#endif // FOREX_AGENT_SECONDARY_STRATEGY_PERSISTENCE_MQH
