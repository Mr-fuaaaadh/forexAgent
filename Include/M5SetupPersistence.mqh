//+------------------------------------------------------------------+
//| M5SetupPersistence.mqh                                           |
//| Persists in-progress M5 setup state to MT5 terminal globals.      |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_M5_SETUP_PERSISTENCE_MQH
#define FOREX_AGENT_M5_SETUP_PERSISTENCE_MQH

#include "M5EntrySignal.mqh"

uint PA_M5SetupIdentityHash(const string symbol,const long magic_number)
  {
   const string identity=StringFormat("%I64d|%I64d|%s|M5",
      AccountInfoInteger(ACCOUNT_LOGIN),magic_number,symbol);
   uint hash=2166136261;
   for(int i=0;i<StringLen(identity);i++)
     {
      hash^=(uint)StringGetCharacter(identity,i);
      hash=(uint)(hash*16777619);
     }
   return hash;
  }

string PA_M5SetupKey(const uint hash,const string field)
  {
   return StringFormat("PAM5%I64d.%s",(long)hash,field);
  }

bool PA_M5Write(const uint hash,const string field,const double value)
  {
   return (GlobalVariableSet(PA_M5SetupKey(hash,field),value)!=0);
  }

bool PA_M5Read(const uint hash,const string field,double &value)
  {
   const string key=PA_M5SetupKey(hash,field);
   if(!GlobalVariableCheck(key))
      return false;
   value=GlobalVariableGet(key);
   return MathIsValidNumber(value);
  }

bool PA_SaveM5SetupState(const string symbol,const long magic_number,
                         const PA_M5SetupState &state)
  {
   if(symbol=="" || magic_number<=0 ||
      state.stage<PA_SETUP_IDLE || state.stage>PA_SETUP_WAIT_RETEST ||
      state.direction < -1 || state.direction > 1 ||
      state.bars_since_sweep<0 || state.bars_since_choch<0)
      return false;

   const uint hash=PA_M5SetupIdentityHash(symbol,magic_number);
   bool ok=true;
   ok=PA_M5Write(hash,"st",(double)(int)state.stage) && ok;
   ok=PA_M5Write(hash,"dir",(double)state.direction) && ok;
   ok=PA_M5Write(hash,"sw",(double)state.sweep_time) && ok;
   ok=PA_M5Write(hash,"ex",state.sweep_extreme) && ok;
   ok=PA_M5Write(hash,"lvl",state.swept_level) && ok;
   ok=PA_M5Write(hash,"ch",(double)state.choch_time) && ok;
   ok=PA_M5Write(hash,"fv",(double)state.fvg_time) && ok;
   ok=PA_M5Write(hash,"lo",state.fvg_lower) && ok;
   ok=PA_M5Write(hash,"hi",state.fvg_upper) && ok;
   ok=PA_M5Write(hash,"bs",(double)state.bars_since_sweep) && ok;
   ok=PA_M5Write(hash,"bc",(double)state.bars_since_choch) && ok;
   ok=PA_M5Write(hash,"lp",(double)state.last_processed_bar_time) && ok;

   // Store the last setup ID as two numeric hashes to avoid string globals.
   uint id_hash=2166136261;
   if(StringFind(state.last_emitted_setup_id,"HASH:")==0)
      id_hash=(uint)StringToInteger(StringSubstr(state.last_emitted_setup_id,5));
   else
     {
      for(int i=0;i<StringLen(state.last_emitted_setup_id);i++)
        {
         id_hash^=(uint)StringGetCharacter(state.last_emitted_setup_id,i);
         id_hash=(uint)(id_hash*16777619);
        }
     }
   ok=PA_M5Write(hash,"idh",(double)id_hash) && ok;
   GlobalVariablesFlush();
   return ok;
  }

// The actual setup ID string is intentionally not reconstructed from its
// hash. The persisted hash is retained separately for duplicate auditing;
// the latest closed-bar timestamp prevents replay of the last signal candle.
bool PA_LoadM5SetupState(const string symbol,const long magic_number,
                         PA_M5SetupState &state)
  {
   PA_ResetM5SetupState(state);
   if(symbol=="" || magic_number<=0)
      return false;
   const uint hash=PA_M5SetupIdentityHash(symbol,magic_number);
   double st=0,dir=0,sw=0,ex=0,lvl=0,ch=0,fv=0,lo=0,hi=0,bs=0,bc=0,lp=0,idh=0;
   if(!PA_M5Read(hash,"st",st) || !PA_M5Read(hash,"dir",dir) ||
      !PA_M5Read(hash,"sw",sw) || !PA_M5Read(hash,"ex",ex) ||
      !PA_M5Read(hash,"lvl",lvl) || !PA_M5Read(hash,"ch",ch) ||
      !PA_M5Read(hash,"fv",fv) || !PA_M5Read(hash,"lo",lo) ||
      !PA_M5Read(hash,"hi",hi) || !PA_M5Read(hash,"bs",bs) ||
      !PA_M5Read(hash,"bc",bc) || !PA_M5Read(hash,"lp",lp) ||
      !PA_M5Read(hash,"idh",idh))
      return false;

   if(st<PA_SETUP_IDLE || st>PA_SETUP_WAIT_RETEST || MathFloor(st)!=st ||
      dir < -1 || dir > 1 || MathFloor(dir)!=dir ||
      bs<0 || bc<0 || MathFloor(bs)!=bs || MathFloor(bc)!=bc ||
      sw<0 || ch<0 || fv<0 || lp<0)
      return false;

   state.stage=(PA_SetupStage)(int)st;
   state.direction=(int)dir;
   state.sweep_time=(datetime)sw;
   state.sweep_extreme=ex;
   state.swept_level=lvl;
   state.choch_time=(datetime)ch;
   state.fvg_time=(datetime)fv;
   state.fvg_lower=lo;
   state.fvg_upper=hi;
   state.bars_since_sweep=(int)bs;
   state.bars_since_choch=(int)bc;
   state.last_processed_bar_time=(datetime)lp;
   // Keep a stable marker so the caller can avoid replaying an emitted ID.
   state.last_emitted_setup_id=StringFormat("HASH:%I64d",(long)idh);
   if(state.stage!=PA_SETUP_IDLE && state.direction==0)
     {
      PA_ResetM5SetupState(state);
      return false;
     }
   return (state.last_processed_bar_time>0);
  }

#endif // FOREX_AGENT_M5_SETUP_PERSISTENCE_MQH
