import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';

void main() {
  group('PlatformSettingsModel', () {
    test('fromJson creates correct model with valid inputs', () {
      final json = {
        'limits': {
          'newWalletTransactionLimit': 15000.0,
          'newWalletMonthlyLimit': 75000.0,
          'oldWalletTransactionLimit': 80000.0,
          'oldWalletMonthlyLimit': 250000.0,
          'registeredStoreTransactionLimit': 90000.0,
          'registeredStoreMonthlyLimit': 500000.0,
          'instapayTransactionLimit': 150000.0,
          'instapayMonthlyLimit': 600000.0,
        },
        'feeLimits': {
          'minCrossNetworkFee': 2.0,
          'maxCrossNetworkFee': 20.0,
          'minInstapayFee': 1.0,
          'maxInstapayFee': 30.0,
        },
        'serviceFees': {
          'sameNetworkFee': 1.5,
          'crossNetworkFeeRate': 0.007,
          'instapayFeeRate': 0.002,
        },
        'subscriptions': {
          'trialDurationDays': 45,
        }
      };

      final model = PlatformSettingsModel.fromJson(json);

      expect(model.newWalletTransactionLimit, 15000.0);
      expect(model.newWalletMonthlyLimit, 75000.0);
      expect(model.oldWalletTransactionLimit, 80000.0);
      expect(model.oldWalletMonthlyLimit, 250000.0);
      expect(model.registeredStoreTransactionLimit, 90000.0);
      expect(model.registeredStoreMonthlyLimit, 500000.0);
      expect(model.instapayTransactionLimit, 150000.0);
      expect(model.instapayMonthlyLimit, 600000.0);

      expect(model.minCrossNetworkFee, 2.0);
      expect(model.maxCrossNetworkFee, 20.0);
      expect(model.minInstapayFee, 1.0);
      expect(model.maxInstapayFee, 30.0);

      expect(model.sameNetworkFee, 1.5);
      expect(model.crossNetworkFeeRate, 0.007);
      expect(model.instapayFeeRate, 0.002);

      expect(model.trialDurationDays, 45);
    });

    test('fromJson falls back to safe defaults when inputs are empty or null', () {
      final model = PlatformSettingsModel.fromJson({});

      expect(model.newWalletTransactionLimit, 10000.0);
      expect(model.newWalletMonthlyLimit, 60000.0);
      expect(model.oldWalletTransactionLimit, 60000.0);
      expect(model.oldWalletMonthlyLimit, 200000.0);
      expect(model.registeredStoreTransactionLimit, 60000.0);
      expect(model.registeredStoreMonthlyLimit, 400000.0);
      expect(model.instapayTransactionLimit, 120000.0);
      expect(model.instapayMonthlyLimit, 400000.0);

      expect(model.minCrossNetworkFee, 1.0);
      expect(model.maxCrossNetworkFee, 15.0);
      expect(model.minInstapayFee, 0.5);
      expect(model.maxInstapayFee, 20.0);

      expect(model.sameNetworkFee, 1.0);
      expect(model.crossNetworkFeeRate, 0.005);
      expect(model.instapayFeeRate, 0.001);

      expect(model.trialDurationDays, 30);
    });

    test('toJson serializes correctly', () {
      final json = {
        'limits': {
          'newWalletTransactionLimit': 15000.0,
          'newWalletMonthlyLimit': 75000.0,
          'oldWalletTransactionLimit': 80000.0,
          'oldWalletMonthlyLimit': 250000.0,
          'registeredStoreTransactionLimit': 90000.0,
          'registeredStoreMonthlyLimit': 500000.0,
          'instapayTransactionLimit': 150000.0,
          'instapayMonthlyLimit': 600000.0,
        },
        'feeLimits': {
          'minCrossNetworkFee': 2.0,
          'maxCrossNetworkFee': 20.0,
          'minInstapayFee': 1.0,
          'maxInstapayFee': 30.0,
        },
        'serviceFees': {
          'sameNetworkFee': 1.5,
          'crossNetworkFeeRate': 0.007,
          'instapayFeeRate': 0.002,
        },
        'subscriptions': {
          'trialDurationDays': 45,
        }
      };

      final model = PlatformSettingsModel.fromJson(json);
      final serialized = model.toJson();

      expect(serialized['limits']['newWalletTransactionLimit'], 15000.0);
      expect(serialized['feeLimits']['minCrossNetworkFee'], 2.0);
      expect(serialized['serviceFees']['sameNetworkFee'], 1.5);
      expect(serialized['subscriptions']['trialDurationDays'], 45);
    });
  });
}
