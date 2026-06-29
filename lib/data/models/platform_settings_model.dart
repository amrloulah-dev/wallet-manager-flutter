import 'package:flutter/foundation.dart';
import '../../core/utils/number_parser.dart';

class PlatformSettingsModel {
  // Limits
  final double newWalletTransactionLimit;
  final double newWalletMonthlyLimit;
  final double oldWalletTransactionLimit;
  final double oldWalletMonthlyLimit;
  final double registeredStoreTransactionLimit;
  final double registeredStoreMonthlyLimit;
  final double instapayTransactionLimit;
  final double instapayMonthlyLimit;

  // Fee Limits
  final double minCrossNetworkFee;
  final double maxCrossNetworkFee;
  final double minInstapayFee;
  final double maxInstapayFee;

  // Service Fees
  final double sameNetworkFee;
  final double crossNetworkFeeRate;
  final double instapayFeeRate;

  // Subscriptions
  final int trialDurationDays;

  const PlatformSettingsModel({
    required this.newWalletTransactionLimit,
    required this.newWalletMonthlyLimit,
    required this.oldWalletTransactionLimit,
    required this.oldWalletMonthlyLimit,
    required this.registeredStoreTransactionLimit,
    required this.registeredStoreMonthlyLimit,
    required this.instapayTransactionLimit,
    required this.instapayMonthlyLimit,
    required this.minCrossNetworkFee,
    required this.maxCrossNetworkFee,
    required this.minInstapayFee,
    required this.maxInstapayFee,
    required this.sameNetworkFee,
    required this.crossNetworkFeeRate,
    required this.instapayFeeRate,
    required this.trialDurationDays,
  });

  factory PlatformSettingsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ [PlatformSettingsModel] Warning: loaded empty settings, falling back to safe defaults.');
      }
      return const PlatformSettingsModel.defaults();
    }

    final limits = json['limits'] as Map<String, dynamic>? ?? {};
    final feeLimits = json['feeLimits'] as Map<String, dynamic>? ?? {};
    final serviceFees = json['serviceFees'] as Map<String, dynamic>? ?? {};
    final subscriptions = json['subscriptions'] as Map<String, dynamic>? ?? {};

    return PlatformSettingsModel(
      newWalletTransactionLimit: NumberParser.toDouble(limits['newWalletTransactionLimit'], 10000.0),
      newWalletMonthlyLimit: NumberParser.toDouble(limits['newWalletMonthlyLimit'], 60000.0),
      oldWalletTransactionLimit: NumberParser.toDouble(limits['oldWalletTransactionLimit'], 60000.0),
      oldWalletMonthlyLimit: NumberParser.toDouble(limits['oldWalletMonthlyLimit'], 200000.0),
      registeredStoreTransactionLimit: NumberParser.toDouble(limits['registeredStoreTransactionLimit'], 60000.0),
      registeredStoreMonthlyLimit: NumberParser.toDouble(limits['registeredStoreMonthlyLimit'], 400000.0),
      instapayTransactionLimit: NumberParser.toDouble(limits['instapayTransactionLimit'], 120000.0),
      instapayMonthlyLimit: NumberParser.toDouble(limits['instapayMonthlyLimit'], 400000.0),
      
      minCrossNetworkFee: NumberParser.toDouble(feeLimits['minCrossNetworkFee'], 1.0),
      maxCrossNetworkFee: NumberParser.toDouble(feeLimits['maxCrossNetworkFee'], 15.0),
      minInstapayFee: NumberParser.toDouble(feeLimits['minInstapayFee'], 0.5),
      maxInstapayFee: NumberParser.toDouble(feeLimits['maxInstapayFee'], 20.0),
      
      sameNetworkFee: NumberParser.toDouble(serviceFees['sameNetworkFee'], 1.0),
      crossNetworkFeeRate: NumberParser.toDouble(serviceFees['crossNetworkFeeRate'], 0.005),
      instapayFeeRate: NumberParser.toDouble(serviceFees['instapayFeeRate'], 0.001),
      
      trialDurationDays: NumberParser.toInt(subscriptions['trialDurationDays'], 30),
    );
  }

  const PlatformSettingsModel.defaults()
      : newWalletTransactionLimit = 10000.0,
        newWalletMonthlyLimit = 60000.0,
        oldWalletTransactionLimit = 60000.0,
        oldWalletMonthlyLimit = 200000.0,
        registeredStoreTransactionLimit = 60000.0,
        registeredStoreMonthlyLimit = 400000.0,
        instapayTransactionLimit = 120000.0,
        instapayMonthlyLimit = 400000.0,
        minCrossNetworkFee = 1.0,
        maxCrossNetworkFee = 15.0,
        minInstapayFee = 0.5,
        maxInstapayFee = 20.0,
        sameNetworkFee = 1.0,
        crossNetworkFeeRate = 0.005,
        instapayFeeRate = 0.001,
        trialDurationDays = 30;

  Map<String, dynamic> toJson() {
    return {
      'limits': {
        'newWalletTransactionLimit': newWalletTransactionLimit,
        'newWalletMonthlyLimit': newWalletMonthlyLimit,
        'oldWalletTransactionLimit': oldWalletTransactionLimit,
        'oldWalletMonthlyLimit': oldWalletMonthlyLimit,
        'registeredStoreTransactionLimit': registeredStoreTransactionLimit,
        'registeredStoreMonthlyLimit': registeredStoreMonthlyLimit,
        'instapayTransactionLimit': instapayTransactionLimit,
        'instapayMonthlyLimit': instapayMonthlyLimit,
      },
      'feeLimits': {
        'minCrossNetworkFee': minCrossNetworkFee,
        'maxCrossNetworkFee': maxCrossNetworkFee,
        'minInstapayFee': minInstapayFee,
        'maxInstapayFee': maxInstapayFee,
      },
      'serviceFees': {
        'sameNetworkFee': sameNetworkFee,
        'crossNetworkFeeRate': crossNetworkFeeRate,
        'instapayFeeRate': instapayFeeRate,
      },
      'subscriptions': {
        'trialDurationDays': trialDurationDays,
      },
    };
  }
}
