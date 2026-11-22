//+------------------------------------------------------------------+
//| StructurePersistence.mqh                                         |
//| Terminal-global-variable persistence for PA_StructureState.      |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_STRUCTURE_PERSISTENCE_MQH
#define FOREX_AGENT_STRUCTURE_PERSISTENCE_MQH

#include "MarketStructure.mqh"

// Compact deterministic identity hash. Includes account, EA magic,
// symbol, and timeframe without exposing those values in variable names.
uint PA_StateIdentityHash(const string symbol,
                          const ENUM_TIMEFRAMES timeframe,
                          const long magic_number)
  {
   const string identity = StringFormat("%I64d|%I64d|%s|%d",
                                        AccountInfoInteger(ACCOUNT_LOGIN),
                                        magic_number,
                                        symbol,
                                        (int)timeframe);
   uint hash = 2166136261;
   const int length = StringLen(identity);
   for(int i = 0; i < length; i++)
     {
      hash ^= (uint)StringGetCharacter(identity, i);
      hash = (uint)(hash * 16777619);
     }
   return hash;
  }

string PA_StateGlobalKey(const uint identity_hash,const string field)
  {
   return StringFormat("PA%I64d.%s",(long)identity_hash,field);
  }

bool PA_WriteStateValue(const uint hash,const string field,const double value)
  {
   const datetime changed = GlobalVariableSet(PA_StateGlobalKey(hash,field),value);
   return (changed != 0);
  }

bool PA_ReadStateValue(const uint hash,const string field,double &value)
  {
   const string key = PA_StateGlobalKey(hash,field);
   if(!GlobalVariableCheck(key))
      return false;
   value = GlobalVariableGet(key);
   return MathIsValidNumber(value);
  }

bool PA_SaveStructureState(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const long magic_number,
                           const PA_StructureState &state)
  {
   if(symbol == "" || magic_number <= 0 ||
      state.direction < -1 || state.direction > 1 ||
      state.reversal_candidate_direction < -1 ||
      state.reversal_candidate_direction > 1 ||
      state.confirmed_reversal_direction < -1 ||
      state.confirmed_reversal_direction > 1)
      return false;

   const uint hash = PA_StateIdentityHash(symbol,timeframe,magic_number);
   bool ok = true;

   ok = PA_WriteStateValue(hash,"d",(double)state.direction) && ok;
   ok = PA_WriteStateValue(hash,"sh",state.latest_swing_high) && ok;
   ok = PA_WriteStateValue(hash,"sl",state.latest_swing_low) && ok;
   ok = PA_WriteStateValue(hash,"sht",(double)state.latest_swing_high_time) && ok;
   ok = PA_WriteStateValue(hash,"slt",(double)state.latest_swing_low_time) && ok;
   ok = PA_WriteStateValue(hash,"ph",state.protected_high) && ok;
   ok = PA_WriteStateValue(hash,"pl",state.protected_low) && ok;
   ok = PA_WriteStateValue(hash,"pht",(double)state.protected_high_time) && ok;
   ok = PA_WriteStateValue(hash,"plt",(double)state.protected_low_time) && ok;
   ok = PA_WriteStateValue(hash,"let",(double)state.last_structure_event_time) && ok;
   ok = PA_WriteStateValue(hash,"lbt",(double)(int)state.last_break_type) && ok;
   ok = PA_WriteStateValue(hash,"rcd",(double)state.reversal_candidate_direction) && ok;
   ok = PA_WriteStateValue(hash,"rct",(double)state.reversal_choch_time) && ok;
   ok = PA_WriteStateValue(hash,"crd",(double)state.confirmed_reversal_direction) && ok;
   ok = PA_WriteStateValue(hash,"crt",(double)state.confirmed_reversal_time) && ok;

   // Commit marker is written last. An absent marker means incomplete state.
   ok = PA_WriteStateValue(hash,"lpt",(double)state.last_processed_bar_time) && ok;
   GlobalVariablesFlush();
   return ok;
  }

bool PA_LoadStructureState(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const long magic_number,
                           PA_StructureState &state)
  {
   PA_ResetStructureState(state);
   if(symbol == "" || magic_number <= 0)
      return false;

   const uint hash = PA_StateIdentityHash(symbol,timeframe,magic_number);
   double d=0,sh=0,sl=0,sht=0,slt=0,ph=0,pl=0,pht=0,plt=0;
   double let=0,lbt=0,rcd=0,rct=0,crd=0,crt=0,lpt=0;

   if(!PA_ReadStateValue(hash,"d",d) ||
      !PA_ReadStateValue(hash,"sh",sh) ||
      !PA_ReadStateValue(hash,"sl",sl) ||
      !PA_ReadStateValue(hash,"sht",sht) ||
      !PA_ReadStateValue(hash,"slt",slt) ||
      !PA_ReadStateValue(hash,"ph",ph) ||
      !PA_ReadStateValue(hash,"pl",pl) ||
      !PA_ReadStateValue(hash,"pht",pht) ||
      !PA_ReadStateValue(hash,"plt",plt) ||
      !PA_ReadStateValue(hash,"let",let) ||
      !PA_ReadStateValue(hash,"lbt",lbt) ||
      !PA_ReadStateValue(hash,"rcd",rcd) ||
      !PA_ReadStateValue(hash,"rct",rct) ||
      !PA_ReadStateValue(hash,"crd",crd) ||
      !PA_ReadStateValue(hash,"crt",crt) ||
      !PA_ReadStateValue(hash,"lpt",lpt))
      return false;

   if(d < -1 || d > 1 || MathFloor(d) != d ||
      rcd < -1 || rcd > 1 || MathFloor(rcd) != rcd ||
      crd < -1 || crd > 1 || MathFloor(crd) != crd ||
      lbt < 0 || lbt > (double)PA_BREAK_CHOCH_BEARISH || MathFloor(lbt) != lbt ||
      sh < 0 || sl < 0 || ph < 0 || pl < 0 ||
      lpt < 0 || sht < 0 || slt < 0 || pht < 0 || plt < 0 ||
      let < 0 || rct < 0 || crt < 0)
      return false;

   state.direction = (int)d;
   state.latest_swing_high = sh;
   state.latest_swing_low = sl;
   state.latest_swing_high_time = (datetime)sht;
   state.latest_swing_low_time = (datetime)slt;
   state.protected_high = ph;
   state.protected_low = pl;
   state.protected_high_time = (datetime)pht;
   state.protected_low_time = (datetime)plt;
   state.last_structure_event_time = (datetime)let;
   state.last_break_type = (PA_BreakType)(int)lbt;
   state.reversal_candidate_direction = (int)rcd;
   state.reversal_choch_time = (datetime)rct;
   state.confirmed_reversal_direction = (int)crd;
   state.confirmed_reversal_time = (datetime)crt;
   state.last_processed_bar_time = (datetime)lpt;

   if(state.direction != 0 &&
      state.latest_swing_high_time <= 0 &&
      state.latest_swing_low_time <= 0)
     {
      PA_ResetStructureState(state);
      return false;
     }
   return (state.last_processed_bar_time > 0);
  }

#endif // FOREX_AGENT_STRUCTURE_PERSISTENCE_MQH
