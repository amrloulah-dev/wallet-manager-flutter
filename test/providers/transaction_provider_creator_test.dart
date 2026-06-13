import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
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

class MockEmployeeProvider extends Mock implements EmployeeProvider {}

class FakeTransactionModel extends Fake implements TransactionModel {}

void main() {
  late MockTransactionRepository mockTxRepo;
  late MockWalletRepository mockWalletRepo;
  late MockAuthProvider mockAuth;
  late MockWalletProvider mockWalletProvider;
  late MockEmployeeProvider mockEmployeeProvider;

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
    mockEmployeeProvider = MockEmployeeProvider();

    final sl = GetIt.instance;
    late MockStatsRepository mockStats;
    if (!sl.isRegistered<StatsRepository>()) {
      mockStats = MockStatsRepository();
      sl.registerLazySingleton<StatsRepository>(() => mockStats);
    } else {
      mockStats = sl<StatsRepository>() as MockStatsRepository;
    }
    when(() => mockStats.fetchTodayStats(any()))
        .thenAnswer((_) async => DailyStatsModel.empty('2026-06-13'));

    when(() => mockAuth.currentStoreId).thenReturn('s1');
    when(() => mockWalletProvider.walletMap)
        .thenReturn(<String, WalletModel>{});
  });

  group('TransactionProvider Creator Name and Role Tests', () {
    test(
        'createTransaction should populate createdByName and creatorRole from EmployeeProvider when user is an employee',
        () async {
      // Arrange
      final employeeUser = UserModel(
        userId: 'emp1',
        storeId: 's1',
        role: UserRole.employee,
        fullName: 'Test Employee Name',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        permissions: UserPermissions(createTransaction: true),
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

      when(() => mockAuth.currentUser).thenReturn(employeeUser);
      when(() => mockAuth.isOwner).thenReturn(false);
      when(() => mockWalletRepo.getWalletById('w1', expectedStoreId: 's1'))
          .thenAnswer((_) async => mockWallet);
      when(() => mockWalletProvider.isWalletFrozenSync('w1')).thenReturn(false);
      when(() => mockEmployeeProvider.getEmployeeById('emp1'))
          .thenReturn(employeeUser);

      TransactionModel? capturedTx;
      when(() => mockTxRepo.createTransaction(any()))
          .thenAnswer((invocation) async {
        capturedTx = invocation.positionalArguments[0] as TransactionModel;
      });

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        walletRepository: mockWalletRepo,
        storeId: 's1',
      );
      provider.updateAuthState(mockAuth);
      provider.updateWalletProvider(mockWalletProvider);
      provider.updateEmployeeProvider(mockEmployeeProvider);

      // Act
      final result = await provider.createTransaction(
        walletId: 'w1',
        amount: 100.0,
        commission: 5.0,
        transactionType: TransactionType.deposit,
      );

      // Assert
      expect(result, isTrue);
      expect(capturedTx, isNotNull);
      expect(capturedTx!.createdByName, equals('Test Employee Name'));
      expect(capturedTx!.creatorRole, equals('employee'));
    });

    test(
        'createTransaction should fall back to AuthProvider when EmployeeProvider returns null (e.g. for store owner)',
        () async {
      // Arrange
      final ownerUser = UserModel(
        userId: 'owner1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Test Owner Name',
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

      when(() => mockAuth.currentUser).thenReturn(ownerUser);
      when(() => mockAuth.isOwner).thenReturn(true);
      when(() => mockWalletRepo.getWalletById('w1', expectedStoreId: 's1'))
          .thenAnswer((_) async => mockWallet);
      when(() => mockWalletProvider.isWalletFrozenSync('w1')).thenReturn(false);
      when(() => mockEmployeeProvider.getEmployeeById('owner1'))
          .thenReturn(null);

      TransactionModel? capturedTx;
      when(() => mockTxRepo.createTransaction(any()))
          .thenAnswer((invocation) async {
        capturedTx = invocation.positionalArguments[0] as TransactionModel;
      });

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        walletRepository: mockWalletRepo,
        storeId: 's1',
      );
      provider.updateAuthState(mockAuth);
      provider.updateWalletProvider(mockWalletProvider);
      provider.updateEmployeeProvider(mockEmployeeProvider);

      // Act
      final result = await provider.createTransaction(
        walletId: 'w1',
        amount: 100.0,
        commission: 5.0,
        transactionType: TransactionType.deposit,
      );

      // Assert
      expect(result, isTrue);
      expect(capturedTx, isNotNull);
      expect(capturedTx!.createdByName, equals('Test Owner Name'));
      expect(capturedTx!.creatorRole, equals('owner'));
    });

    test(
        'createTransaction should use a sensible fallback if both providers return null or empty',
        () async {
      // Arrange
      final anonymousUser = UserModel(
        userId: 'unknown1',
        storeId: 's1',
        role: UserRole.employee,
        fullName: '', // empty name
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        permissions: UserPermissions(createTransaction: true),
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

      when(() => mockAuth.currentUser).thenReturn(anonymousUser);
      when(() => mockAuth.isOwner).thenReturn(false);
      when(() => mockWalletRepo.getWalletById('w1', expectedStoreId: 's1'))
          .thenAnswer((_) async => mockWallet);
      when(() => mockWalletProvider.isWalletFrozenSync('w1')).thenReturn(false);
      when(() => mockEmployeeProvider.getEmployeeById('unknown1'))
          .thenReturn(null);

      TransactionModel? capturedTx;
      when(() => mockTxRepo.createTransaction(any()))
          .thenAnswer((invocation) async {
        capturedTx = invocation.positionalArguments[0] as TransactionModel;
      });

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        walletRepository: mockWalletRepo,
        storeId: 's1',
      );
      provider.updateAuthState(mockAuth);
      provider.updateWalletProvider(mockWalletProvider);
      provider.updateEmployeeProvider(mockEmployeeProvider);

      // Act
      final result = await provider.createTransaction(
        walletId: 'w1',
        amount: 100.0,
        commission: 5.0,
        transactionType: TransactionType.deposit,
      );

      // Assert
      expect(result, isTrue);
      expect(capturedTx, isNotNull);
      expect(capturedTx!.createdByName, equals('Store Member'));
      expect(capturedTx!.creatorRole, equals('employee'));
    });
  });
}
