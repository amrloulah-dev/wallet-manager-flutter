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
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockAuthProvider extends Mock implements AuthProvider {}
class MockStatsRepository extends Mock implements StatsRepository {}
class MockWalletRepository extends Mock implements WalletRepository {}
class MockWalletProvider extends Mock implements WalletProvider {}
class FakeTransactionModel extends Fake implements TransactionModel {}

void main() {
  late MockTransactionRepository mockTxRepo;
  late MockWalletRepository mockWalletRepo;
  late MockAuthProvider mockAuth;
  late MockWalletProvider mockWalletProvider;

  setUpAll(() {
    registerFallbackValue(UserRole.employee);
    registerFallbackValue(FakeTransactionModel());
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockTxRepo = MockTransactionRepository();
    mockWalletRepo = MockWalletRepository();
    mockAuth = MockAuthProvider();
    mockWalletProvider = MockWalletProvider();

    final sl = GetIt.instance;
    late MockStatsRepository mockStats;
    if (!sl.isRegistered<StatsRepository>()) {
      mockStats = MockStatsRepository();
      sl.registerLazySingleton<StatsRepository>(() => mockStats);
    } else {
      mockStats = sl<StatsRepository>() as MockStatsRepository;
    }
    when(() => mockStats.fetchTodayStats(any()))
        .thenAnswer((_) async => DailyStatsModel.empty('2026-05-26'));

    when(() => mockAuth.currentStoreId).thenReturn('s1');
  });

  group('TransactionProvider Frozen Wallet Guard Tests', () {
    test(
        'createTransaction should return false and set error if wallet is dynamically frozen by provider',
        () async {
      final owner = UserModel(
        userId: 'o1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Owner',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      final mockWallet = WalletModel.fromWalletStatus(
        walletId: 'w1',
        storeId: 's1',
        phoneNumber: '01000000000',
        walletType: WalletType.vodafoneCash.name,
        walletStatus: WalletStatus.active.name,
        balance: 1000.0,
        createdBy: 'owner1',
      );

      when(() => mockAuth.currentUser).thenReturn(owner);
      when(() => mockAuth.isOwner).thenReturn(true);
      when(() => mockWalletRepo.getWalletById('w1', expectedStoreId: 's1'))
          .thenAnswer((_) async => mockWallet);
      when(() => mockWalletProvider.isWalletFrozenSync('w1')).thenReturn(true);

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        walletRepository: mockWalletRepo,
        storeId: 's1',
      );
      provider.updateAuthState(mockAuth);
      provider.updateWalletProvider(mockWalletProvider);

      // Act
      final result = await provider.createTransaction(
        walletId: 'w1',
        amount: 100.0,
        commission: 5.0,
        transactionType: TransactionType.deposit,
      );

      // Assert
      expect(result, isFalse);
      expect(provider.hasError, isTrue);
      expect(provider.errorMessage, equals('wallet_is_frozen'));
    });

    test(
        'updateTransaction should return false and set error if wallet is dynamically frozen by provider',
        () async {
      final owner = UserModel(
        userId: 'o1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Owner',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      final mockTx = TransactionModel(
        transactionId: 't1',
        storeId: 's1',
        walletId: 'w1',
        transactionType: TransactionType.deposit,
        amount: 100.0,
        commission: 5.0,
        createdAt: DateTime.now(),
        createdBy: 'o1',
      );

      final mockWallet = WalletModel.fromWalletStatus(
        walletId: 'w1',
        storeId: 's1',
        phoneNumber: '01000000000',
        walletType: WalletType.vodafoneCash.name,
        walletStatus: WalletStatus.active.name,
        balance: 1000.0,
        createdBy: 'owner1',
      );

      when(() => mockAuth.currentUser).thenReturn(owner);
      when(() => mockAuth.isOwner).thenReturn(true);
      when(() => mockTxRepo.getTransactionById('t1', expectedStoreId: 's1'))
          .thenAnswer((_) async => mockTx);
      when(() => mockWalletRepo.getWalletById('w1', expectedStoreId: 's1'))
          .thenAnswer((_) async => mockWallet);
      when(() => mockWalletProvider.isWalletFrozenSync('w1')).thenReturn(true);

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        walletRepository: mockWalletRepo,
        storeId: 's1',
      );
      provider.updateAuthState(mockAuth);
      provider.updateWalletProvider(mockWalletProvider);

      // Act
      final result = await provider.updateTransaction('t1', {'amount': 150.0});

      // Assert
      expect(result, isFalse);
      expect(provider.hasError, isTrue);
      expect(provider.errorMessage, equals('wallet_is_frozen'));
    });
  });
}
