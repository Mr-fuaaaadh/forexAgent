//+------------------------------------------------------------------+
//| DemoExecutionFixture.mq5                                         |
//| Deterministic tests for the pure stop/target calculations.         |
//| Broker/account-dependent checks are covered by the test plan.     |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "..\\Include\\SecondaryStrategyRuntime.mqh"
#include "..\\Include\\DemoExecution.mqh"

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

void OnStart()
  {
   double sl=0.0,tp=0.0;

   Check("buy stop is below entry and target above",
      PA_CalculateStops(1,4000.0,3995.0,2.0,sl,tp) &&
      MathAbs(sl-3995.0)<0.000001 &&
      MathAbs(tp-4010.0)<0.000001);

   Check("sell stop is above entry and target below",
      PA_CalculateStops(-1,4000.0,4005.0,2.0,sl,tp) &&
      MathAbs(sl-4005.0)<0.000001 &&
      MathAbs(tp-3990.0)<0.000001);

   Check("buy invalidation above entry is rejected",
      !PA_CalculateStops(1,4000.0,4001.0,2.0,sl,tp));

   Check("sell invalidation below entry is rejected",
      !PA_CalculateStops(-1,4000.0,3999.0,2.0,sl,tp));

   Check("unsupported reward ratio is rejected",
      !PA_CalculateStops(1,4000.0,3995.0,3.0,sl,tp));

   Check("invalid direction is rejected",
      !PA_CalculateStops(0,4000.0,3995.0,2.0,sl,tp));

   Check("static max-loss floor is 88% of starting balance",
      MathAbs(PA_ChallengeStaticLossFloor(10000.0)-8800.0)<0.000001);
   Check("static max-loss triggers at 12% equity drawdown",
      PA_IsChallengeStaticLossTriggered(10000.0,8800.0));
   Check("static max-loss stays clear above floor",
      !PA_IsChallengeStaticLossTriggered(10000.0,8800.01));
   Check("single profit target is 110% of starting balance",
      MathAbs(PA_ChallengeProfitTarget(10000.0)-11000.0)<0.000001);
   Check("single target triggers at target balance",
      PA_IsChallengeProfitTargetReached(10000.0,11000.0));
   Check("2% internal daily equity guard triggers at threshold",
      PA_IsDailyInternalLossTriggered(10000.0,9800.0));
   Check("2% internal daily equity guard remains clear above threshold",
      !PA_IsDailyInternalLossTriggered(10000.0,9800.01));

   PrintFormat("Demo execution fixtures complete. Passed=%d Failed=%d",
      g_passed,g_failed);
  }
