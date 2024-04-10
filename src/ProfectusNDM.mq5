//+------------------------------------------------------------------+
//|                                                 ProfectusNDM.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- input parameters
input double risk = 0.05;
input int ESTOffset = -4;
input double targetRatio = 3;
input double slPercentage = 0.3;
input double tpRatio = 4;

//--- Global variables initialization
datetime latestM15Time;
datetime latestH1Time;
datetime latestD1Time;

//--- Trade-related variables initialization
double bullishFVGs[][5];
double bearishFVGs[][5];
double freshHighsH1[];
double freshLowsH1[];
double freshHighsD1[];
double freshLowsD1[];
int biasD1;
int executionMode;
bool hasRunSwingPointD1 = false;
int nextCandleCountD1 = 0;
bool isNextDay = false;
bool hasBrokenStructureH1 = false;
double entryPoint;
bool readyToExecute = false;
bool alreadyOpenedTrade = false;

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
   Print("Starting ProfectusNDM...");
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
   
   // Get D1 candles and time
   MqlRates candlesD1[];
   datetime currentD1Time[1];
   CopyRates(_Symbol, PERIOD_D1, 0, 4, candlesD1);
   CopyTime(_Symbol, PERIOD_D1, 0, 1, currentD1Time);
  
   // Calling the on-close events   
   if (latestM15Time != currentM15Time[0]){
      onM15Close(candlesM15);
      latestM15Time = currentM15Time[0];
   }
   if (latestH1Time != currentH1Time[0]){
      onH1Close(candlesH1);
      latestH1Time = currentH1Time[0];
   }
   if (latestD1Time != currentD1Time[0]){
      onD1Close(candlesD1);
      latestD1Time = currentD1Time[0];
   }
   
   // Call necessary trading functions
   checkIsNextDay(currentPrice);
   checkBOSH1(currentPrice);
   executeIfReady(currentPrice);
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| On-Close Events                                                  |
//+------------------------------------------------------------------+
//===== M15 On-Close Event =====
void onM15Close(MqlRates &candlesM15[]){
   // Check for FVGs formation
   double bullishFVG[5];
   double bearishFVG[5];
   bool bullishFVGFormed = formedBullishFVG(candlesM15, bullishFVG);
   bool bearishFVGFormed = formedBearishFVG(candlesM15, bearishFVG);
   
   if (bullishFVGFormed && isWithinSession()){
      if (isNextDay && hasBrokenStructureH1 && biasD1 == BullishBias){
         entryPoint = bullishFVG[0];
         Print("M15 FVG formed");
      }
   }
   if (bearishFVGFormed && isWithinSession()){
      if (isNextDay && hasBrokenStructureH1 && biasD1 == BearishBias){
         entryPoint = bearishFVG[0];
         Print("M15 FVG formed");
      }
   }
}

//===== H1 On-Close Event =====
void onH1Close(MqlRates &candlesH1[]){
   // Check for swing highs/lows formation
   double swingHigh = formedSwingHigh(candlesH1);
   double swingLow = formedSwingLow(candlesH1);
   
   // Record H1 swing highs/lows
   if (swingHigh != NULL){
      int i = ArraySize(freshHighsH1);
      ArrayResize(freshHighsH1, i+1);
      freshHighsH1[i] = swingHigh;
      if (i >= 30){
         ArrayRemove(freshHighsH1, 0, 1);
      }
      // Print("Formed a swing high on H1");
   }
   if (swingLow != NULL){
      int j = ArraySize(freshLowsH1);
      ArrayResize(freshLowsH1, j+1);
      freshLowsH1[j] = swingLow;
      if (j >= 30){
         ArrayRemove(freshLowsH1, 0, 1);
      }
      // Print("Formed a swing low on H1");
   }
}

//===== D1 On-Close Event =====
void onD1Close(MqlRates &candlesD1[]){   
   // Reset some trading conditions
   hasBrokenStructureH1 = false;
   alreadyOpenedTrade = false;
   entryPoint = false;

   // Check if the candle has run a high or a low
   int highsCountD1 = ArraySize(freshHighsD1);
   if (highsCountD1 > 0){
      if (candlesD1[ArraySize(candlesD1)-2].high > freshHighsD1[highsCountD1-1]){
         hasRunSwingPointD1 = true;
         biasD1 = BearishBias;
         ArrayRemove(freshHighsD1, highsCountD1-1, 1);
         Print("Ran a D1 swing high");
      }
   }
   int lowsCountD1 = ArraySize(freshLowsD1);
   if (lowsCountD1 > 0){
      if (candlesD1[ArraySize(candlesD1)-2].low < freshLowsD1[lowsCountD1-1]){
         hasRunSwingPointD1 = true;
         biasD1 = BullishBias;
         ArrayRemove(freshLowsD1, lowsCountD1-1, 1);
         Print("Ran a D1 swing low");
      }
   }
   
   // Check next days count
   if (isNextDay){
      isNextDay = false;
      Print("Next day: ", isNextDay);
   }
   
   // Check for swing highs/lows formation
   double swingHigh = formedSwingHigh(candlesD1);
   double swingLow = formedSwingLow(candlesD1);
   
   // Record D1 swing highs/lows
   if (swingHigh != NULL){
      int i = ArraySize(freshHighsD1);
      ArrayResize(freshHighsD1, i+1);
      freshHighsD1[i] = swingHigh;
      if (i >= 30){
         ArrayRemove(freshHighsD1, 0, 1);
      }
      Print("Formed a swing high on D1");
   }
   if (swingLow != NULL){
      int j = ArraySize(freshLowsD1);
      ArrayResize(freshLowsD1, j+1);
      freshLowsD1[j] = swingLow;
      if (j >= 30){
         ArrayRemove(freshLowsD1, 0, 1);
      }
      Print("Formed a swing low on D1");
   }
}


//+------------------------------------------------------------------+
//| Trade-related Functions                                          |
//+------------------------------------------------------------------+
void checkIsNextDay(MqlTick &currentPrice){
   // Check whether it's the next day
   if (hasRunSwingPointD1){
      hasRunSwingPointD1 = false;
      
      isNextDay = true;
      Print("Next day: ", isNextDay);
   }
}

void checkBOSH1(MqlTick &currentPrice){
   int highsCountH1 = ArraySize(freshHighsH1);
   if (highsCountH1 > 0){
      if (currentPrice.bid > freshHighsH1[highsCountH1-1]){
         ArrayRemove(freshHighsH1, highsCountH1-1, 1);
         if (isNextDay && biasD1 == BullishBias){
            if (!hasBrokenStructureH1){
               hasBrokenStructureH1 = true;
               Print("Broke structure high on H1");
            }
         }
      }
   }
   
   int lowsCountH1 = ArraySize(freshLowsH1);
   if (lowsCountH1 > 0){
      if (currentPrice.bid < freshLowsH1[lowsCountH1-1]){
         ArrayRemove(freshLowsH1, lowsCountH1-1, 1);
         if (isNextDay && biasD1 == BearishBias){
            if (!hasBrokenStructureH1){
               hasBrokenStructureH1 = true;
               Print("Broke structure low on H1");
            }
         }
      }
   }
}

void executeIfReady(MqlTick &currentPrice){
   if (biasD1 == BullishBias && hasBrokenStructureH1 && entryPoint != NULL && !isInTrade()){
      if (currentPrice.bid <= entryPoint){
         Print("Opening a BUY trade...");
         openBuyTrade();
         alreadyOpenedTrade = true;
      }
   }
   else if (biasD1 == BearishBias && hasBrokenStructureH1 && entryPoint != NULL && !isInTrade()){
      if (currentPrice.bid >= entryPoint){
         Print("Opening a SELL trade...");
         openSellTrade();
         alreadyOpenedTrade = true;
      }
   }
}

//===== Function to place a BUY market order =====
bool openBuyTrade(){
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   double price = tick.ask;
   double slPrice = price - (price * slPercentage / 100);
   double tpPrice = price + (tpRatio * (price - slPrice));

   bool success = openTrade(ORDER_TYPE_BUY, price, slPrice, tpPrice, risk);
   if (success){
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
   double slPrice = price + (price * slPercentage / 100) + spread;
   double tpPrice = price - (tpRatio * (slPrice - price)) + spread;

   bool success = openTrade(ORDER_TYPE_SELL, price, slPrice, tpPrice, risk);
   if (success){
      return true;
   }
   return false;
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

//===== Function to check if we're within the killzone sessions =====
bool isWithinSession(){   
   //return true;
   // Get the time in GMT 
   MqlDateTime UTCNow;
   TimeGMT(UTCNow);
   
   int ESTNowHour = UTCNow.hour + ESTOffset;
   
   if (ESTNowHour == 8 || ESTNowHour == 9 || ESTNowHour == 10 || ESTNowHour == 11){
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
   
   /*Print("risk percentage: ", riskPercentage);
   Print("balance: ", balance);
   Print("price: ", price);
   Print("sl price: ", slPrice);
   Print("point: ", point);*/
   double lotSize = NormalizeDouble((riskPercentage*balance)/(MathAbs(price-slPrice)/point), 2);
   return lotSize;
}

//===== Function to get the spread =====
double getSpread(){
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   return spread * _Point;
}

//===== Function to place a market order =====
bool openTrade(int posType, double price, double slPrice, double tpPrice, double riskPercentage){
   double lotSize = calculateLotSize(riskPercentage, price, slPrice);
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

//===== Function to check if we're in a trade =====
bool isInTrade(){
   if (PositionsTotal() > 0){
      return true;
   }
   return false;
}