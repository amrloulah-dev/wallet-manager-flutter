class FeeCalculator {
  // Network Prefixes
  static const List<String> vodafonePrefixes = ['010'];
  static const List<String> etisalatPrefixes = ['011'];
  static const List<String> orangePrefixes = ['012'];
  static const List<String> wePrefixes = ['015'];

  // Wallet Types
  static const String walletVodafone = 'vodafone_cash';
  static const String walletEtisalat = 'etisalat_cash';
  static const String walletOrange = 'orange_cash';
  static const String walletInstaPay = 'instapay';

  /// Identifies the network provider based on the phone number prefix.
  static String identifyProvider(String phone) {
    if (phone.length < 3) return 'Unknown';
    final prefix = phone.substring(0, 3);

    if (vodafonePrefixes.contains(prefix)) return 'Vodafone';
    if (etisalatPrefixes.contains(prefix)) return 'Etisalat';
    if (orangePrefixes.contains(prefix)) return 'Orange';
    if (wePrefixes.contains(prefix)) return 'WE';

    return 'Other';
  }

  /// Calculates the transaction fee based on source wallet and receiver number.
  ///
  /// Rules:
  /// 1. Vodafone Cash:
  ///    - To Vodafone (010): 1 EGP
  ///    - To Others: 0.5% (Min 1, Max 15)
  /// 2. Etisalat Cash:
  ///    - To Etisalat (011): 1 EGP
  ///    - To Others: 0.5% (Min 1, Max 15)
  /// 3. Orange Cash:
  ///    - To Orange (012): 1 EGP
  ///    - To Others: 0.5% (Min 1, Max 15)
  /// 4. InstaPay:
  ///    - To Any: 0.1% (Min 0.5, Max 20)
  static double calculateTransactionFee({
    required double amount,
    required String sourceWalletType,
    required String receiverPhone,
  }) {
    if (amount <= 0) return 0.0;

    final provider = identifyProvider(receiverPhone);

    switch (sourceWalletType) {
      case walletVodafone:
        if (provider == 'Vodafone') {
          return 1.0;
        } else {
          return _calculatePercentageFee(amount, 0.005, 1.0, 15.0);
        }

      case walletEtisalat:
        if (provider == 'Etisalat') {
          return 1.0;
        } else {
          return _calculatePercentageFee(amount, 0.005, 1.0, 15.0);
        }

      case walletOrange:
        if (provider == 'Orange') {
          return 1.0;
        } else {
          return _calculatePercentageFee(amount, 0.005, 1.0, 15.0);
        }

      case walletInstaPay:
        return _calculatePercentageFee(amount, 0.001, 0.5, 20.0);

      default:
        return 0.0;
    }
  }

  static double _calculatePercentageFee(
    double amount,
    double rate,
    double min,
    double max,
  ) {
    var fee = amount * rate;
    return fee.clamp(min, max);
  }
}
