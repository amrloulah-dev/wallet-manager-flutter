import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockAuthProvider extends Mock implements AuthProvider {}
class MockStatsRepository extends Mock implements StatsRepository {}
class MockWalletRepository extends Mock implements WalletRepository {}
class MockWalletProvider extends Mock implements WalletProvider {}
class MockPlatformSettingsProvider extends Mock implements PlatformSettingsProvider {}
class FakeTransactionModel extends Fake implements TransactionModel {}

void main() {
  late MockTransactionRepository mockTxRepo;
  late MockWalletRepository mockWalletRepo;
  late MockAuthProvider mockAuth;
  late MockWalletProvider mockWalletProvider;
  late MockPlatformSettingsProvider mockSettingsProvider;

  setUpAll(() {
    registerFallbackValue(UserRole.employee);
    registerFallbackValue(FakeTransactionModel());
    registerFallbackValue(DateTimeRange(start: DateTime.now(), end: DateTime.now()));
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockTxRepo = MockTransactionRepository();
    mockWalletRepo = MockWalletRepository();
    mockAuth = MockAuthProvider();
    mockWalletProvider = MockWalletProvider();
    mockSettingsProvider = MockPlatformSettingsProvider();

    when(() => mockTxRepo.getTransactionsByDateRange(any(), any(), any(),
            lastDocument: any(named: 'lastDocument')))
        .thenAnswer((_) async =>
            PaginatedResult<TransactionModel>(items: [], lastDocument: null));

    final sl = GetIt.instance;
    if (sl.isRegistered<StatsRepository>()) {
      sl.unregister<StatsRepository>();
    }
    final mockStats = MockStatsRepository();
    sl.registerSingleton<StatsRepository>(mockStats);
    
    when(() => mockStats.fetchTodayStats(any()))
        .thenAnswer((_) async => DailyStatsModel.empty('2026-06-29'));

    when(() => mockAuth.currentStoreId).thenReturn('s1');
    when(() => mockWalletProvider.walletMap)
        .thenReturn(<String, WalletModel>{});
    when(() => mockWalletProvider.isWalletFrozenSync(any())).thenReturn(false);
  });

  group('TransactionProvider Dynamic Limits Validation', () {
    final customSettings = PlatformSettingsModel(
      newWalletTransactionLimit: 5000.0,
      newWalletMonthlyLimit: 30000.0,
      oldWalletTransactionLimit: 40000.0,
      oldWalletMonthlyLimit: 150000.0,
      registeredStoreTransactionLimit: 50000.0,
      registeredStoreMonthlyLimit: 300000.0,
      instapayTransactionLimit: 80000.0,
      instapayMonthlyLimit: 300000.0,
      
      minCrossNetworkFee: 1.0,
      maxCrossNetworkFee: 15.0,
      minInstapayFee: 0.5,
      maxInstapayFee: 20.0,
      sameNetworkFee: 1.0,
      crossNetworkFeeRate: 0.005,
      instapayFeeRate: 0.001,
      trialDurationDays: 30,
    );

    test('should reject debit transaction when amount exceeds dynamic limits', () async {
      final user = UserModel(
        userId: 'owner1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Owner Name',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      final wallet = WalletModel(
        walletId: 'w1',
        storeId: 's1',
        phoneNumber: '01000000000',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active, // maps to newWalletTransactionLimit (5000.0)
        balance: 10000.0,
        isActive: true,
        createdBy: 'owner1',
        sendLimits: WalletLimits(dailyLimit: 5000, dailyUsed: 0, monthlyLimit: 30000, monthlyUsed: 0),
        receiveLimits: WalletLimits(dailyLimit: 5000, dailyUsed: 0, monthlyLimit: 30000, monthlyUsed: 0),
        stats: WalletStats(totalTransactions: 0, totalCommission: 0, totalSentAmount: 0, totalReceivedAmount: 0),
      );

      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => mockAuth.isOwner).thenReturn(true);
      when(() => mockWalletRepo.getWalletById('w1', expectedStoreId: 's1'))
          .thenAnswer((_) async => wallet);
      when(() => mockSettingsProvider.settings).thenReturn(customSettings);

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        walletRepository: mockWalletRepo,
        platformSettingsProvider: mockSettingsProvider,
      );
      provider.updateAuthState(mockAuth);
      provider.updateWalletProvider(mockWalletProvider);

      // Amount 6000 exceeds dynamic limit of 5000 for active (new) wallet
      final result = await provider.createTransaction(
        walletId: 'w1',
        transactionType: TransactionType.debit,
        amount: 6000.0,
        commission: 0.0,
      );

      expect(result, isFalse);
      expect(provider.errorMessage, equals('wallet_error_telecom_limit'));
    });

    test('should reject debit transaction when amount exceeds dynamic InstaPay limit', () async {
      final user = UserModel(
        userId: 'owner1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Owner Name',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      final wallet = WalletModel(
        walletId: 'w2',
        storeId: 's1',
        phoneNumber: '01000000000',
        walletType: WalletType.instaPay,
        walletStatus: WalletStatus.active,
        balance: 100000.0,
        isActive: true,
        createdBy: 'owner1',
        sendLimits: WalletLimits(dailyLimit: 80000, dailyUsed: 0, monthlyLimit: 300000, monthlyUsed: 0),
        receiveLimits: WalletLimits(dailyLimit: 80000, dailyUsed: 0, monthlyLimit: 300000, monthlyUsed: 0),
        stats: WalletStats(totalTransactions: 0, totalCommission: 0, totalSentAmount: 0, totalReceivedAmount: 0),
      );

      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => mockAuth.isOwner).thenReturn(true);
      when(() => mockWalletRepo.getWalletById('w2', expectedStoreId: 's1'))
          .thenAnswer((_) async => wallet);
      when(() => mockSettingsProvider.settings).thenReturn(customSettings);

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        walletRepository: mockWalletRepo,
        platformSettingsProvider: mockSettingsProvider,
      );
      provider.updateAuthState(mockAuth);
      provider.updateWalletProvider(mockWalletProvider);

      // Amount 90000 exceeds dynamic limit of 80000 for InstaPay
      final result = await provider.createTransaction(
        walletId: 'w2',
        transactionType: TransactionType.debit,
        amount: 90000.0,
        commission: 0.0,
      );

      expect(result, isFalse);
      expect(provider.errorMessage, equals('wallet_error_instapay_limit'));
    });

    test('should allow debit transaction when amount is within dynamic limits', () async {
      final user = UserModel(
        userId: 'owner1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Owner Name',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      final wallet = WalletModel(
        walletId: 'w1',
        storeId: 's1',
        phoneNumber: '01000000000',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 10000.0,
        isActive: true,
        createdBy: 'owner1',
        sendLimits: WalletLimits(dailyLimit: 5000, dailyUsed: 0, monthlyLimit: 30000, monthlyUsed: 0),
        receiveLimits: WalletLimits(dailyLimit: 5000, dailyUsed: 0, monthlyLimit: 30000, monthlyUsed: 0),
        stats: WalletStats(totalTransactions: 0, totalCommission: 0, totalSentAmount: 0, totalReceivedAmount: 0),
      );

      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => mockAuth.isOwner).thenReturn(true);
      when(() => mockWalletRepo.getWalletById('w1', expectedStoreId: 's1'))
          .thenAnswer((_) async => wallet);
      when(() => mockSettingsProvider.settings).thenReturn(customSettings);
      when(() => mockTxRepo.createTransaction(any())).thenAnswer((_) async {});

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        walletRepository: mockWalletRepo,
        platformSettingsProvider: mockSettingsProvider,
      );
      provider.updateAuthState(mockAuth);
      provider.updateWalletProvider(mockWalletProvider);

      // Amount 4000 is within 5000 limit
      final result = await provider.createTransaction(
        walletId: 'w1',
        transactionType: TransactionType.debit,
        amount: 4000.0,
        commission: 0.0,
      );

      expect(result, isTrue);
    });
  });
}
