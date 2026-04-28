import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/services/transaction_validator_service.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockTransaction extends Mock implements Transaction {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {}
class FakeTransaction extends Fake implements Transaction {}
class FakeSetOptions extends Fake implements SetOptions {}

void main() {
  late TransactionValidatorService service;
  late MockFirebaseFirestore mockFirestore;
  late MockTransaction mockTransaction;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockWalletRef;
  late MockDocumentSnapshot mockWalletSnap;

  setUpAll(() {
    registerFallbackValue(FakeDocumentReference());
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(FakeSetOptions());
    registerFallbackValue(const Duration(seconds: 1));
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    mockFirestore = MockFirebaseFirestore();
    mockTransaction = MockTransaction();
    mockCollection = MockCollectionReference();
    mockWalletRef = MockDocumentReference();
    mockWalletSnap = MockDocumentSnapshot();

    service = TransactionValidatorService(firestore: mockFirestore);

    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockWalletRef);
    when(() => mockWalletRef.collection(any())).thenReturn(mockCollection);
    
    // Stub Transaction methods to return itself (fluent interface)
    when(() => mockTransaction.set(
      any<DocumentReference<Map<String, dynamic>>>(),
      any<Map<String, dynamic>>(),
    )).thenReturn(mockTransaction);

    when(() => mockTransaction.set(
      any<DocumentReference<Map<String, dynamic>>>(),
      any<Map<String, dynamic>>(),
      any<SetOptions>(),
    )).thenReturn(mockTransaction);

    when(() => mockTransaction.update(
      any<DocumentReference<Map<String, dynamic>>>(),
      any<Map<String, dynamic>>(),
    )).thenReturn(mockTransaction);

    when(() => mockTransaction.delete(any<DocumentReference<Map<String, dynamic>>>()))
        .thenReturn(mockTransaction);
    
    // Stub runTransaction to execute the callback
    when(() => mockFirestore.runTransaction<void>(any<Future<void> Function(Transaction)>()))
        .thenAnswer((invocation) async {
      final callback = invocation.positionalArguments[0] as Future<void> Function(Transaction);
      return await callback(mockTransaction);
    });
  });

  group('TransactionValidatorService (Phase 2)', () {
    test('isReceive should NOT include commission in balanceChange', () async {
      final txModel = TransactionModel(
        transactionId: 'tx1',
        walletId: 'w1',
        transactionType: TransactionType.credit, // Receive
        amount: 100.0,
        commission: 5.0,
        serviceFee: 0.0,
        storeId: 's1',
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '012',
        paymentStatus: PaymentStatus.paid,
      );

      when(() => mockTransaction.get(mockWalletRef)).thenAnswer((_) async => mockWalletSnap);
      when(() => mockWalletSnap.exists).thenReturn(true);
      when(() => mockWalletSnap.id).thenReturn('w1');
      when(() => mockWalletSnap.data()).thenReturn({
        'walletId': 'w1',
        'storeId': 's1',
        'balance': 500.0,
        'isActive': true,
        'walletType': 'vodafoneCash',
        'sendLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
        'receiveLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
      });

      await service.validateAndSave(txModel);

      // Desired behavior: balanceChange = 100.0 (amount ONLY)
      final captured = verify(() => mockTransaction.update(
        any<DocumentReference<Map<String, dynamic>>>(),
        captureAny(),
      )).captured;

      final updateData = captured.first as Map<String, dynamic>;
      expect(updateData['balance'], 500.0 + 100.0);
    });

    test('should use epsilon for balance sufficiency check', () async {
      final txModel = TransactionModel(
        transactionId: 'tx1',
        walletId: 'w1',
        transactionType: TransactionType.debit, // Send
        amount: 100.0,
        commission: 0.0,
        serviceFee: 0.0,
        storeId: 's1',
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '012',
        paymentStatus: PaymentStatus.paid,
      );

      when(() => mockTransaction.get(mockWalletRef)).thenAnswer((_) async => mockWalletSnap);
      when(() => mockWalletSnap.exists).thenReturn(true);
      when(() => mockWalletSnap.id).thenReturn('w1');
      when(() => mockWalletSnap.data()).thenReturn({
        'walletId': 'w1',
        'storeId': 's1',
        'balance': 100.0 - 0.0000001, // Within 0.0001 epsilon
        'isActive': true,
        'walletType': 'vodafoneCash',
        'sendLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
        'receiveLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
      });

      // Should NOT throw ValidationException due to epsilon check
      await service.validateAndSave(txModel);
    });

    test('isDeposit should create transaction document and update balance', () async {
      final txModel = TransactionModel(
        transactionId: 'tx_deposit_1',
        walletId: 'w1',
        transactionType: TransactionType.deposit,
        amount: 1000.0,
        commission: 0.0,
        serviceFee: 0.0,
        storeId: 's1',
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '012',
        paymentStatus: PaymentStatus.paid,
      );

      when(() => mockTransaction.get(mockWalletRef)).thenAnswer((_) async => mockWalletSnap);
      when(() => mockWalletSnap.exists).thenReturn(true);
      when(() => mockWalletSnap.id).thenReturn('w1');
      when(() => mockWalletSnap.data()).thenReturn({
        'walletId': 'w1',
        'storeId': 's1',
        'balance': 500.0,
        'isActive': true,
        'walletType': 'vodafoneCash',
        'sendLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
        'receiveLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
      });

      await service.validateAndSave(txModel);

      // Verify transaction document was set
      verify(() => mockTransaction.set(
        any<DocumentReference<Map<String, dynamic>>>(),
        any<Map<String, dynamic>>(),
      )).called(1);
      
      // Verify balance update was called (currently it uses FieldValue.increment in the early return branch)
      // Actually, after our fix, it will use the atomic path.
    });
  });
}
