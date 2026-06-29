import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/utils/fee_calculator.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';

void main() {
  group('FeeCalculator Dynamic Fees', () {
    const defaultSettings = PlatformSettingsModel.defaults();

    final customSettings = PlatformSettingsModel(
      newWalletTransactionLimit: 10000.0,
      newWalletMonthlyLimit: 60000.0,
      oldWalletTransactionLimit: 60000.0,
      oldWalletMonthlyLimit: 200000.0,
      registeredStoreTransactionLimit: 60000.0,
      registeredStoreMonthlyLimit: 400000.0,
      instapayTransactionLimit: 120000.0,
      instapayMonthlyLimit: 400000.0,
      
      minCrossNetworkFee: 2.0, // Default is 1.0
      maxCrossNetworkFee: 20.0, // Default is 15.0
      minInstapayFee: 1.0, // Default is 0.5
      maxInstapayFee: 30.0, // Default is 20.0
      
      sameNetworkFee: 2.0, // Default is 1.0
      crossNetworkFeeRate: 0.01, // Default is 0.005 (0.5%)
      instapayFeeRate: 0.002, // Default is 0.001 (0.1%)
      
      trialDurationDays: 30,
    );

    test('Vodafone same-network fee uses sameNetworkFee settings', () {
      final defaultFee = FeeCalculator.calculateTransactionFee(
        amount: 100.0,
        sourceWalletType: FeeCalculator.walletVodafone,
        receiverPhone: '01012345678', // Vodafone recipient
        settings: defaultSettings,
      );
      expect(defaultFee, 1.0);

      final customFee = FeeCalculator.calculateTransactionFee(
        amount: 100.0,
        sourceWalletType: FeeCalculator.walletVodafone,
        receiverPhone: '01012345678',
        settings: customSettings,
      );
      expect(customFee, 2.0); // Verifies sameNetworkFee settings
    });

    test('Cross-network fee matches percentage rate and caps min/max', () {
      // Amount 1000.0 * 0.005 (default rate) = 5.0 (between 1.0 and 15.0)
      final defaultNormal = FeeCalculator.calculateTransactionFee(
        amount: 1000.0,
        sourceWalletType: FeeCalculator.walletVodafone,
        receiverPhone: '01112345678', // Etisalat recipient
        settings: defaultSettings,
      );
      expect(defaultNormal, 5.0);

      // Amount 100.0 * 0.005 = 0.5 -> capped at min 1.0 (default)
      final defaultMin = FeeCalculator.calculateTransactionFee(
        amount: 100.0,
        sourceWalletType: FeeCalculator.walletVodafone,
        receiverPhone: '01112345678',
        settings: defaultSettings,
      );
      expect(defaultMin, 1.0);

      // Amount 5000.0 * 0.005 = 25.0 -> capped at max 15.0 (default)
      final defaultMax = FeeCalculator.calculateTransactionFee(
        amount: 5000.0,
        sourceWalletType: FeeCalculator.walletVodafone,
        receiverPhone: '01112345678',
        settings: defaultSettings,
      );
      expect(defaultMax, 15.0);

      // Custom settings checks: rate=0.01, min=2.0, max=20.0
      final customNormal = FeeCalculator.calculateTransactionFee(
        amount: 500.0,
        sourceWalletType: FeeCalculator.walletVodafone,
        receiverPhone: '01112345678',
        settings: customSettings,
      );
      expect(customNormal, 5.0); // 500.0 * 0.01 = 5.0

      final customMin = FeeCalculator.calculateTransactionFee(
        amount: 100.0,
        sourceWalletType: FeeCalculator.walletVodafone,
        receiverPhone: '01112345678',
        settings: customSettings,
      );
      expect(customMin, 2.0); // 100.0 * 0.01 = 1.0 -> clamped at min 2.0

      final customMax = FeeCalculator.calculateTransactionFee(
        amount: 3000.0,
        sourceWalletType: FeeCalculator.walletVodafone,
        receiverPhone: '01112345678',
        settings: customSettings,
      );
      expect(customMax, 20.0); // 3000.0 * 0.01 = 30.0 -> clamped at max 20.0
    });

    test('InstaPay fee matches percentage rate and caps min/max', () {
      // Default: rate=0.001 (0.1%), min=0.5, max=20.0
      // Amount 1000.0 * 0.001 = 1.0
      final defaultNormal = FeeCalculator.calculateTransactionFee(
        amount: 1000.0,
        sourceWalletType: FeeCalculator.walletInstaPay,
        receiverPhone: '01212345678',
        settings: defaultSettings,
      );
      expect(defaultNormal, 1.0);

      // Amount 100.0 * 0.001 = 0.1 -> clamped at 0.5
      final defaultMin = FeeCalculator.calculateTransactionFee(
        amount: 100.0,
        sourceWalletType: FeeCalculator.walletInstaPay,
        receiverPhone: '01212345678',
        settings: defaultSettings,
      );
      expect(defaultMin, 0.5);

      // Amount 30000.0 * 0.001 = 30.0 -> clamped at 20.0
      final defaultMax = FeeCalculator.calculateTransactionFee(
        amount: 30000.0,
        sourceWalletType: FeeCalculator.walletInstaPay,
        receiverPhone: '01212345678',
        settings: defaultSettings,
      );
      expect(defaultMax, 20.0);

      // Custom settings checks: rate=0.002, min=1.0, max=30.0
      final customNormal = FeeCalculator.calculateTransactionFee(
        amount: 1000.0,
        sourceWalletType: FeeCalculator.walletInstaPay,
        receiverPhone: '01212345678',
        settings: customSettings,
      );
      expect(customNormal, 2.0); // 1000.0 * 0.002 = 2.0

      final customMin = FeeCalculator.calculateTransactionFee(
        amount: 100.0,
        sourceWalletType: FeeCalculator.walletInstaPay,
        receiverPhone: '01212345678',
        settings: customSettings,
      );
      expect(customMin, 1.0); // 100 * 0.002 = 0.2 -> clamped at 1.0

      final customMax = FeeCalculator.calculateTransactionFee(
        amount: 20000.0,
        sourceWalletType: FeeCalculator.walletInstaPay,
        receiverPhone: '01212345678',
        settings: customSettings,
      );
      expect(customMax, 30.0); // 20000 * 0.002 = 40.0 -> clamped at 30.0
    });

    test('Throws DomainException when amount is zero or negative', () {
      expect(
        () => FeeCalculator.calculateTransactionFee(
          amount: 0.0,
          sourceWalletType: FeeCalculator.walletVodafone,
          receiverPhone: '01012345678',
          settings: defaultSettings,
        ),
        throwsA(isA<DomainException>()),
      );

      expect(
        () => FeeCalculator.calculateTransactionFee(
          amount: -100.0,
          sourceWalletType: FeeCalculator.walletVodafone,
          receiverPhone: '01012345678',
          settings: defaultSettings,
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });
}
