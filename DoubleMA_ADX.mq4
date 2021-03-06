#property copyright "impulse10101"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

extern int Period_MA_1 = 11;
extern int Period_MA_2 = 31;
extern int MAShift = 1;

extern double MADistance = 56;
extern double ADXDistance = 10;
extern int MaxRisk = 2;

extern int TakeProfit = 0;
extern int StopLoss = 0;

extern int TrailStop = 45;
extern int TrailStep = 10;
extern int Magic = 51102;


int OnInit(){
   if (Digits == 3 || Digits == 5) {
      TrailStop *= 10;
      TrailStep *= 10;
   }
   return(INIT_SUCCEEDED);
}
  
void OnDeinit(const int reason){
   
}
  
void OnTick(){

   Trail();

   Trade();
}

// Трейлинг стоп
void Trail() {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == Magic) {
            RefreshRates();
            
            if (OrderType() == OP_BUY) {
               if (Bid - OrderOpenPrice() > TrailStop*Point || OrderStopLoss() == 0) {
                  if (OrderStopLoss() < Bid - (TrailStop + TrailStep) * Point || OrderStopLoss() == 0) {
                     if (!OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(Bid - TrailStop * Point, Digits), 0, 0)) {
                        Print("Ошибка модификации ордера на покупку!");
                     }
                  }
               }
            }
            
            if (OrderType() == OP_SELL) {
               if (OrderOpenPrice() - Ask > TrailStop*Point || OrderStopLoss() == 0) {
                  if (OrderStopLoss() > Ask + (TrailStop + TrailStep) * Point || OrderStopLoss() == 0) {
                     if (!OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(Ask + TrailStop * Point, Digits), 0, 0)) {
                        Print("Ошибка модификации ордера на продажу!");
                     }
                  }
               }
            }
         }
      }
   }
}


// Торговля и всё что с ней связано
void Trade() {

   if (TimeHour(TimeCurrent()) < 10 || TimeHour(TimeCurrent()) > 17) {
      return;
   }
   
   double MA_1_t;
   double MA_2_t;
   double ADX_PLUSDI;
   double ADX_MINUSDI;
   double ADX_MAIN;
   bool Cls_B = false;
   bool Cls_S = false;
   bool Opn_B = false;
   bool Opn_S = false;

   MA_1_t = iMA(Symbol(), PERIOD_H1, Period_MA_1, 0, MODE_LWMA, PRICE_TYPICAL, MAShift); //MA_1
   MA_2_t = iMA(Symbol(), PERIOD_H1, Period_MA_2, 0, MODE_LWMA, PRICE_TYPICAL, MAShift); //MA_2
   ADX_PLUSDI = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
   ADX_MINUSDI = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
   ADX_MAIN = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_MAIN, 0);
   
   if (ADX_MAIN < 30) {
      return;
   }
   
   if ((MA_1_t > MA_2_t + MADistance*Point) && (ADX_PLUSDI > ADX_MINUSDI) && (MathAbs(ADX_PLUSDI - ADX_MINUSDI) > ADXDistance)) {
      Opn_B = true;
   }
   if ((MA_1_t < MA_2_t - MADistance*Point) && (ADX_PLUSDI < ADX_MINUSDI) && (MathAbs(ADX_PLUSDI - ADX_MINUSDI) > ADXDistance)) {
      Opn_S = true;
   }
   
   if(OrdersTotal() > 0) {
      return;
   }
   
   double Lot = GetLot(MaxRisk);
   if (Opn_B) {
      RefreshRates();
      NewOrder(OP_BUY, Lot);
   }
   if (Opn_S) {
      RefreshRates();
      NewOrder(OP_SELL, Lot);
   }
   
}

// Расчёт лота
double GetLot(int Risk) {
   double Free = AccountFreeMargin();
   double One_Lot = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double Min_Lot = MarketInfo(Symbol(), MODE_MINLOT);
   double Max_Lot = MarketInfo(Symbol(), MODE_MAXLOT);
   double Step = MarketInfo(Symbol(), MODE_LOTSTEP);
   double Lot = MathFloor(Free*Risk/100/One_Lot/Step)*Step;
   if(Lot<Min_Lot) {
      Lot = Min_Lot;
   }
   if(Lot>Max_Lot) {
      Lot = Max_Lot;
   }
   return(Lot);
}

// Открытие ордера
int NewOrder(int Cmd, double Lot) {
   double TP = 0;
   double SL = 0;
   double PR = 0;
   while (!IsTradeAllowed()) Sleep(100);
   if (Cmd == OP_BUY) {
      PR = Ask;
      if(TakeProfit>0) TP = Ask+TakeProfit*Point;
      if(StopLoss>0) SL = Ask-StopLoss*Point;
   }
   if (Cmd == OP_SELL){
      PR=Bid;
      if(TakeProfit>0) TP = Bid-TakeProfit*Point;
      if(StopLoss>0) SL = Bid+StopLoss*Point;
   }
   int ticket = OrderSend(Symbol(), Cmd, Lot, PR, 3, SL, TP, "", Magic, 0, CLR_NONE);
   if (ticket < 0) {
      Print("Ошибка открытия ордера: ", GetLastError());
   }
   return(ticket);
}

// Закрытие ордера
void CloseOrder(int type) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderType() == type) {
         double price;
         RefreshRates();
         if (OrderType() == OP_SELL) {
            price = Ask;
         } else {
            price = Bid;
         }
         OrderClose(OrderTicket(), OrderLots(), price, 3);
      }
   }
}