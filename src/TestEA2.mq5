//+------------------------------------------------------------------+
//|                                                      TestEA2.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- input parameters
input double risk = 0.05;
input int ESTOffset = -4;

//--- Global variables intialization
datetime latestM1Time;
datetime latestM15Time;
double latestM15High;
double latestM15Low;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("TestEA2 starting... WOOHOO!");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Get the latest tick
   MqlTick currentPrice;
   SymbolInfoTick(_Symbol, currentPrice);
   
   // Get M1 candles and time
   MqlRates candlesM1[];
   datetime currentM1Time[1];
   CopyRates(_Symbol, PERIOD_M1, 0, 30, candlesM1);
   CopyTime(_Symbol, PERIOD_M1, 0, 1, currentM1Time);
   
   // Get M15 candles and time
   MqlRates candlesM15[];
   datetime currentM15Time[1];
   CopyRates(_Symbol, PERIOD_M15, 0, 4, candlesM15);
   CopyTime(_Symbol, PERIOD_M15, 0, 1, currentM15Time);

   // Calling the on-close events   
   if (latestM1Time != currentM1Time[0]){
      onM1Close(candlesM1);
      latestM1Time = currentM1Time[0];
   }
   if (latestM15Time != currentM15Time[0]){
      onM15Close(candlesM15);
      latestM15Time = currentM15Time[0];
   }
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| On-Close Events                                                  |
//+------------------------------------------------------------------+
//===== M1 On-Close Event =====
void onM1Close(MqlRates &candlesM1[]){
   if (hasDisplaced(candlesM1, 3.5)){
      Print("Displacement occured on M1");
   }
}


//===== M15 On-Close Event =====
void onM15Close(MqlRates &candlesM15[]){
   double swingHigh = formedSwingHigh(candlesM15);
   double swingLow = formedSwingLow(candlesM15);
   double bullishFVG = formedBullishFVG(candlesM15);
   double bearishFVG = formedBearishFVG(candlesM15);
   
   if (swingHigh != NULL){
      latestM15High = swingHigh;
      Print("Formed a swing high on M15");
   }
   if (swingLow != NULL){
      latestM15Low = swingLow;
      Print("Formed a swing low on M15");
   }
   if (bullishFVG != NULL){
      Print("Formed a bullish FVG on M15");
   }
   if (bearishFVG != NULL){
      Print("Formed a bearishFVG FVG on M15");
   }
   
   MqlDateTime UTCNow;
   TimeGMT(UTCNow);
   Print(UTCNow.hour);
   
   Print(isWithinSession());
}



//+------------------------------------------------------------------+
//| Utils Functions                                                  |
//+------------------------------------------------------------------+
//===== Function to check for swing high =====
double formedSwingHigh(MqlRates &candles[]){
   int s = ArraySize(candles);
   if ((candles[s-4].high < candles[s-3].high) && (candles[s-2].high < candles[s-3].high)){
      return candles[s-3].high;
   }
   return NULL;
}
 
//===== Function to check for swing low =====
double formedSwingLow(MqlRates &candles[]){
   int s = ArraySize(candles);
   if ((candles[s-4].low > candles[s-3].low) && (candles[s-2].low > candles[s-3].low)){
      return candles[s-3].low;
   }
   return NULL;
}

//===== Function to check for bullish FVG =====
bool formedBullishFVG(MqlRates &candles[], double &levels[]){
   int s = ArraySize(candles);
   if (candles[s-4].high < candles[s-2].low){
      levels[0] = candles[s-2].low;  // FGV entry point
      levels[1] = candles[s-4].high;  // FVG end point
      levels[2] = (candles[s-2].low + candles[s-4].high) / 2;  // FVG midpoint
      return true;
   }
   return false;
}
 
//===== Function to check for bearish FVG =====
bool formedBearishFVG(MqlRates &candles[], double &levels[]){
   int s = ArraySize(candles);
   if (candles[s-4].low > candles[s-2].high){
      levels[0] = candles[s-2].high;  // FGV entry point
      levels[1] = candles[s-4].low;  // FVG end point
      levels[2] = (candles[s-2].high + candles[s-4].low) / 2;  // FVG midpoint
      return true;
   }
   return false;
}

//===== Function to check for bullish engulfing =====
bool formedBullishEngulfing(MqlRates &candles[], double &levels[]){
   int s = ArraySize(candles);
   if (candles[s-3].close < candles[s-3].open && candles[s-2].close > candles[s-3].high){
      levels[0] = candles[s-3].open;  // Engulfing entry point (body)
      levels[1] = candles[s-3].low;  // Engulfing end point (low)
      return true;
   }
   return false;
}

//===== Function to check for bearish engulfing =====
bool formedBearishEngulfing(MqlRates &candles[], double &levels[]){
   int s = ArraySize(candles);
   if (candles[s-3].close > candles[s-3].open && candles[s-2].close < candles[s-3].low){
      levels[0] = candles[s-3].open;  // Engulfing entry point (body)
      levels[1] = candles[s-3].high;  // Engulfing end point (high)
      return true;
   }
   return false;
}

//===== Function to check for displacement =====
bool hasDisplaced(MqlRates &candles[], double displacementStrength){
   int closedCandlesCount = ArraySize(candles)-1;

   // Calculate the mean
   double sum = 0;
   for (int i=0; i<closedCandlesCount; i++){
      sum += MathAbs(candles[i].close - candles[i].open);
   }
   double mean = sum / closedCandlesCount;
   
   // Calculate the standard deviation
   double dSum = 0;
   for (int i=0; i<closedCandlesCount; i++){
      dSum += MathPow((MathAbs(candles[i].close - candles[i].open) - mean), 2);
   }
   double std = MathSqrt(dSum / closedCandlesCount);
   
   // Check if the candle size is bigger than the standard deviation
   int lastCandleIndex = closedCandlesCount - 1;
   double lastCandleRange = MathAbs(candles[lastCandleIndex].close - candles[lastCandleIndex].open);
   bool displaced = lastCandleRange > (std * displacementStrength);
   
   return displaced;
}

//===== Function to determine the bias and previous candle's DOL =====
double getBiasAndDOL(MqlRates &candles[], int &biasDst){
   int s = ArraySize(candles);
   double dol = NULL;
   
   if (candles[s-2].high > candles[s-3].high && candles[s-2].low < candles[s-3].low){  // High and low of prev candle ran
      double midPoint = (candles[s-3].high + candles[s-3].low) / 2;
      if (candles[s-2].close > midPoint){  // Closed nearer to prev candle's high
         biasDst = BullishBias;
      }
      else{  // Closed nearer to the prev candle's low
         biasDst = BearishBias;
      }
   }
   else if (candles[s-2].high > candles[s-3].high){
      if (candles[s-2].close > candles[s-3].high){  // Closed above the prev candle's high
         biasDst = BullishBias;
      }
      else{  // FTD above the prev candle's high
         biasDst = BearishBias;
      }
   }
   else if (candles[s-2].low < candles[s-3].low){
      if (candles[s-2].close < candles[s-3].low){  // Closed below the prev candle's low
         biasDst = BearishBias;
      }
      else{  // Closed below the prev candle's low
         biasDst = BullishBias;
      }
   }
   
   // Determine the Draw on Liquidity (DOL)
   if (biasDst == BullishBias){
      dol = candles[s-2].high;
   }
   else if (biasDst == BearishBias){
      dol = candles[s-2].low;
   }
   
   return dol;
}

//===== Function to check if we're within the killzone sessions =====
bool isWithinSession(){   
   // Get the time in GMT 
   MqlDateTime UTCNow;
   TimeGMT(UTCNow);
   
   int ESTNowHour = UTCNow.hour + ESTOffset;
   
   if (ESTNowHour == 2 || ESTNowHour == 3 || ESTNowHour == 4 || ESTNowHour == 7 || ESTNowHour == 8 || ESTNowHour == 10 || ESTNowHour == 11){
      return true;
   }
   return false;
}
