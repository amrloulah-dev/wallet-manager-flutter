import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';

// Mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockTransaction extends Mock implements Transaction {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockFieldValue extends Mock implements FieldValue {}

class MockCollectionReferenceWithDoc extends Mock
    implements CollectionReference<Map<String, dynamic>> {
  final MockDocumentReference mockDocRef;
  MockCollectionReferenceWithDoc(this.mockDocRef);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return mockDocRef;
  }
}

void main() {
  late StatsRepository statsRepository;
  late MockFirebaseFirestore mockFirestore;
  late MockTransaction mockTransaction;
  late MockDocumentReference mockSummaryDocRef;
  late MockDocumentSnapshot mockSummaryDocSnapshot;

  const storeId = 'test_store';
  const userId = 'test_user';

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockTransaction = MockTransaction();
    mockSummaryDocRef = MockDocumentReference();
    mockSummaryDocSnapshot = MockDocumentSnapshot();
    statsRepository = StatsRepository(firestore: mockFirestore);

    // Setup mock Firestore hierarchy
    final mockStatsCollectionRef =
        MockCollectionReferenceWithDoc(mockSummaryDocRef);
    final mockStoresCollectionRef =
        MockCollectionReferenceWithDoc(mockSummaryDocRef);
    when(() => mockFirestore.collection(any()))
        .thenReturn(mockStoresCollectionRef);
    when(() => mockStoresCollectionRef.doc(any()))
        .thenReturn(mockSummaryDocRef);
    when(() => mockSummaryDocRef.collection(any()))
        .thenReturn(mockStatsCollectionRef);

    // Register fallback values
    registerFallbackValue(mockSummaryDocRef);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(MockFieldValue());
  });

  // Helper to setup mocks for a transaction run
  void setupMocksForTransaction(
      {bool docExists = true, Map<String, dynamic>? initialData}) {
    when(() => mockTransaction.get(mockSummaryDocRef))
        .thenAnswer((_) async => mockSummaryDocSnapshot);
    when(() => mockSummaryDocSnapshot.exists).thenReturn(docExists);
    if (docExists) {
      when(() => mockSummaryDocSnapshot.data())
          .thenReturn(initialData ?? StatsSummaryModel.empty().toMap());
    }
  }

  group('updateStatsOnDebtUpdate', () {
    final debtId = 'debt1';
    final now = Timestamp.now();

    DebtModel createTestDebt({
      required String id,
      required double amount,
      String status = 'open',
    }) {
      return DebtModel(
        debtId: id,
        storeId: storeId,
        customerName: 'Customer $id',
        customerPhone: '123456789',
        debtType: 'lend',
        amountDue: amount,
        totalAmount: amount,
        debtStatus: status,
        createdBy: userId,
        createdAt: now,
        debtDate: now,
      );
    }

    test('should correctly increment stats when a new debt is created',
        () async {
      // ARRANGE
      final newDebt = createTestDebt(id: debtId, amount: 100);
      setupMocksForTransaction(docExists: false);
      when(() => mockTransaction.set(any(), any()))
          .thenAnswer((_) => mockTransaction);

      // ACT
      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: null,
        newDebt: newDebt,
      );

      // ASSERT
      final captured =
          verify(() => mockTransaction.set(mockSummaryDocRef, captureAny()))
              .captured
              .first as Map<String, dynamic>;
      expect(captured['openDebtsCount'], 1);
      expect(captured['totalOpenAmount'], 100.0);
      expect(captured['totalTransactions'], 1);
    });

    test('should correctly update stats for a partial payment', () async {
      // ARRANGE
      final oldDebt = createTestDebt(id: debtId, amount: 100);
      final newDebt = oldDebt.copyWith(amountDue: 50);
      setupMocksForTransaction(initialData: {
        'openDebtsCount': 1,
        'totalOpenAmount': 100.0,
        'totalPaidAmount': 0.0,
        'totalTransactions': 1,
        'paidDebtsCount': 0,
      });
      when(() => mockTransaction.update(any(), any()))
          .thenAnswer((_) => mockTransaction);

      // ACT
      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: oldDebt,
        newDebt: newDebt,
      );

      // ASSERT
      final captured =
          verify(() => mockTransaction.update(mockSummaryDocRef, captureAny()))
              .captured
              .first as Map<String, dynamic>;
      expect(captured['totalOpenAmount'], isA<FieldValue>());
      expect(captured['totalPaidAmount'], isA<FieldValue>());
      expect(captured['totalTransactions'], isA<FieldValue>());
      expect(captured['openDebtsCount'], isNull); // Count shouldn't change
    });

    test('should correctly update stats for a partial addition', () async {
      // ARRANGE
      final oldDebt = createTestDebt(id: debtId, amount: 50);
      final newDebt = oldDebt.copyWith(amountDue: 80);
      setupMocksForTransaction(initialData: {
        'openDebtsCount': 1,
        'totalOpenAmount': 50.0,
        'totalTransactions': 2,
        'paidDebtsCount': 0,
      });
      when(() => mockTransaction.update(any(), any()))
          .thenAnswer((_) => mockTransaction);

      // ACT
      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: oldDebt,
        newDebt: newDebt,
      );

      // ASSERT
      final captured =
          verify(() => mockTransaction.update(mockSummaryDocRef, captureAny()))
              .captured
              .first as Map<String, dynamic>;
      expect(captured['totalOpenAmount'], isA<FieldValue>());
      expect(captured['totalTransactions'], isA<FieldValue>());
      expect(captured['totalPaidAmount'], isNull); // No payment was made
      expect(captured['openDebtsCount'], isNull);
    });

    test('should correctly update stats for a full payment', () async {
      // ARRANGE
      final oldDebt = createTestDebt(id: debtId, amount: 100);
      final newDebt = oldDebt.copyWith(amountDue: 0, debtStatus: 'paid');
      setupMocksForTransaction(initialData: {
        'openDebtsCount': 1,
        'paidDebtsCount': 0,
        'totalOpenAmount': 100.0,
        'totalPaidAmount': 0.0,
        'totalTransactions': 1,
      });
      when(() => mockTransaction.update(any(), any()))
          .thenAnswer((_) => mockTransaction);

      // ACT
      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: oldDebt,
        newDebt: newDebt,
      );

      // ASSERT
      final captured =
          verify(() => mockTransaction.update(mockSummaryDocRef, captureAny()))
              .captured
              .first as Map<String, dynamic>;
      expect(captured['totalOpenAmount'], isA<FieldValue>());
      expect(captured['totalPaidAmount'], isA<FieldValue>());
      expect(captured['totalTransactions'], isA<FieldValue>());
      expect(captured['openDebtsCount'], isA<FieldValue>());
      expect(captured['paidDebtsCount'], isA<FieldValue>());
    });

    test('should correctly update stats when reopening a paid debt', () async {
      // ARRANGE
      final oldDebt = createTestDebt(id: debtId, amount: 0, status: 'paid');
      final newDebt = oldDebt.copyWith(amountDue: 25, debtStatus: 'open');
      setupMocksForTransaction(initialData: {
        'openDebtsCount': 0,
        'paidDebtsCount': 1,
        'totalOpenAmount': 0.0,
        'totalPaidAmount': 100.0,
        'totalTransactions': 2,
      });
      when(() => mockTransaction.update(any(), any()))
          .thenAnswer((_) => mockTransaction);

      // ACT
      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: oldDebt,
        newDebt: newDebt,
      );

      // ASSERT
      final captured =
          verify(() => mockTransaction.update(mockSummaryDocRef, captureAny()))
              .captured
              .first as Map<String, dynamic>;
      expect(captured['totalOpenAmount'], isA<FieldValue>());
      expect(captured['totalTransactions'], isA<FieldValue>());
      expect(captured['openDebtsCount'], isA<FieldValue>());
      expect(captured['paidDebtsCount'], isA<FieldValue>());
      expect(captured['totalPaidAmount'], isNull); // No direct payment change
    });

    test(
        'should correctly update stats when a fully paid debt is reopened with a new partial debt',
        () async {
      // ARRANGE
      final oldDebt = createTestDebt(id: debtId, amount: 0, status: 'paid');
      final newDebt = oldDebt.copyWith(amountDue: 50, debtStatus: 'open');

      setupMocksForTransaction(initialData: {
        'openDebtsCount': 0,
        'paidDebtsCount': 1,
        'totalOpenAmount': 0.0,
        'totalPaidAmount': 100.0, // Customer had previously paid 100
        'totalTransactions': 2,
      });
      when(() => mockTransaction.update(any(), any()))
          .thenAnswer((_) => mockTransaction);

      // ACT
      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: oldDebt,
        newDebt: newDebt,
      );

      // ASSERT
      final captured =
          verify(() => mockTransaction.update(mockSummaryDocRef, captureAny()))
              .captured
              .first as Map<String, dynamic>;

      // Verify that the FieldValue increments are correct
      expect(captured['openDebtsCount'].toString(), 'FieldValue(Increment(1))');
      expect(
          captured['paidDebtsCount'].toString(), 'FieldValue(Increment(-1))');
      expect(captured['totalOpenAmount'].toString(),
          'FieldValue(Increment(50.0))');
      expect(
          captured['totalTransactions'].toString(), 'FieldValue(Increment(1))');
      expect(captured['totalPaidAmount'],
          isNull); // No payment was made in this transaction
    });

    test('should create stats document if it does not exist on update',
        () async {
      // ARRANGE
      final oldDebt = createTestDebt(id: debtId, amount: 100);
      final newDebt = oldDebt.copyWith(amountDue: 50);
      setupMocksForTransaction(docExists: false); // Summary doc does NOT exist
      when(() => mockTransaction.set(any(), any()))
          .thenAnswer((_) => mockTransaction);

      // ACT
      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: oldDebt,
        newDebt: newDebt,
      );

      // ASSERT
      final captured =
          verify(() => mockTransaction.set(mockSummaryDocRef, captureAny()))
              .captured
              .first as Map<String, dynamic>;
      expect(captured['totalOpenAmount'], -50.0);
      expect(captured['totalPaidAmount'], 50.0);
      expect(captured['totalTransactions'], 1);
      expect(captured['openDebtsCount'], 0); // No change in count
      expect(captured['paidDebtsCount'], 0);
    });
  });
}
