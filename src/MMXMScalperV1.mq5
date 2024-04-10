//+------------------------------------------------------------------+
//|                                                MMXMScalperV1.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


//--- input parameters
input double risk = 0.05;
input int ESTOffset = -4;
input double minRR = 3;
input int maxChances = 1;
input int maxCandlesAfterFVG = 2;

//--- Global variables initialization
datetime latestM1Time;
datetime latestH1Time;
datetime latestH4Time;
datetime latestD1Time;

//--- Trade-related variables initialization
double bullishFVGs[][5];
double bearishFVGs[][5];
int executionMode;
double freshHighsM1[];
double freshLowsM1[];
bool hasEnteredH1FVG = false;
bool hasMSS = false;
double slPoint;
double tpPoint;
double entryPoint;
bool readyToExecute = false;
int chances = 0;
int biasH4;
int biasD1;
int candlesAfterFVGCount = 0;

//--- Static variables
int ExecutionModeBuy = 1;
int ExecutionModeSell = 2;
int BullishBias = 1;
int BearishBias = 2;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Starting MMXMScalperV1...");
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
   CopyRates(_Symbol, PERIOD_M5, 0, 4, candlesM1);
   CopyTime(_Symbol, PERIOD_M5, 0, 1, currentM1Time);
   
   // Get H1 candles and time
   MqlRates candlesH1[];
   datetime currentH1Time[1];
   CopyRates(_Symbol, PERIOD_H1, 0, 4, candlesH1);
   CopyTime(_Symbol, PERIOD_H1, 0, 1, currentH1Time);
   
   // Get H4 candles and time
   MqlRates candlesH4[];
   datetime currentH4Time[1];
   CopyRates(_Symbol, PERIOD_H4, 0, 4, candlesH4);
   CopyTime(_Symbol, PERIOD_H4, 0, 1, currentH4Time);
   
   // Get D1 candles and time
   MqlRates candlesD1[];
   datetime currentD1Time[1];
   CopyRates(_Symbol, PERIOD_D1, 0, 4, candlesD1);
   CopyTime(_Symbol, PERIOD_D1, 0, 1, currentD1Time);
   
   // Calling the on-close events   
   if (latestM1Time != currentM1Time[0]){
      onM1Close(candlesM1);
      latestM1Time = currentM1Time[0];
   }
   if (latestH1Time != currentH1Time[0]){
      onH1Close(candlesH1);
      latestH1Time = currentH1Time[0];
   }
   if (latestH4Time != currentH4Time[0]){
      onH4Close(candlesH4);
      latestH4Time = currentH4Time[0];
   }
   if (latestD1Time != currentD1Time[0]){
      onD1Close(candlesD1);
      latestD1Time = currentD1Time[0];
   }
   
   // Call necessary events
   updateExecutionMode(currentPrice);
   checkH1FVGEntered(currentPrice);
   checkM1MSS(currentPrice);
   updateTPPoint(currentPrice);
   updateSLPoint(currentPrice);
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
   double bullishFVG[5];
   double bearishFVG[5];
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
   
   if (bullishFVGFormed && executionMode == ExecutionModeBuy && !isInBuyTrade() && hasEnteredH1FVG){
      entryPoint = bullishFVG[0];
      Print("Formed a bullish FVG on M1. Entry point is now ", entryPoint);
   }
   if (bearishFVGFormed && executionMode == ExecutionModeSell && !isInSellTrade() && hasEnteredH1FVG){
      entryPoint = bearishFVG[0];
      Print("Formed a bearishFVG FVG on M1. Entry point is now ", entryPoint);
   }
}

//===== H1 On-Close Event =====
void onH1Close(MqlRates &candlesH1[]){
   // Check for FVGs formation
   double bullishFVG[5];
   double bearishFVG[5];
   bool bullishFVGFormed = formedBullishFVG(candlesH1, bullishFVG);
   bool bearishFVGFormed = formedBearishFVG(candlesH1, bearishFVG);
   
   // Check for engulfing formation
   double bullishEngulfing[2];
   double bearishEngulfing[2];
   bool bullishEngulfingFormed = formedBullishEngulfing(candlesH1, bullishEngulfing);
   bool bearishEngulfingFormed = formedBearishEngulfing(candlesH1, bearishEngulfing);
   
   if (bullishFVGFormed){
      Print("Formed a bullish FVG on H1");
      ArrayFree(bearishFVGs);  // Clear out the bearish FVGs
      
      int i = ArraySize(bullishFVGs);
      ArrayResize(bullishFVGs, i+1);
      bullishFVGs[i][0] = bullishFVG[0];
      bullishFVGs[i][1] = bullishFVG[1];
      bullishFVGs[i][2] = bullishFVG[2];
      bullishFVGs[i][3] = bullishFVG[3];
      bullishFVGs[i][4] = bullishFVG[4];
      tpPoint = bullishFVG[4];
      candlesAfterFVGCount = 0;
   }
   if (bearishFVGFormed){
      Print("Formed a bearishFVG FVG on H1");
      ArrayFree(bullishFVGs);  // Clear out the bullish FVGs
      
      int i = ArraySize(bearishFVGs);
      ArrayResize(bearishFVGs, i+1);
      bearishFVGs[i][0] = bearishFVG[0];
      bearishFVGs[i][1] = bearishFVG[1];
      bearishFVGs[i][2] = bearishFVG[2];
      bearishFVGs[i][3] = bearishFVG[3];
      bearishFVGs[i][4] = bearishFVG[4];
      tpPoint = bearishFVG[4];
      candlesAfterFVGCount = 0;
   }
   
   if (bullishEngulfingFormed){
      Print("Formed a Bullish Engulfing on H1");
      ArrayFree(bearishFVGs);  // Clear out the bearish FVGs
   }
   if (bearishEngulfingFormed){
      Print("Formed a Bearish Engulfing on H1");
      ArrayFree(bullishFVGs);  // Clear out the bullish FVGs
   }
   
   if (ArraySize(bullishFVGs) > 0 || ArraySize(bearishFVGs) > 0){
      candlesAfterFVGCount++;
   }
}

//===== H4 On-Close Event =====
void onH4Close(MqlRates &candlesH4[]){
   // Update the H4 bias
   double dolH4 = getBiasAndDOL(candlesH4, biasH4);
}

//===== D1 On-Close Event =====
void onD1Close(MqlRates &candlesD1[]){
   // Update the H4 bias
   double dolD1 = getBiasAndDOL(candlesD1, biasD1);
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
      levels[3] = candles[s-4].low;  // FVG SL point
      levels[4] = candles[s-2].high > candles[s-3].high ? candles[s-2].high : candles[s-3].high;  // FVG TP point
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
      levels[3] = candles[s-4].high;  // FVG SL point
      levels[4] = candles[s-2].low < candles[s-3].low ? candles[s-2].low : candles[s-3].low;  // FVG TP point
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

//===== Function to check if we're within the killzone sessions =====
bool isWithinSession(){   
   return true;
   // Get the time in GMT 
   MqlDateTime UTCNow;
   TimeGMT(UTCNow);
   
   int ESTNowHour = UTCNow.hour + ESTOffset;
   
   if (ESTNowHour == 10 || ESTNowHour == 11 || ESTNowHour == 13 || ESTNowHour == 14){
   //if (ESTNowHour == 13 || ESTNowHour == 14){
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

//===== Function to check if we're in a BUY trade =====
bool isInBuyTrade(){
   for (int i=0; i<PositionsTotal(); i++){
      PositionGetTicket(i);
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
         return true;
      }
   }
   return false;
}

//===== Function to check if we're in a SELL trade =====
bool isInSellTrade(){
   for (int i=0; i<PositionsTotal(); i++){
      PositionGetTicket(i);
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
         return true;
      }
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

//===== Function to get an entry point with a specified RR =====
double getEntryPrice(double slPrice, double tpPrice, double minimumRR){
   double entryPrice = ((minimumRR * slPrice) + tpPrice) / (minimumRR + 1);
   return entryPrice;
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
//| Trade-related Functions                                          |
//+------------------------------------------------------------------+
//===== Function to update the execution mode =====
void updateExecutionMode(MqlTick &currentPrice){
   int bullishFVGsCount = ArrayRange(bullishFVGs, 0);
   int bearishFVGsCount = ArrayRange(bearishFVGs, 0);
   
   if (bullishFVGsCount > 0){
      if (executionMode != ExecutionModeBuy){
         Print("Execution mode: BUY");
         executionMode = ExecutionModeBuy;
         hasEnteredH1FVG = false;  // Reset this checklist
         entryPoint = NULL;  // Reset the entry point
         chances = 0;  // Reset the chances count
      }
   }
   else if (bearishFVGsCount > 0){
      if (executionMode != ExecutionModeSell){
         Print("Execution mode: SELL");
         executionMode = ExecutionModeSell;
         hasEnteredH1FVG = false;  // Reset this checklist
         entryPoint = NULL;  // Reset the entry point
         chances = 0;  // Reset the chances count
      }
   }
   else{
      if (executionMode != NULL){
         Print("Execution mode: NULL");
         executionMode = NULL;
         hasEnteredH1FVG = false;  // Reset this checklist
         entryPoint = NULL;  // Reset the entry point
         chances = 0;  // Reset the chances count
      }
   }
   
   if (hasEnteredH1FVG){
      if (tpPoint != NULL){
         if (executionMode == ExecutionModeBuy && currentPrice.bid > tpPoint){
            Print("Reached Buy TP! Clearing Bullish FVGs");
            ArrayFree(bullishFVGs);
         }
         else if (executionMode == ExecutionModeSell && currentPrice.bid < tpPoint){
            Print("Reached Sell TP! Clearing Bearish FVGs");
            ArrayFree(bearishFVGs);
         }
      }
   }
}

//===== Function to check whether price has entered a H1 FVG =====
void checkH1FVGEntered(MqlTick &currentPrice){
   int bullishFVGsCount = ArrayRange(bullishFVGs, 0);
   int bearishFVGsCount = ArrayRange(bearishFVGs, 0);
   
   if (executionMode == ExecutionModeBuy){
      for (int i=bullishFVGsCount-1; i>-1; i--){
         if (currentPrice.bid < bullishFVGs[i][0] && currentPrice.bid > bullishFVGs[i][3]){
            if (!hasEnteredH1FVG){
               Print("Entered a Bullish H1 FVG. TP is: ", tpPoint);
               hasEnteredH1FVG = true;
            }
            break;
         }
         else if (i == 0 && currentPrice.bid < bullishFVGs[i][3]){
            if (hasEnteredH1FVG){
               Print("All bullish FVGs broken");
               hasEnteredH1FVG = false;
            }
            ArrayFree(bullishFVGs);
         }
      }
   }
   if (bearishFVGsCount > 0){
      for (int i=bearishFVGsCount-1; i>-1; i--){
         if (currentPrice.bid > bearishFVGs[i][0] && currentPrice.bid < bearishFVGs[i][3]){
            if (!hasEnteredH1FVG){
               Print("Entered a Bearish H1 FVG. TP is: ", tpPoint);
               hasEnteredH1FVG = true;
            }
            break;
         }
         else if (i == 0 && currentPrice.bid > bearishFVGs[i][3]){
            if (hasEnteredH1FVG){
               Print("All bearish FVGs broken");
               hasEnteredH1FVG = false;
            }
            ArrayFree(bearishFVGs);
         }
      }
   }
}

//===== Function to check if price has displaced by candle close =====
void checkM1MSS(MqlTick &currentPrice){
   if (hasEnteredH1FVG){
      if (executionMode == ExecutionModeBuy){
         int freshHighsCount = ArraySize(freshHighsM1);
         if (freshHighsCount > 0){
            if (currentPrice.bid > freshHighsM1[freshHighsCount-1]){
               if (!hasMSS){
                  Print("Bullish M1 MSS occured");
                  hasMSS = true;
               }
               ArrayRemove(freshHighsM1, freshHighsCount-1, 1);
            }
         }
      }
      else if (executionMode == ExecutionModeSell){
         int freshLowsCount = ArraySize(freshLowsM1);
         //Print("Fresh lows count: ", freshLowsCount);
         if (freshLowsCount > 0){
            if (currentPrice.bid < freshLowsM1[freshLowsCount-1]){
               if (!hasMSS){
                  Print("Bearish M1 MSS occured");
                  hasMSS = true;
               }
               ArrayRemove(freshLowsM1, freshLowsCount-1, 1);
            }
         }
      }
   }
   else{
      hasMSS = false;
   }
}

//===== Function to update the TP point =====
void updateTPPoint(MqlTick &currentPrice){
   if (executionMode == ExecutionModeBuy){
      if (tpPoint == NULL){
         tpPoint = currentPrice.bid;
      }
      else if (currentPrice.bid > tpPoint){
         tpPoint = currentPrice.bid;
      }
   }
   else if (executionMode == ExecutionModeSell){
      if (tpPoint == NULL){
         tpPoint = currentPrice.bid;
      }
      else if (currentPrice.bid < tpPoint){
         tpPoint = currentPrice.bid;
      }
   }
   else{
      tpPoint = NULL;
   }
}

//===== Function to update the SL point =====
void updateSLPoint(MqlTick &currentPrice){
   if (hasEnteredH1FVG){
      if (executionMode == ExecutionModeBuy){
         if (slPoint == NULL){
            slPoint = currentPrice.bid;
         }
         else if (currentPrice.bid < slPoint){
            slPoint = currentPrice.bid;
            entryPoint = NULL;  // The previous entry point would be invalid
            hasMSS = false;  // The previous MSS would be invalid
         }
      }
      else if (executionMode == ExecutionModeSell){
         if (slPoint == NULL){
            slPoint = currentPrice.bid;
         }
         else if (currentPrice.bid > slPoint){
            slPoint = currentPrice.bid;
            entryPoint = NULL;  // The previous entry point would be invalid
            hasMSS = false;  // The previous MSS would be invalid
         }
      }
   }
   else{
      slPoint = NULL;
   }
}

//===== Function to execute if ready =====
void executeIfReady(MqlTick &currentPrice){
   if (hasEnteredH1FVG && hasMSS && isWithinSession() && slPoint != NULL && tpPoint != NULL && entryPoint != NULL){
      if (executionMode == ExecutionModeBuy){
         if (!isInBuyTrade() && chances < maxChances && candlesAfterFVGCount <= maxCandlesAfterFVG && biasH4 == BullishBias){
            double currentRR = (tpPoint - entryPoint) / (entryPoint - slPoint);
            entryPoint = currentRR >= minRR ? entryPoint : getEntryPrice(slPoint, tpPoint, minRR);  // Refine the entry point
            if (currentPrice.bid <= entryPoint){
               openBuyTrade();
               chances++;
            }
         }
      }
      else if (executionMode == ExecutionModeSell){
         if (!isInSellTrade() && chances < maxChances && candlesAfterFVGCount <= maxCandlesAfterFVG && biasH4 == BearishBias){
            double currentRR = (entryPoint - tpPoint) / (slPoint - entryPoint);
            entryPoint = currentRR >= minRR ? entryPoint : getEntryPrice(slPoint, tpPoint, minRR);  // Refine the entry point
            if (currentPrice.bid >= entryPoint){
               openSellTrade();
               chances++;
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
   //bool success = openTrade(ORDER_TYPE_SELL, price, tpPrice, slPrice);
   if (success){
      // alreadyExecutedBuy = true;
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
   double slPrice = slPoint + spread;
   double tpPrice = tpPoint + spread;

   bool success = openTrade(ORDER_TYPE_SELL, price, slPrice, tpPrice);
   //bool success = openTrade(ORDER_TYPE_BUY, price, tpPrice, slPrice);
   if (success){
      // alreadyExecutedSell = true;
      return true;
   }
   return false;
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