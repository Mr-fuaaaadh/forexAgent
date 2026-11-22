//+------------------------------------------------------------------+
//| SecondaryStrategyRuntime.mqh                                     |
//| New-bar dispatcher, fail-closed context checks and arbitration.  |
//+------------------------------------------------------------------+
#ifndef FOREX_AGENT_SECONDARY_STRATEGY_RUNTIME_MQH
#define FOREX_AGENT_SECONDARY_STRATEGY_RUNTIME_MQH

#include "SecondaryStrategyPersistence.mqh"

uint PA_SecondarySetupHash(const string setup_id)
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(setup_id);i++)
     {
      hash^=(uint)StringGetCharacter(setup_id,i);
      hash=(uint)(hash*16777619);
     }
   return hash;
  }

string PA_SecondaryHashMarker(const string setup_id)
  {
   return StringFormat("HASH:%I64d",(long)PA_SecondarySetupHash(setup_id));
  }

bool PA_RunSecondaryStrategies(const string symbol,
                               const long magic_number,
                               const MqlRates &m15_rates[],
                               const int m15_count,
                               const PA_StructureState &m15_state,
                               const PA_MultiTimeframeSnapshot &context,
                               const MqlRates &m5_rates[],
                               const int m5_count,
                               const double spread_price,
                               const PA_StructureSnapshot &m5_snapshot,
                               PA_SecondaryStrategyState &state,
                               PA_StrategySignal &selected)
  {
   PA_ResetStrategySignal(selected);
   if(symbol=="" || magic_number<=0 || m15_count<20 || m5_count<20 ||
      m15_rates[1].time<=0 || m5_rates[1].time<=0 ||
      spread_price<0.0)
     {
      selected.rejection_reason="INVALID_SECONDARY_RUNTIME_INPUT";
      return false;
     }

   if(state.last_processed_m5_bar_time>0 &&
      m5_rates[1].time<=state.last_processed_m5_bar_time)
     {
      selected.rejection_reason="DUPLICATE_OR_OLD_M5_BAR";
      return false;
     }
   state.last_processed_m5_bar_time=m5_rates[1].time;

   // Any unavailable/conflicting context invalidates pending secondary
   // setups. No countertrend secondary setup is permitted in this phase.
   if(context.context!=PA_CONTEXT_BULLISH_ALIGNED &&
      context.context!=PA_CONTEXT_BEARISH_ALIGNED)
     {
      PA_ResetSecondarySetup(state.order_block);
      PA_ResetSecondarySetup(state.breakout);
      PA_ResetSecondarySetup(state.continuation);
      selected.rejection_reason="H1_M15_CONTEXT_NOT_ALIGNED";
      PA_SaveSecondaryStrategyState(symbol,magic_number,state);
      return false;
     }

   // Discard setups whose direction is no longer aligned with the context.
   const int context_direction=context.context==PA_CONTEXT_BULLISH_ALIGNED?1:-1;
   if(state.order_block.stage!=PA_SECONDARY_IDLE &&
      state.order_block.direction!=context_direction)
      PA_ResetSecondarySetup(state.order_block);
   if(state.breakout.stage!=PA_SECONDARY_IDLE &&
      state.breakout.direction!=context_direction)
      PA_ResetSecondarySetup(state.breakout);
   if(state.continuation.stage!=PA_SECONDARY_IDLE &&
      state.continuation.direction!=context_direction)
      PA_ResetSecondarySetup(state.continuation);

   // Capture an M15 BOS only when it is the currently completed M15 bar.
   PA_CaptureM15BOS(symbol,m15_rates,m15_count,m15_state,context,state);

   PA_StrategySignal candidates[3];
   for(int i=0;i<3;i++)
      PA_ResetStrategySignal(candidates[i]);

   PA_EvaluateBOSOrderBlockRetest(symbol,m5_rates,m5_count,spread_price,
      m5_snapshot,state.order_block,candidates[0]);
   PA_EvaluateBreakoutRetest(symbol,m5_rates,m5_count,spread_price,
      m5_snapshot,state.breakout,candidates[1]);
   PA_EvaluateTrendPullback(symbol,m5_rates,m5_count,spread_price,
      m5_snapshot,state.continuation,candidates[2]);

   const bool arbitrated=PA_ArbitrateStrategySignals(candidates,3,selected);
   if(arbitrated)
     {
      const string marker=PA_SecondaryHashMarker(selected.setup_id);
      if(marker==state.last_emitted_setup_id)
        {
         PA_ResetStrategySignal(selected);
         selected.rejection_reason="DUPLICATE_SECONDARY_SETUP_ID";
        }
      else
        {
         state.last_emitted_setup_id=marker;
         selected.rejection_reason="PRIORITY_SELECTED_NO_ORDER_SENT";
        }
     }

   if(!PA_SaveSecondaryStrategyState(symbol,magic_number,state))
     {
      PA_ResetStrategySignal(selected);
      selected.rejection_reason="SECONDARY_PERSISTENCE_FAILED_FAIL_CLOSED";
      return false;
     }
   return arbitrated && selected.strategy!=PA_STRATEGY_NONE;
  }

// Combine the primary sweep strategy and secondary strategies under one
// priority order. A direction conflict among any qualified signals means
// no trade. The caller must pass only signals from this same M5 decision.
bool PA_ArbitrateAllStrategies(const PA_M5Signal &primary,
                               const PA_StrategySignal &secondary[],
                               const int secondary_count,
                               PA_StrategySignal &selected)
  {
   PA_ResetStrategySignal(selected);
   if(secondary_count<0 || secondary_count>3)
     {
      selected.rejection_reason="INVALID_STRATEGY_SIGNAL_COUNT";
      return false;
     }

   PA_StrategySignal all[4];
   for(int i=0;i<4;i++)
      PA_ResetStrategySignal(all[i]);

   if(primary.signal==PA_ENTRY_BUY || primary.signal==PA_ENTRY_SELL)
     {
      all[0].strategy=PA_STRATEGY_SWEEP_CHOCH_FVG;
      all[0].direction=primary.direction;
      all[0].signal_bar_time=primary.signal_bar_time;
      all[0].source_event_time=primary.sweep_time;
      all[0].reference_level=primary.fvg_lower;
      all[0].invalidation_level=primary.sweep_extreme;
      all[0].zone_low=primary.fvg_lower;
      all[0].zone_high=primary.fvg_upper;
      all[0].setup_id=primary.setup_id;
      all[0].rejection_reason=primary.rejection_reason;
     }

   for(int i=0;i<secondary_count;i++)
      all[i+1]=secondary[i];

   return PA_ArbitrateStrategySignals(all,secondary_count+1,selected);
  }

#endif // FOREX_AGENT_SECONDARY_STRATEGY_RUNTIME_MQH
