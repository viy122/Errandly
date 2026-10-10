/// Exchange rates for buying coins and withdrawing earned coins.
abstract final class WalletRates {
  static const topUpPesos = 100.0;
  static const topUpCoins = 110.0;
  static const cashOutCoins = 110.0;
  static const cashOutPesos = 80.0;

  static double coinsForTopUp(double pesos) =>
      (pesos * topUpCoins / topUpPesos * 100).round() / 100;

  static double pesosForCashOut(double coins) =>
      (coins * cashOutPesos / cashOutCoins * 100).round() / 100;
}
