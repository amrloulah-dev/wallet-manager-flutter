import 'package:flutter/foundation.dart';
import '../errors/app_exceptions.dart';
import 'amount_validator.dart';
import '../../data/models/platform_settings_model.dart';

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
  static const String walletWePay = 'we_pay';
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
  static double calculateTransactionFee({
    required double amount,
    required String sourceWalletType,
    required String receiverPhone,
    required PlatformSettingsModel settings,
  }) {
    AmountValidator.ensurePositive(amount);

    final provider = identifyProvider(receiverPhone);
    if (kDebugMode) {
      debugPrint('🔥 [TX_FLOW] [fee_calculator] -> calculateTransactionFee: '
          'amount=$amount, sourceWalletType=$sourceWalletType, '
          'receiverPhone=$receiverPhone, identifiedProvider=$provider');
    }

    switch (sourceWalletType) {
      case walletVodafone:
        if (provider == 'Vodafone') {
          return settings.sameNetworkFee;
        } else {
          return _calculatePercentageFee(
            amount,
            settings.crossNetworkFeeRate,
            settings.minCrossNetworkFee,
            settings.maxCrossNetworkFee,
          );
        }

      case walletEtisalat:
        if (provider == 'Etisalat') {
          return settings.sameNetworkFee;
        } else {
          return _calculatePercentageFee(
            amount,
            settings.crossNetworkFeeRate,
            settings.minCrossNetworkFee,
            settings.maxCrossNetworkFee,
          );
        }

      case walletOrange:
        if (provider == 'Orange') {
          return settings.sameNetworkFee;
        } else {
          return _calculatePercentageFee(
            amount,
            settings.crossNetworkFeeRate,
            settings.minCrossNetworkFee,
            settings.maxCrossNetworkFee,
          );
        }

      case walletWePay:
        if (provider == 'WE') {
          return settings.sameNetworkFee;
        } else {
          return _calculatePercentageFee(
            amount,
            settings.crossNetworkFeeRate,
            settings.minCrossNetworkFee,
            settings.maxCrossNetworkFee,
          );
        }

      case walletInstaPay:
        return _calculatePercentageFee(
          amount,
          settings.instapayFeeRate,
          settings.minInstapayFee,
          settings.maxInstapayFee,
        );

      default:
        throw DomainException(
            'Unknown wallet type for fee calculation: $sourceWalletType. '
            'Transaction cannot proceed without a valid fee.');
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
