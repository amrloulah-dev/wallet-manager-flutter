import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/domain/usecases/transaction_fee_calculator.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';

class MockWalletModel extends Mock implements WalletModel {}

class MockWalletLimits extends Mock implements WalletLimits {}

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

void main() {
  late TransactionFeeCalculator calculator;
  late MockWalletModel mockWallet;
  late MockWalletLimits mockLimits;

  setUp(() {
    calculator = TransactionFeeCalculator();
    mockWallet = MockWalletModel();
    mockLimits = MockWalletLimits();

    final mockSettingsProvider = MockPlatformSettingsProvider();
    final mockSettings = const PlatformSettingsModel.defaults();
    when(() => mockSettingsProvider.settings).thenReturn(mockSettings);
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      sl.unregister<PlatformSettingsProvider>();
    }
    sl.registerSingleton<PlatformSettingsProvider>(mockSettingsProvider);

    // Default mocks
    when(() => mockWallet.walletType).thenReturn(WalletType.vodafoneCash);
    when(() => mockWallet.getLimits()).thenReturn(mockLimits);
    when(() => mockWallet.getReceiveLimits()).thenReturn(mockLimits);
    when(() => mockLimits.dailyUsed).thenReturn(0.0);
    when(() => mockLimits.monthlyUsed).thenReturn(0.0);
    when(() => mockLimits.dailyLimit).thenReturn(1000.0);
    when(() => mockLimits.monthlyLimit).thenReturn(10000.0);
  });

  group('TransactionFeeCalculator Hardening', () {
    test('should throw DomainException when transactionType is null', () {
      expect(
        () => calculator.calculate(
          wallet: mockWallet,
          transactionType: null,
          amount: 100.0,
          commission: 5.0,
          receiverPhone: '01012345678',
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('should include serviceFee in totalAmount', () {
      // Vodafone prefix '010' with Vodafone wallet should give 1.0 fee
      // We expect the implementation to be fixed to use the correct name/string

      final result = calculator.calculate(
        wallet: mockWallet,
        transactionType: TransactionType.debit,
        amount: 100.0,
        commission: 5.0,
        receiverPhone: '01012345678',
      );

      // Expected totalAmount = amount + commission + serviceFee
      // 100.0 + 5.0 + 1.0 = 106.0
      expect(result.totalAmount, 106.0);
      expect(result.serviceFee, 1.0);
    });

    test('should throw DomainException for unknown wallet type', () {
      when(() => mockWallet.walletType).thenReturn(WalletType.other);

      expect(
        () => calculator.calculate(
          wallet: mockWallet,
          transactionType: TransactionType.debit,
          amount: 100.0,
          commission: 5.0,
          receiverPhone: '01012345678',
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('should throw DomainException when amount is negative', () {
      expect(
        () => calculator.calculate(
          wallet: mockWallet,
          transactionType: TransactionType.debit,
          amount: -10.0,
          commission: 5.0,
          receiverPhone: '01012345678',
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('should throw DomainException when commission is negative', () {
      expect(
        () => calculator.calculate(
          wallet: mockWallet,
          transactionType: TransactionType.debit,
          amount: 100.0,
          commission: -5.0,
          receiverPhone: '01012345678',
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });
}
