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
datetime latestM5Time;
datetime latestM15Time;
datetime latestH1Time;
double latestM15High;
double latestM15Low;
double freshSwingHighsM1[];
double freshSwingLowsM1[];
int biasH1;
double dolH1;
double bullishEntryPoint;
double bullishSLPoint;
double bullishTPPoint;
double bearishEntryPoint;
double bearishSLPoint;
double bearishTPPoint;
bool executedOrder = false;

//--- Static variables
static int BullishBias = 1;
static int BearishBias = 2;

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
   
   // Get M1 candles and time
   MqlRates candlesM5[];
   datetime currentM5Time[1];
   CopyRates(_Symbol, PERIOD_M5, 0, 4, candlesM5);
   CopyTime(_Symbol, PERIOD_M5, 0, 1, currentM5Time);
   
   // Get M15 candles and time
   MqlRates candlesM15[];
   datetime currentM15Time[1];
   CopyRates(_Symbol, PERIOD_M15, 0, 4, candlesM15);
   CopyTime(_Symbol, PERIOD_M15, 0, 1, currentM15Time);
   
   // Get H1 candles and time
   MqlRates candlesH1[];
   datetime currentH1Time[1];
   CopyRates(_Symbol, PERIOD_H1, 0, 4, candlesH1);
   CopyTime(_Symbol, PERIOD_H1, 0, 1, currentH1Time);

   // Calling the on-close events   
   if (latestM1Time != currentM1Time[0]){
      onM1Close(candlesM1);
      latestM1Time = currentM1Time[0];
   }
   if (latestM5Time != currentM5Time[0]){
      onM5Close(candlesM5);
      latestM5Time = currentM5Time[0];
   }
   if (latestM15Time != currentM15Time[0]){
      onM15Close(candlesM15);
      latestM15Time = currentM15Time[0];
   }
   if (latestH1Time != currentH1Time[0]){
      onH1Close(candlesH1);
      latestH1Time = currentH1Time[0];
   }
   
   // Execute the orders if ready
   executeIfReady(currentPrice);
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| On-Close Events                                                  |
//+------------------------------------------------------------------+
//===== M1 On-Close Event =====
void onM1Close(MqlRates &candlesM1[]){
   /*// Check for swing highs and lows formation
   double swingHigh = formedSwingHigh(candlesM1);
   double swingLow = formedSwingLow(candlesM1);
   
   // Check for FVGs formation
   double bullishFVG[3];
   double bearishFVG[3];
   bool bullishFVGFormed = formedBullishFVG(candlesM1, bullishFVG);
   bool bearishFVGFormed = formedBearishFVG(candlesM1, bearishFVG);
   
   if (swingHigh != NULL){
      int i = ArraySize(freshSwingHighsM1);
      ArrayResize(freshSwingHighsM1, i+1);
      freshSwingHighsM1[i] = swingHigh;
      if (i >= 30){
         ArrayRemove(freshSwingHighsM1, 0, 1);
      }
      Print("Formed a swing high on M1");
   }
   if (swingLow != NULL){
      int i = ArraySize(freshSwingLowsM1);
      ArrayResize(freshSwingLowsM1, i+1);
      freshSwingLowsM1[i] = swingLow;
      if (i >= 30){
         ArrayRemove(freshSwingLowsM1, 0, 1);
      }
      Print("Formed a swing low on M1");
   }
   if (bullishFVGFormed){
      Print("Formed a bullish FVG on M1");
   }
   if (bearishFVGFormed){
      Print("Formed a bearishFVG FVG on M1");
   }
   
   if (hasDisplaced(candlesM1, 3.5)){
      Print("Displacement occured on M1");
   }*/
}


//===== M5 On-Close Event =====
void onM5Close(MqlRates &candlesM5[]){    
   if (biasH1 == BullishBias){
      double bullishEngulfing[2];
      bool bullishEngulfingFormed = formedBullishEngulfing(candlesM5, bullishEngulfing);
      if (bullishEngulfingFormed){
         Print("Bullish engulfing formed on M5");
         bullishEntryPoint = bullishEngulfing[0];
         bullishSLPoint = bullishEngulfing[1];
      }
   }
   else if (biasH1 == BearishBias){
      double bearishEngulfing[2];
      bool bearishEngulfingFormed = formedBearishEngulfing(candlesM5, bearishEngulfing);
      if (bearishEngulfingFormed){
         Print("Bearish engulfing formed on M5");
         bearishEntryPoint = bearishEngulfing[0];
         bearishSLPoint = bearishEngulfing[1];
      }
   }
}


//===== M15 On-Close Event =====
void onM15Close(MqlRates &candlesM15[]){
   /*// Check for swing highs and lows formation
   double swingHigh = formedSwingHigh(candlesM15);
   double swingLow = formedSwingLow(candlesM15);
   
   // Check for FVGs formation
   double bullishFVG[3];
   double bearishFVG[3];
   bool bullishFVGFormed = formedBullishFVG(candlesM15, bullishFVG);
   bool bearishFVGFormed = formedBearishFVG(candlesM15, bearishFVG);
   
   if (swingHigh != NULL){
      latestM15High = swingHigh;
      Print("Formed a swing high on M15");
   }
   if (swingLow != NULL){
      latestM15Low = swingLow;
      Print("Formed a swing low on M15");
   }
   if (bullishFVGFormed){
      Print("Formed a bullish FVG on M15");
   }
   if (bearishFVGFormed){
      Print("Formed a bearishFVG FVG on M15");
   }*/
}


//===== H1 On-Close Event =====
void onH1Close(MqlRates &candlesH1[]){
   dolH1 = getBiasAndDOL(candlesH1, biasH1);
   if (biasH1 == BullishBias){
      Print("H1 bias is now Bullish, DOL: ", dolH1);
      executedOrder = false;  // Reset this variable
   }
   else if (biasH1 == BearishBias){
      Print("H1 bias is now Bearish, DOL: ", dolH1);
      executedOrder = false;  // Reset this variable
   }
}


//===== Function to trigger the execution =====
void executeIfReady(MqlTick &currentPrice){
   if (biasH1 == BullishBias && currentPrice.bid < dolH1){
      if (bullishEntryPoint != NULL && currentPrice.bid <= bullishEntryPoint && !executedOrder){
         Print("Triggering a BUY, Entry: ", bullishEntryPoint, ", SL: ", bullishSLPoint);
         executedOrder = true;
      }
   }
   else if (biasH1 == BearishBias && currentPrice.bid > dolH1){
      if (bearishEntryPoint != NULL && currentPrice.bid >= bearishEntryPoint && !executedOrder){
         Print("Triggering a SELL, Entry: ", bearishEntryPoint, ", SL: ", bearishSLPoint);
         executedOrder = true;
      }
   }
   
   
   if (currentPrice.bid < bullishSLPoint){  // The bullish engulfing candle is no longer valid
      bullishEntryPoint = NULL;
      bullishSLPoint = NULL;
   }
   else if (currentPrice.bid > bearishSLPoint){  // The bearish engulfing candle is no longer valid
      bearishEntryPoint = NULL;
      bearishSLPoint = NULL;
   } 
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
