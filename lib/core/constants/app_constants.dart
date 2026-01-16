class AppConstants {
  // App Info
  static const String appName = 'Wallet Manager';
  static const String appVersion = '1.0.0';
  // Wallet Limits
  // Wallet Limits
  static const double newWalletTransactionLimit = 10000.0;
  static const double newWalletMonthlyLimit = 60000.0;

  static const double oldWalletTransactionLimit = 60000.0;
  static const double oldWalletMonthlyLimit = 200000.0;

  static const double registeredStoreTransactionLimit = 60000.0;
  static const double registeredStoreMonthlyLimit = 400000.0;

  // Instapay Limits
  static const double instapayTransactionLimit =
      120000.0; // Replaces daily limit concept
  static const double instapayMonthlyLimit = 400000.0;

  // Trial Duration
  static const int trialDurationDays = 30;
}
