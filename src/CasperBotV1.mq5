//+------------------------------------------------------------------+
//|                                                  CasperBotV1.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


//--- input parameters
input double risk = 0.05;
input int ESTOffset = -4;
input bool allowHedging = false;
input bool allowSecondChance = false;


//--- Global variables intialization
datetime latestM1Time;
datetime latestM15Time;
double latestM15High;
double latestM15Low;
datetime latestM15HighTime;
datetime latestM15LowTime;

bool readyToExecute = false;
int executionMode;
double slPoint;
datetime slPointTime;
double freshHighsM1[];
double freshLowsM1[];
double fvgPoint;
bool alreadyExecutedBuy = false;
bool alreadyExecutedSell = false;


//--- Static variables
static int BullishBias = 1;
static int BearishBias = 2;
static int ExecutionModeBuy = 1;
static int ExecutionModeSell = 2;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Starting CasperBotV1...");
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
   
   updateExecutionMode(currentPrice);
   updateSLPoint(currentPrice, currentPrice.time);
   executeIfReady(currentPrice);
  }
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| On-Close Events                                                  |
//+------------------------------------------------------------------+
//===== M1 On-Close Event =====
void onM1Close(MqlRates &candlesM1[]){
   // Check for swing highs/lows formation
   double swingHigh = formedSwingHigh(candlesM1);
   double swingLow = formedSwingLow(candlesM1);

   // Check for FVGs formation
   double bullishFVG[3];
   double bearishFVG[3];
   bool bullishFVGFormed = formedBullishFVG(candlesM1, bullishFVG);
   bool bearishFVGFormed = formedBearishFVG(candlesM1, bearishFVG);
   
   // Record M1 swing highs/lows
   if (swingHigh != NULL){
      int i = ArraySize(freshHighsM1);
      ArrayResize(freshHighsM1, i+1);
      freshHighsM1[i] = swingHigh;
      if (i >= 30){
         ArrayRemove(freshHighsM1, 0, 1);
      }
      // Print("Formed a swing high on M1");
   }
   if (swingLow != NULL){
      int j = ArraySize(freshLowsM1);
      ArrayResize(freshLowsM1, j+1);
      freshLowsM1[j] = swingLow;
      if (j >= 30){
         ArrayRemove(freshLowsM1, 0, 1);
      }
      // Print("Formed a swing low on M1");
   }
   
   if (bullishFVGFormed){
      // Print("Formed a bullish FVG on M1");
      fvgPoint = bullishFVG[0];
   }
   if (bearishFVGFormed){
      // Print("Formed a bearishFVG FVG on M1");
      fvgPoint = bearishFVG[0];
   }
   
   MqlRates latestM1Candle = candlesM1[ArraySize(candlesM1)-1];
   if (hasCloseDisplaced(latestM1Candle) && isWithinSession()){
      Print("Displacement occured on M1");
      readyToExecute = true;
      Print("Ready to execute: ", readyToExecute);
   }
}


//===== M15 On-Close Event =====
void onM15Close(MqlRates &candlesM15[]){
   // Check for swing highs/lows formation
   double swingHigh = formedSwingHigh(candlesM15);
   double swingLow = formedSwingLow(candlesM15);
   
   if (swingHigh != NULL){
      latestM15High = swingHigh;
      latestM15HighTime = candlesM15[ArraySize(candlesM15)-1].time;
      // Print("Formed a swing high on M15");
   }
   if (swingLow != NULL){
      latestM15Low = swingLow;
      latestM15LowTime = candlesM15[ArraySize(candlesM15)-1].time;
      // Print("Formed a swing low on M15");
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

//===== Function to check if we're in a trade =====
bool isInTrade(){
   if (PositionsTotal() > 0){
      return true;
   }
   return false;
}

//===== Function to calculate lot size =====
double calculateLotSize(double riskPercentage, double price, double slPrice){
   double point = _Point;
   if (_Symbol == "XAUUSD")
      point = 0.01;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   double lotSize = NormalizeDouble((riskPercentage*balance)/(MathAbs(price-slPrice)/point), 2);
   return lotSize;
}

//===== Function to get the spread =====
double getSpread(){
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   return spread * _Point;
}

//===== Function to place a market order =====
bool openTrade(int posType, double price, double slPrice, double tpPrice){
   double lotSize = calculateLotSize(risk, price, slPrice);
   MqlTradeRequest request;
   ZeroMemory(request);
   MqlTradeResult result;
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = posType;
   request.price = price;
   request.sl = slPrice;
   request.tp = tpPrice;
   
   Print(request.symbol);
   Print(request.volume);
   Print(request.price);
   Print(request.sl);
   Print(request.tp);
   
   bool success = OrderSend(request, result);
   if (success)
      return true;
   else
      Print("Order retcode: ", result.retcode);
   return false;
}


//+------------------------------------------------------------------+
//| Other Functions                                                  |
//+------------------------------------------------------------------+
//===== Function to reset all the necessary variables after making a trade =====
void resetChecklist(){
   readyToExecute = false;
   executionMode = NULL;
   slPoint = NULL;
   slPointTime = NULL;
   ArrayFree(freshHighsM1);
   ArrayFree(freshLowsM1);
   fvgPoint = NULL;
}

//===== Function to update the execution mode =====
void updateExecutionMode(MqlTick &currentPrice){
   if (latestM15High != NULL && currentPrice.bid > latestM15High){
      executionMode = ExecutionModeSell;
      ArrayFree(freshHighsM1);
      alreadyExecutedBuy = false;
      /*Print("M15 high taken out");
      Print("Execution mode is ", executionMode);
      Print("Fresh highs M1 count: ", ArraySize(freshHighsM1));*/
   }
   else if (latestM15Low != NULL && currentPrice.bid < latestM15Low){
      executionMode = ExecutionModeBuy;
      ArrayFree(freshLowsM1);
      alreadyExecutedSell = false;
      /*Print("M15 low taken out");
      Print("Execution mode is ", executionMode);
      Print("Fresh lows M1 count: ", ArraySize(freshLowsM1));*/
   }
}

//===== Function to update the SL point =====
void updateSLPoint(MqlTick &currentPrice, datetime currentTime){
   if (executionMode == ExecutionModeBuy){
      if (slPointTime != NULL && slPointTime < latestM15LowTime){
         if (currentPrice.bid < latestM15Low){
            slPoint = currentPrice.bid;
            slPointTime = latestM15LowTime;
            // Print("Updated SL Point with BUY MODE: ", slPoint);
         }
      }
      if (slPoint == NULL || currentPrice.bid < slPoint){
         slPoint = currentPrice.bid;
         slPointTime = currentPrice.time;
         fvgPoint = NULL;  // Existing FVG no longer valid
         readyToExecute = false;  // Previous displacement no longer counts
         if (allowSecondChance){
            alreadyExecutedBuy = false;  // Allow entry again
         }
         // Print("Updated SL Point with BUY MODE: ", slPoint);
      }
   }
   
   else if (executionMode == ExecutionModeSell){
      if (slPointTime != NULL && slPointTime > latestM15HighTime){
         if (currentPrice.bid > latestM15High){
            slPoint = currentPrice.bid;
            slPointTime = latestM15HighTime;
            // Print("Updated SL Point with SELL MODE: ", slPoint);
         }
      }
      if (slPoint == NULL || currentPrice.bid > slPoint){
         slPoint = currentPrice.bid;
         slPointTime = currentPrice.time;
         fvgPoint = NULL;  // Existing FVG no longer valid
         readyToExecute = false;  // Previous displacement no longer counts
         if (allowSecondChance){
            alreadyExecutedSell = false;  // Allow entry again
         }
         // Print("Updated SL Point with SELL MODE: ", slPoint);
      }
   }
}


//===== Function to execute if ready =====
void executeIfReady(MqlTick &currentPrice){
   if (readyToExecute && isWithinSession()){
      // Print("Ready to execute and within session!");
      if (executionMode == ExecutionModeBuy && !alreadyExecutedBuy){
         // Print("Ready to execute a BUY position");
         Print(fvgPoint);
         Print(currentPrice.bid);
         if (fvgPoint != NULL){
            if (currentPrice.bid <= fvgPoint){
               if (!allowHedging){
                  if (!isInTrade()){
                     Print("Opening a BUY trade");  // BUY HERE
                     openBuyTrade();
                     resetChecklist();
                  }
               }
               else{
                  Print("Opening a BUY trade");  // BUY HERE
                  openBuyTrade();
                  resetChecklist();
               }
            }
         }
      }
      else if (executionMode == ExecutionModeSell && !alreadyExecutedSell){
         Print("Ready to execute a SELL position");
         Print(fvgPoint);
         Print(currentPrice.bid);
         if (fvgPoint != NULL){
            if (currentPrice.bid >= fvgPoint){
               if (!allowHedging){
                  if (!isInTrade()){
                     Print("Opening a SELL trade");  // BUY HERE
                     openSellTrade();
                     resetChecklist();
                  }
               }
               else{
                  Print("Opening a SELL trade");  // BUY HERE
                  openSellTrade();
                  resetChecklist();
               }
            }
         }
      }
   }
}


//===== Function to place a BUY market order =====
bool openBuyTrade(){
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   double price = tick.ask;
   double slPrice = slPoint;
   double tpPrice = price + (2 * (price - slPrice));

   bool success = openTrade(ORDER_TYPE_BUY, price, slPrice, tpPrice);
   if (success){
      alreadyExecutedBuy = true;
      return true;
   }
   return false;
}

//===== Function to place a SELL market order =====
bool openSellTrade(){
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   double price = tick.bid;
   double spread = getSpread();
   Print("Spread down here");
   Print(spread);
   double slPrice = slPoint + spread;
   double tpPrice = price - (2 * (slPrice - price));

   bool success = openTrade(ORDER_TYPE_SELL, price, slPrice, tpPrice);
   if (success){
      alreadyExecutedSell = true;
      return true;
   }
   return false;
}

//===== Function to check if price has displaced by candle close =====
bool hasCloseDisplaced(MqlRates &candle){
   bool displaced = false;
   if (executionMode == ExecutionModeBuy){
      int freshHighsCount = ArraySize(freshHighsM1);
      if (freshHighsCount > 0){
         if (candle.high > freshHighsM1[freshHighsCount-1]){
            if (candle.close > freshHighsM1[freshHighsCount-1]){
               displaced = true;
            }
            ArrayRemove(freshHighsM1, freshHighsCount-1, 1);
         }
      }
   }
   else if (executionMode == ExecutionModeSell){
      int freshLowsCount = ArraySize(freshLowsM1);
      if (freshLowsCount > 0){
         if (candle.low > freshLowsM1[freshLowsCount-1]){
            if (candle.close > freshLowsM1[freshLowsCount-1]){
               displaced = true;
            }
            ArrayRemove(freshLowsM1, freshLowsCount-1, 1);
         }
      }
   }
   return displaced;
}
