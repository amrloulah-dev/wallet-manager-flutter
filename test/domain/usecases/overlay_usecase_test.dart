import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

void main() {
  final sl = GetIt.instance;
  late MockTransactionRepository mockTxRepo;
  late MockLocalStorageService mockStorage;
  late MockPlatformSettingsProvider mockSettingsProvider;
  late OverlayUseCase overlayUseCase;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(TransactionModel(
      transactionId: 'fallback_id',
      storeId: 'store_1',
      walletId: 'w1',
      transactionType: TransactionType.credit,
      amount: 100.0,
      createdBy: 'user_1',
    ));
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    FirebaseService().initializeForTest(FakeFirebaseFirestore());
    sl.reset();
    mockTxRepo = MockTransactionRepository();
    mockStorage = MockLocalStorageService();
    mockSettingsProvider = MockPlatformSettingsProvider();

    sl.registerSingleton<PlatformSettingsProvider>(mockSettingsProvider);

    when(() => mockSettingsProvider.settings)
        .thenReturn(const PlatformSettingsModel.defaults());

    when(() => mockTxRepo.generateId()).thenReturn('generated_tx_123');
    when(() => mockTxRepo.createTransaction(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveToVault(any())).thenAnswer((_) async {});

    overlayUseCase = OverlayUseCase(
      transactionRepository: mockTxRepo,
      localStorage: mockStorage,
    );
  });

  tearDown(() {
    sl.reset();
  });

  test('execute() for credit (incoming) transaction sets serviceFee to 0.0',
      () async {
    final availableWallets = [
      {
        'id': 'w1',
        'walletType': 'vodafone_cash',
        'isFrozen': false,
      }
    ];

    final result = await overlayUseCase.execute(
      storeId: 'store_123',
      userId: 'user_123',
      userName: 'Test Owner',
      userRole: 'owner',
      selectedWalletId: 'w1',
      type: 'credit',
      amount: 500.0,
      commission: 80.0,
      sender:
          '01112345678', // Cross-network phone (Etisalat number to Vodafone wallet)
      availableWallets: availableWallets,
    );

    // Verify created transaction passed to repository has serviceFee = 0.0
    final captured = verify(() => mockTxRepo.createTransaction(captureAny()))
        .captured
        .first as TransactionModel;

    expect(captured.transactionType, TransactionType.credit);
    expect(captured.amount, 500.0);
    expect(captured.commission, 80.0);
    expect(captured.serviceFee, 0.0,
        reason: 'Credit transactions MUST have 0.0 service fee');
    expect(captured.totalAmount, 580.0);
    expect(result.totalDeduction, 500.0,
        reason: 'Vault totalDeduction for credit must not include serviceFee');
  });

  test(
      'execute() for debit (outgoing) transaction calculates cross-network serviceFee',
      () async {
    final availableWallets = [
      {
        'id': 'w1',
        'walletType': 'vodafone_cash',
        'isFrozen': false,
      }
    ];

    final result = await overlayUseCase.execute(
      storeId: 'store_123',
      userId: 'user_123',
      userName: 'Test Owner',
      userRole: 'owner',
      selectedWalletId: 'w1',
      type: 'debit',
      amount: 500.0,
      commission: 10.0,
      sender:
          '01112345678', // Cross-network phone (Etisalat number from Vodafone wallet)
      availableWallets: availableWallets,
    );

    // Verify created transaction passed to repository has calculated cross-network serviceFee (500 * 0.5% = 2.5 EGP)
    final captured = verify(() => mockTxRepo.createTransaction(captureAny()))
        .captured
        .first as TransactionModel;

    expect(captured.transactionType, TransactionType.debit);
    expect(captured.amount, 500.0);
    expect(captured.commission, 10.0);
    expect(captured.serviceFee, 2.5,
        reason:
            'Debit transactions must compute service fee (500 * 0.005 = 2.5)');
    expect(result.totalDeduction, 502.5,
        reason: 'Vault totalDeduction for debit includes amount + serviceFee');
  });
}
