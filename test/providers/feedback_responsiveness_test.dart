import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/debt_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/services/wallet_cache_manager.dart';
import 'package:walletmanager/domain/usecases/wallet_usecase.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/debt_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'dart:async';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

class MockDebtRepository extends Mock implements DebtRepository {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockWalletCacheManager extends Mock implements WalletCacheManager {}

class MockWalletUseCase extends Mock implements WalletUseCase {}

class MockStatisticsProvider extends Mock implements StatisticsProvider {}

class DebtModelFake extends Fake implements DebtModel {}

class WalletModelFake extends Fake implements WalletModel {}

void main() {
  late MockAuthProvider mockAuth;
  late MockSubscriptionProvider mockSub;
  late MockDebtRepository mockDebtRepo;
  late MockWalletRepository mockWalletRepo;
  late MockTransactionRepository mockTransactionRepo;
  late MockWalletCacheManager mockCacheManager;
  late MockWalletUseCase mockUseCase;
  late MockStatisticsProvider mockStatsProvider;

  setUpAll(() {
    registerFallbackValue(DebtModelFake());
    registerFallbackValue(WalletModelFake());
  });

  setUp(() async {
    await sl.reset();
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockAuth = MockAuthProvider();
    mockSub = MockSubscriptionProvider();
    mockDebtRepo = MockDebtRepository();
    mockWalletRepo = MockWalletRepository();
    mockTransactionRepo = MockTransactionRepository();
    mockCacheManager = MockWalletCacheManager();
    mockUseCase = MockWalletUseCase();
    mockStatsProvider = MockStatisticsProvider();

    when(() => mockAuth.currentStoreId).thenReturn('store1');
    when(() => mockAuth.currentUserId).thenReturn('user1');
    when(() => mockAuth.currentUser).thenReturn(UserModel(
      userId: 'user1',
      storeId: 'store1',
      role: UserRole.owner,
      fullName: 'Owner',
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    ));

    when(() => mockCacheManager.cacheWallets(any())).thenAnswer((_) async {});
    when(() => mockSub.canAddWallet(any())).thenReturn(true);
    when(() => mockUseCase.calculateFrozenWallets(
          wallets: any(named: 'wallets'),
          subscriptionProvider: any(named: 'subscriptionProvider'),
          storeId: any(named: 'storeId'),
        )).thenReturn(<String>{});

    when(() => mockStatsProvider.dashboardSummary).thenReturn(null);
    when(() => mockStatsProvider.todayStats).thenReturn(null);
    when(() => mockStatsProvider.addDebtOptimistically(
        amount: any(named: 'amount'))).thenAnswer((_) {});

    sl.registerSingleton<StatisticsProvider>(mockStatsProvider);
  });

  group('Provider Responsiveness', () {
    test(
        'DebtProvider.createDebt should reset error and set isCreating immediately',
        () async {
      final provider = DebtProvider(
          authProvider: mockAuth,
          debtRepository: mockDebtRepo,
          storeId: 'store1');
      provider.setError('old error');

      final completer = Completer<void>();
      when(() => mockDebtRepo.getDebtByCustomerPhone(any(), any()))
          .thenAnswer((_) async => null);
      when(() => mockDebtRepo.generateId()).thenReturn('new-debt');
      when(() => mockDebtRepo.createDebt(any()))
          .thenAnswer((_) => completer.future);

      final future = provider.createDebt(
        customerName: 'Test',
        customerPhone: '01234567890',
        debtType: DebtType.transaction,
        amountDue: 100.0,
        createdBy: 'user1',
      );

      expect(provider.isCreating, isTrue);
      expect(provider.errorMessage, isNull);

      completer.complete();
      await future;
      expect(provider.isCreating, isFalse);
    });

    test(
        'WalletProvider.createWallet should reset error and set isCreating immediately',
        () async {
      final provider = WalletProvider(
          authProvider: mockAuth,
          subscriptionProvider: mockSub,
          walletRepository: mockWalletRepo,
          transactionRepository: mockTransactionRepo,
          cacheManager: mockCacheManager,
          walletUseCase: mockUseCase,
          storeId: 'store1');
      provider.setError('old error');

      final completer = Completer<void>();
      when(() => mockWalletRepo.getWalletsCount(any()))
          .thenAnswer((_) async => 0);
      when(() => mockWalletRepo.generateId()).thenReturn('new-wallet');
      when(() => mockWalletRepo.createWallet(any()))
          .thenAnswer((_) => completer.future);
      when(() => mockUseCase.validatePermission(any()))
          .thenAnswer((_) async => mockAuth.currentUser!);

      final future = provider.createWallet(
        phoneNumber: '01234567890',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100.0,
        createdBy: 'user1',
      );

      expect(provider.isCreating, isTrue);
      expect(provider.errorMessage, isNull);

      completer.complete();
      await future;
      expect(provider.isCreating, isFalse);
    });
  });
}
