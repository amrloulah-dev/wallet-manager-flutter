import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:walletmanager/core/sms_automation/strategies/vodafone_cash_strategy.dart';
import 'package:walletmanager/core/sms_automation/utils/text_normalizer.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';
import 'package:walletmanager/domain/usecases/wallet_usecase.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/services/wallet_cache_manager.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/data/models/wallet_model.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockWalletRepository extends Mock implements WalletRepository {}
class MockWalletCacheManager extends Mock implements WalletCacheManager {}
class MockWalletUseCase extends Mock implements WalletUseCase {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockPlatformSettingsProvider extends Mock implements PlatformSettingsProvider {}
class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  final sl = GetIt.instance;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(TransactionModel(
      transactionId: 'fallback_id',
      storeId: 'store_1',
      walletId: 'w1',
      transactionType: TransactionType.debit,
      amount: 200.0,
      serviceFee: 1.0,
      createdBy: 'user_1',
    ));
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    FirebaseService().initializeForTest(FakeFirebaseFirestore());
    sl.reset();
  });

  tearDown(() {
    sl.reset();
  });

  group('AutoSMS Amount vs Service Fee Mismatch Fix', () {
    test('1. VodafoneCashStrategy extracts pure net amount from SMS', () {
      final strategy = VodafoneCashStrategy();
      const body = 'تم تحويل مبلغ 200 جنيه إلى رقم 01112345678';
      final normalized = TextNormalizer.normalize(body);
      final result = strategy.parse(normalized);

      expect(result, isNotNull);
      expect(result!.amount, 200.0,
          reason: 'Parsed SMS amount MUST be the net 200 EGP principal amount');
      expect(result.type.name, 'debit');
      expect(result.counterpartyNumber, '01112345678');
    });

    test('2. OverlayUseCase saves net amount (200 EGP) and service fee (2.5 EGP) as distinct fields in vault', () async {
      final mockTxRepo = MockTransactionRepository();
      final mockStorage = MockLocalStorageService();
      final mockSettingsProvider = MockPlatformSettingsProvider();

      sl.registerSingleton<PlatformSettingsProvider>(mockSettingsProvider);
      when(() => mockSettingsProvider.settings)
          .thenReturn(const PlatformSettingsModel.defaults());
      when(() => mockTxRepo.generateId()).thenReturn('tx_200_test');
      when(() => mockTxRepo.createTransaction(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveCompletedTxSync(any()))
          .thenAnswer((_) async {});

      final overlayUseCase = OverlayUseCase(
        transactionRepository: mockTxRepo,
        localStorage: mockStorage,
      );

      final availableWallets = [
        {
          'id': 'w1',
          'walletType': 'vodafone_cash',
          'isFrozen': false,
        }
      ];

      final result = await overlayUseCase.execute(
        storeId: 'store_1',
        userId: 'user_1',
        userName: 'Store Owner',
        userRole: 'owner',
        selectedWalletId: 'w1',
        type: 'debit',
        amount: 500.0,
        commission: 0.0,
        sender: '01112345678', // Cross-network -> 0.5% fee = 2.5 EGP
        availableWallets: availableWallets,
      );

      expect(result.totalDeduction, 502.5);

      final capturedVaultMap =
          verify(() => mockStorage.saveCompletedTxSync(captureAny()))
              .captured
              .first as Map<String, dynamic>;

      expect(capturedVaultMap['amount'], 500.0,
          reason: 'Vault amount field MUST store net principal amount (500 EGP)');
      expect(capturedVaultMap['serviceFee'], 2.5,
          reason: 'Vault serviceFee field MUST store fee (2.5 EGP)');
      expect(capturedVaultMap['totalDeduction'], 502.5,
          reason: 'Vault totalDeduction MUST store amount + serviceFee (502.5 EGP)');
    });

    test('3. WalletProvider.updateLocalBalance deducts amount + serviceFee from balance while tracking net amount', () async {
      final mockAuth = MockAuthProvider();
      final mockWalletRepo = MockWalletRepository();
      final mockTxRepo = MockTransactionRepository();
      final mockCacheManager = MockWalletCacheManager();
      final mockWalletUseCase = MockWalletUseCase();

      sl.registerSingleton<TransactionRepository>(mockTxRepo);
      sl.registerSingleton<WalletCacheManager>(mockCacheManager);

      when(() => mockCacheManager.cacheWallets(any())).thenAnswer((_) async {});
      when(() => mockWalletUseCase.calculateFrozenWallets(
            wallets: any(named: 'wallets'),
            subscriptionProvider: any(named: 'subscriptionProvider'),
            storeId: any(named: 'storeId'),
          )).thenReturn(<String>{});

      final user = UserModel(
        userId: 'u1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Owner',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      when(() => mockAuth.currentStoreId).thenReturn('s1');
      when(() => mockAuth.isOwner).thenReturn(true);
      when(() => mockAuth.currentUser).thenReturn(user);

      final initialWallet = WalletModel(
        walletId: 'w1',
        storeId: 's1',
        phoneNumber: '01012345678',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 1000.0,
        isActive: true,
        createdBy: 'u1',
        sendLimits: WalletLimits(
            dailyLimit: 10000, dailyUsed: 0, monthlyLimit: 50000, monthlyUsed: 0),
        receiveLimits: WalletLimits(
            dailyLimit: 10000, dailyUsed: 0, monthlyLimit: 50000, monthlyUsed: 0),
        stats: WalletStats(
            totalTransactions: 0,
            totalSentAmount: 0,
            totalReceivedAmount: 0),
      );

      when(() => mockWalletRepo.getAllWallets('s1')).thenAnswer((_) async =>
          PaginatedResult<WalletModel>(
              items: [initialWallet], lastDocument: null));

      final provider = WalletProvider(
        authProvider: mockAuth,
        walletRepository: mockWalletRepo,
        transactionRepository: mockTxRepo,
        cacheManager: mockCacheManager,
        walletUseCase: mockWalletUseCase,
        storeId: 's1',
      );

      await provider.fetchInitialWallets();

      // Deduct 200 EGP with 1 EGP service fee
      provider.updateLocalBalance('w1', 200.0, 'debit', serviceFee: 1.0);

      final updatedWallet = provider.walletMap['w1']!;
      expect(updatedWallet.balance, 799.0,
          reason: '1000 - (200 + 1) = 799 EGP balance');
      expect(updatedWallet.sendLimits.dailyUsed, 200.0,
          reason: 'Daily used limit MUST increase by net amount 200 EGP, not total deduction');
      expect(provider.isFetchShieldActive, isTrue,
          reason: 'updateLocalBalance MUST activate fetch shield for 5s to prevent stale overwrite');
    });
  });
}
