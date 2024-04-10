//+------------------------------------------------------------------+
//|                                                      Test_EA.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//--- input parameters
input double risk = 0.05;

//--- Static variables
static int BullishBias = 1;
static int BearishBias = 2;
static int ExecutionModeBuy = 1;
static int ExecutionModeSell = 2;

//--- Global variables intialization
datetime latestM1Time;
datetime latestM15Time;
datetime latestH1Time;
datetime latestH4Time;
int biasH1;
int biasH4;
double latestM15High;
double latestM15Low;
int executionMode;
double freshSwingHighsM1[];
double freshSwingLowsM1[];
double slPoint;
double fvgPoint;
bool readyToExecute = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Print("Starting Zharfan's Test EA...");
//---
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
void OnTick(){
   MqlTick currentPrice;       // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates candlesM1[];          // To be used to store the prices, volumes and spread of each bar
   MqlRates candlesM15[];          // To be used to store the prices, volumes and spread of each bar
   MqlRates candlesH1[];
   MqlRates candlesH4[];
   datetime currentM1Time[1];
   datetime currentM15Time[1];
   datetime currentH1Time[1];
   datetime currentH4Time[1];
   
   SymbolInfoTick(_Symbol, currentPrice);  // Get the latest tick
   
   CopyRates(_Symbol, PERIOD_M1, 0, 4, candlesM1);   // Get the latest 4 candles for M1
   CopyRates(_Symbol, PERIOD_M15, 0, 4, candlesM15);   // Get the latest 4 candles for M15
   CopyRates(_Symbol, PERIOD_H1, 0, 3, candlesH1);   // Get the latest 4 candles for H1
   CopyRates(_Symbol, PERIOD_H4, 0, 3, candlesH4);   // Get the latest 4 candles for H4
   
   CopyTime(_Symbol, PERIOD_M1, 0, 1, currentM1Time);  // Get the latest time for M1
   CopyTime(_Symbol, PERIOD_M15, 0, 1, currentM15Time);  // Get the latest time for M15
   CopyTime(_Symbol, PERIOD_H1, 0, 1, currentH1Time);  // Get the latest time for H1
   CopyTime(_Symbol, PERIOD_H4, 0, 1, currentH4Time);  // Get the latest time for H4
   
   if (latestM1Time != currentM1Time[0]){
      onM1Close(candlesM1);
      latestM1Time = currentM1Time[0];
   }
   if (latestM15Time != currentM15Time[0]){
      onM15Close(candlesM15);
      latestM15Time = currentM15Time[0];
   }
   if (latestH1Time != currentH1Time[0]){
      onH1Close(candlesH1);
      latestH1Time = currentH1Time[0];
   }
   if (latestH4Time != currentH4Time[0]){
      onH4Close(candlesH4);
      latestH4Time = currentH4Time[0];
   }
   
   // Update the execution mode
   updateExecutionMode(currentPrice);
   
   // Execute an order if ready
   executeIfReady(currentPrice);
 }
  
//===== M1 On-Close Event =====
void onM1Close(MqlRates &candlesM1[]){
   double swingHigh = formedSwingHigh(candlesM1);
   double swingLow = formedSwingLow(candlesM1);
   double bullishFVG = formedBullishFVG(candlesM1);
   double bearishFVG = formedBearishFVG(candlesM1);
   
   // Record M1 swing highs/lows
   if (swingHigh != NULL){
      int i = ArraySize(freshSwingHighsM1);
      ArrayResize(freshSwingHighsM1, i+1);
      freshSwingHighsM1[i] = swingHigh;
      if (i >= 30){
         ArrayRemove(freshSwingHighsM1, 0, 1);
      }
      // Print("Formed a swing high on M1");
   }
   if (swingLow != NULL){
      int j = ArraySize(freshSwingLowsM1);
      ArrayResize(freshSwingLowsM1, j+1);
      freshSwingLowsM1[j] = swingLow;
      if (j >= 30){
         ArrayRemove(freshSwingLowsM1, 0, 1);
      }
      // Print("Formed a swing low on M1");
   }
   
   // Record the latest FVG point for entry
   if (executionMode == ExecutionModeBuy && bullishFVG != NULL){
      fvgPoint = bullishFVG;
      slPoint = candlesM1[0].low;
      Print("Formed a Bullish FVG on M1");
   }
   else if (executionMode == ExecutionModeSell && bearishFVG != NULL){
      fvgPoint = bearishFVG;
      slPoint = candlesM1[0].high;
      Print("Formed a Bearish FVG on M1");
   }
   
   // Check for displacement
   int k = ArraySize(candlesM1);
   
   if (hasDisplaced(candlesM1[k-1]) && isWithinSession()){
      readyToExecute = true;
      Print("Displacement occured on M1");
   }
}
 
//===== M15 On-Close Event =====
void onM15Close(MqlRates &candlesM15[]){
   double swingHigh = formedSwingHigh(candlesM15);
   double swingLow = formedSwingLow(candlesM15);
   
   if (swingHigh != NULL){
      latestM15High = swingHigh;
      Print("Formed a swing high on M15");
   }
   if (swingLow != NULL){
      latestM15Low = swingLow;
      Print("Formed a swing low on M15");
   }
}

//===== H1 On-Close Event =====
void onH1Close(MqlRates &candlesH1[]){
   if (candlesH1[1].close > candlesH1[0].high){
      biasH1 = BullishBias;
      Print("H1 bias is Bullish");
   }
   else if (candlesH1[1].close < candlesH1[0].low){
      biasH1 = BearishBias;
      Print("H1 bias is Bearish");
   }
}

//===== H4 On-Close Event =====
void onH4Close(MqlRates &candlesH4[]){
   if (candlesH4[1].close > candlesH4[0].high){
      biasH4 = BullishBias;
      Print("H4 bias is Bullish");
   }
   else if (candlesH4[1].close < candlesH4[0].low){
      biasH4 = BearishBias;
      Print("H4 bias is Bearish");
   }
}

//===== Function to update execution mode =====
void updateExecutionMode(MqlTick &currentPrice){
   // Check if M15 Swing High/Low has been ran
   if (latestM15High != NULL && currentPrice.bid > latestM15High){
      if (executionMode != ExecutionModeSell){
         executionMode = ExecutionModeSell;
         readyToExecute = false;  // Reset this variable
         fvgPoint = NULL;  // Reset this variable
         Print("Execution mode: SELL");
      }
   }
   if (latestM15Low != NULL && currentPrice.bid < latestM15Low){
      if (executionMode != ExecutionModeBuy){
         executionMode = ExecutionModeBuy;
         readyToExecute = false;  // Reset this variable
         fvgPoint = NULL;  // Reset this variable
         Print("Execution mode: BUY");
      }
   }
}

//===== Function to execute an order if ready =====
void executeIfReady(MqlTick &currentPrice){
   if (readyToExecute && isWithinSession()){
      if (executionMode == ExecutionModeBuy && fvgPoint != NULL && PositionsTotal() < 1){
         if (currentPrice.bid <= fvgPoint && biasH1 == BullishBias && biasH4 == BullishBias){
            Print("Attempting to execute a BUY order..");
            openBuyTrade();
         }
      }
      if (executionMode == ExecutionModeSell && fvgPoint != NULL && PositionsTotal() < 1){
         if (currentPrice.bid >= fvgPoint && biasH1 == BearishBias && biasH4 == BearishBias){
            Print("Attempting to execute a SELL order..");
            openSellTrade();
         }
      }
   }
}
  
//===== Function to check if we're within the killzone sessions =====
bool isWithinSession(){
   return true;
   // Get the NY/EST offset from GMT
   int offset;
   if(TimeDaylightSavings() != 0){
      offset = -4;
   }
   else{
      offset = -5;
   }
   
   // Get the time in GMT 
   MqlDateTime UTCNow;
   TimeGMT(UTCNow);
   
   int ESTNowHour = UTCNow.hour + offset;
   
   if (ESTNowHour == 2 || ESTNowHour == 3 || ESTNowHour == 4 || ESTNowHour == 7 || ESTNowHour == 9 || ESTNowHour == 10 || ESTNowHour == 12){
      return true;
   }
   return false;
}
  
//===== Function to check for swing high =====
double formedSwingHigh(MqlRates &candles[]){
   if ((candles[0].high < candles[1].high) && (candles[2].high < candles[1].high)){
      return candles[1].high;
   }
   return NULL;
}
 
//===== Function to check for swing low =====
double formedSwingLow(MqlRates &candles[]){
   if ((candles[0].low > candles[1].low) && (candles[2].low > candles[1].low)){
      return candles[1].low;
   }
   return NULL;
}

//===== Function to check for bullish FVG =====
double formedBullishFVG(MqlRates &candles[]){
   if (candles[0].high < candles[2].low){
      return candles[2].low;
   }
   return NULL;
}
 
//===== Function to check for bearish FVG =====
double formedBearishFVG(MqlRates &candles[]){
   if (candles[0].low > candles[2].high){
      return candles[2].high;
   }
   return NULL;
}

//===== Function to check for displacement =====
bool hasDisplaced(MqlRates &candle){
   bool displaced = false;
   
   if (executionMode ==  ExecutionModeBuy){
      int swingHighsCount = ArraySize(freshSwingHighsM1);
      if (swingHighsCount > 0){
         if (candle.high > freshSwingHighsM1[swingHighsCount-1]){
            if (candle.close > freshSwingHighsM1[swingHighsCount-1]){
               displaced = true;
            }
            ArrayRemove(freshSwingHighsM1, swingHighsCount-1, 1);
         }
      }
   }
   if (executionMode ==  ExecutionModeSell){
      int swingLowsCount = ArraySize(freshSwingLowsM1);
      if (swingLowsCount > 0){
         if (candle.low < freshSwingLowsM1[swingLowsCount-1]){
            if (candle.close < freshSwingLowsM1[swingLowsCount-1]){
               displaced = true;
            }
            ArrayRemove(freshSwingLowsM1, swingLowsCount-1, 1);
         }
      }
   }
   
   return displaced;
}

//===== Function to calculate the lot size needed =====
double calculateLotSize(double price, double slPrice){
   double point = _Point;
   if (_Symbol == "XAUUSD")
      point = 0.01;
   double balance = ACCOUNT_BALANCE;
   
   double lotSize = NormalizeDouble((risk*balance)/(MathAbs(price-slPrice)/point), 2);
   return lotSize;
}

//===== Function to get the spread =====
double getSpread(){
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   return spread * _Point;
}

//===== Function to open a trade =====
bool openTrade(int posType, double price, double slPrice, double tpPrice){
   double lotSize = calculateLotSize(price, slPrice);
   MqlTradeRequest request;
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
   return false;
}


//===== Function to open a BUY trade =====
bool openBuyTrade(){
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   double price = tick.ask;
   double slPrice = slPoint;
   double tpPrice = price + (2 * (price - slPrice));

   bool success = openTrade(ORDER_TYPE_BUY, price, slPrice, tpPrice);
   if (success)
      return true;
   return false;
}


//===== Function to open a SELL trade =====
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
   if (success)
      return true;
   return false;
}

  
 void Buy(){
   MqlTick latestPrice;       // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates mrate1[];          // To be used to store the prices, volumes and spread of each bar
   MqlRates mrate15[];          // To be used to store the prices, volumes and spread of each bar
   
   SymbolInfoTick(_Symbol, latestPrice);  // Get the latest tick
   CopyRates(_Symbol, 1, 0, 3, mrate1);   // Get the latest 3 candles for M1
   CopyRates(_Symbol, 15, 0, 3, mrate15);   // Get the latest 3 candles for M15
   
   
   mrequest.action = TRADE_ACTION_DEAL;                                // immediate order execution
   mrequest.price = NormalizeDouble(latestPrice.ask, _Digits);          // latest ask price
   mrequest.sl = NormalizeDouble(latestPrice.ask-stopLoss*_Point, _Digits); // Stop Loss
   mrequest.tp = NormalizeDouble(latestPrice.ask+takeProfit*_Point, _Digits); // Take Profit
   Print("Buying at price ", mrequest.price);
   // mrequest.sl = mrequest.price-stopLoss; // Stop Loss
   Print("Stop loss is ", mrequest.sl);
   // mrequest.tp = mrequest.price+takeProfit; // Take Profit
   Print("Take profit is ", mrequest.tp);
   mrequest.symbol = SYMBOL;                                         // currency pair
   mrequest.volume = LOTSIZE;                                            // number of lots to trade
   mrequest.type = ORDER_TYPE_BUY;                                     // Buy Order
   //mrequest.type_filling = ORDER_FILLING_FOK;                          // Order execution type
   //mrequest.deviation=100;                                            // Deviation from current price
   //--- send order
   OrderSend(mrequest,mresult);
 }
 
  void Sell(){
   MqlTick latestPrice; // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates mrate[];
   
   SymbolInfoTick(SYMBOL, latestPrice);
   mrequest.action = TRADE_ACTION_DEAL;                                // immediate order execution
   mrequest.price = NormalizeDouble(latestPrice.ask, _Digits);          // latest ask price
   mrequest.sl = NormalizeDouble(latestPrice.bid+stopLoss*_Point, _Digits); // Stop Loss
   mrequest.tp = NormalizeDouble(latestPrice.bid-takeProfit*_Point, _Digits); // Take Profit
   // mrequest.sl = mrequest.price+stopLoss; // Stop Loss
   // mrequest.tp = mrequest.price-takeProfit; // Take Profit
   mrequest.symbol = SYMBOL;                                         // currency pair
   mrequest.volume = LOTSIZE;                                            // number of lots to trade
   mrequest.type = ORDER_TYPE_SELL;                                     // Buy Order
   //mrequest.type_filling = ORDER_FILLING_FOK;                          // Order execution type
   //mrequest.deviation=100;                                            // Deviation from current price
   //--- send order
   OrderSend(mrequest,mresult);
 }
//+------------------------------------------------------------------+
