//+------------------------------------------------------------------+
//|                                                        NYR50.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- input parameters
input double risk = 0.05;
input int ESTOffset = -4;
input double tpRatio = 2.5;

//--- Global variables initialization
datetime latestM5Time;
datetime latestH1Time;

//--- Trade-related variables initialization
double rangeHigh;
double rangeLow;
bool isTradingSession = false;
int executionMode;
double entryPoint;
bool alreadyExecutedTrade = false;

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
//---
   
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
void OnTick()
  {
//---
   // Get the latest tick
   MqlTick currentPrice;
   SymbolInfoTick(_Symbol, currentPrice);
   
   // Get M15 candles and time
   MqlRates candlesM5[];
   datetime currentM5Time[1];
   CopyRates(_Symbol, PERIOD_M5, 0, 4, candlesM5);
   CopyTime(_Symbol, PERIOD_M5, 0, 1, currentM5Time);
   
   // Get H1 candles and time
   MqlRates candlesH1[];
   datetime currentH1Time[1];
   CopyRates(_Symbol, PERIOD_H1, 0, 4, candlesH1);
   CopyTime(_Symbol, PERIOD_H1, 0, 1, currentH1Time);
   
   // Calling the on-close events   
   if (latestM5Time != currentM5Time[0]){
      onM5Close(candlesM5);
      latestM5Time = currentM5Time[0];
   }
   if (latestH1Time != currentH1Time[0]){
      onH1Close(candlesH1);
      latestH1Time = currentH1Time[0];
   }
   
   executeIfReady(currentPrice);
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| On-Close Events                                                  |
//+------------------------------------------------------------------+
//===== M5 On-Close Event =====
void onM5Close(MqlRates &candlesM5[]){
   int lastCloseIndex = ArraySize(candlesM5) - 2;
   if (isWithinTradingSession(candlesM5[lastCloseIndex].time)){
      if (!isTradingSession){
         Print("Within Trading Session!");
         isTradingSession = true;
         // Calculate the entry point (the middle of the range)
         entryPoint = (rangeHigh + rangeLow) / 2;
         Print("Range midpoint: ", entryPoint);
      }
      // Check for candle close above range high or below range low
      if (candlesM5[lastCloseIndex].close > rangeHigh){
         if (executionMode == NULL){
            Print("Execution Mode: BUY");
            executionMode = ExecutionModeBuy;
         }
      }
      else if (candlesM5[lastCloseIndex].close < rangeLow){
         if (executionMode == NULL){
            Print("Execution Mode: SELL");
            executionMode = ExecutionModeSell;
         }
      }
   }
   else if (isTradingSession){
      Print("No longer trading session!");
      isTradingSession = false;
      Print("Reseting trading range...");
      rangeHigh = NULL;
      rangeLow = NULL;
      entryPoint = NULL;
      Print("Reseting execution mode...");
      executionMode = NULL;
      alreadyExecutedTrade = false;
   }
}

//===== H1 On-Close Event =====
void onH1Close(MqlRates &candlesH1[]){
   int lastCloseIndex = ArraySize(candlesH1) - 2;
   if (isWithinRangeSession(candlesH1[lastCloseIndex].time)){
      Print("Within range session!");
      if (rangeHigh == NULL || candlesH1[lastCloseIndex].high > rangeHigh){
         rangeHigh = candlesH1[lastCloseIndex].high;
      }
      if (rangeLow == NULL || candlesH1[lastCloseIndex].low < rangeLow){
         rangeLow = candlesH1[lastCloseIndex].low;
      }
   }
   else if (rangeHigh != NULL && rangeLow != NULL){
      Print("Range High: ", rangeHigh, ", Range Low: ", rangeLow);
   }
}


//+------------------------------------------------------------------+
//| Trade-related Functions                                          |
//+------------------------------------------------------------------+
// Function to execute if ready
void executeIfReady(MqlTick &currentPrice){
   if (isTradingSession && entryPoint != NULL && executionMode != NULL && !alreadyExecutedTrade){
      if (executionMode == ExecutionModeBuy && currentPrice.bid <= entryPoint){
         Print("Executing a BUY order");
         openBuyTrade();
         alreadyExecutedTrade = true;
      }
      else if (executionMode == ExecutionModeSell && currentPrice.bid >= entryPoint){
         Print("Executing a SELL order");
         openSellTrade();
         alreadyExecutedTrade = true;
      }
   }
}

//===== Function to place a BUY market order =====
bool openBuyTrade(){
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   double price = tick.ask;
   double slPrice = rangeLow;
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
   double slPrice = rangeHigh + spread;
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
//===== Function to check if we're within the range session (20:00 - 02:00) =====
bool isWithinRangeSession(datetime dt){
   //Print("======================================");
   // Convert dt from server's timezone to GMT/UTC
   datetime dtUTC = dt + serverGMTOffset();
   MqlDateTime dtUTCStruct;
   TimeToStruct(dtUTC, dtUTCStruct);
   //Print("dt: ", dt);
   //Print("dtUTC: ", dtUTC);
   //Print("dtStruct Hour Time: ", dtUTCStruct.hour, " | dtStruct Minute Time: ", dtUTCStruct.min);
   
   // Convert the dt from GMT/UTC to EST
   datetime dtEST = dtUTC + (ESTOffset * 60 * 60);
   MqlDateTime dtESTStruct;
   TimeToStruct(dtEST, dtESTStruct);
   int ESTHour = dtESTStruct.hour;
   //Print("EST: ", dtEST);
   //Print("dtESTStruct Hour Time: ", dtESTStruct.hour, " | dtESTStruct Minute Time: ", dtESTStruct.min);
   
   if (ESTHour == 20 || ESTHour == 21 || ESTHour == 22 || ESTHour == 23 || ESTHour == 0 || ESTHour == 1){
      return true;
   }
   return false;
}

//===== Function to check if we're within the trading session (02:00 - 09:00) =====
bool isWithinTradingSession(datetime dt){
   //Print("======================================");
   // Convert dt from server's timezone to GMT/UTC
   datetime dtUTC = dt + serverGMTOffset();
   MqlDateTime dtUTCStruct;
   TimeToStruct(dtUTC, dtUTCStruct);
   //Print("dt: ", dt);
   //Print("dtUTC: ", dtUTC);
   //Print("dtStruct Hour Time: ", dtUTCStruct.hour, " | dtStruct Minute Time: ", dtUTCStruct.min);
   
   // Convert the dt from GMT/UTC to EST
   datetime dtEST = dtUTC + (ESTOffset * 60 * 60);
   MqlDateTime dtESTStruct;
   TimeToStruct(dtEST, dtESTStruct);
   int ESTHour = dtESTStruct.hour;
   //Print("EST: ", dtEST);
   //Print("dtESTStruct Hour Time: ", dtESTStruct.hour, " | dtESTStruct Minute Time: ", dtESTStruct.min);
   
   if (ESTHour == 2 || ESTHour == 3 || ESTHour == 4 || ESTHour == 5 || ESTHour == 6 || ESTHour == 7 || ESTHour == 8){
      return true;
   }
   return false;
}

//===== Function to get the offset from the server time to GMT time in seconds =====
int serverGMTOffset(){
   datetime serverTime=TimeTradeServer();
   datetime gmtTime=TimeGMT();
   int offsetInSeconds = ((int)serverTime)-((int)gmtTime);
   
   return offsetInSeconds;
}

//===== Function to check if we're in a trade =====
bool isInTrade(){
   if (PositionsTotal() > 0){
      return true;
   }
   return false;
}

//===== Function to get the spread =====
double getSpread(){
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   return spread * _Point;
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