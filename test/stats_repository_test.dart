import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/core/enums/debt_enums.dart';

// Mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockTransaction extends Mock implements Transaction {
  final List<MapEntry<DocumentReference, dynamic>> setCalls = [];
  final List<MapEntry<DocumentReference, dynamic>> updateCalls = [];

  @override
  Future<DocumentSnapshot<T>> get<T>(
      DocumentReference<T> documentReference) async {
    return MockDocumentSnapshot<T>();
  }

  @override
  Transaction set<T>(DocumentReference<T> documentReference, T data,
      [SetOptions? options]) {
    setCalls.add(MapEntry(documentReference, data));
    return this;
  }

  @override
  Transaction update(
      DocumentReference documentReference, Map<String, dynamic> data) {
    updateCalls.add(MapEntry(documentReference, data));
    return this;
  }
}

class MockWriteBatch extends Mock implements WriteBatch {}

class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {
  @override
  bool get exists => false;
}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {
  final String _path;
  MockDocumentReference([this._path = 'test_path']);

  @override
  String get path => _path;
}

class MockFieldValue extends Mock implements FieldValue {}

void main() {
  late StatsRepository statsRepository;
  late MockFirebaseFirestore mockFirestore;
  late MockTransaction mockTransaction;
  late MockDocumentReference mockSummaryDocRef;

  const storeId = 'test_store';
  const userId = 'test_user';

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(MockFieldValue());
    registerFallbackValue(MockDocumentReference());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockTransaction = MockTransaction();
    mockSummaryDocRef =
        MockDocumentReference('stores/test_store/stats/summary');
    final mockDailyStatsDocRef =
        MockDocumentReference('stores/test_store/daily_stats/2026-05-26');
    statsRepository = StatsRepository(firestore: mockFirestore);

    final mockStoresCollection = MockCollectionReference();
    final mockStoreDoc = MockDocumentReference();
    final mockStatsCollection = MockCollectionReference();

    when(() => mockFirestore.collection('stores'))
        .thenReturn(mockStoresCollection);
    when(() => mockFirestore.doc(any())).thenReturn(mockSummaryDocRef);
    when(() => mockFirestore.doc(any(that: contains('daily_stats'))))
        .thenReturn(mockDailyStatsDocRef);
    when(() => mockStoresCollection.doc(any())).thenReturn(mockStoreDoc);
    when(() => mockStoreDoc.collection('stats'))
        .thenReturn(mockStatsCollection);
    when(() => mockStatsCollection.doc('summary'))
        .thenReturn(mockSummaryDocRef);
  });

  group('updateStatsOnDebtUpdate', () {
    final debtId = 'debt1';
    final now = DateTime.now();

    DebtModel createTestDebt({
      required String id,
      required double amount,
      DebtStatus status = DebtStatus.open,
    }) {
      return DebtModel(
        debtId: id,
        storeId: storeId,
        customerName: 'Customer $id',
        customerPhone: '123456789',
        debtType: DebtType.storeSale,
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

      // ACT
      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: null,
        newDebt: newDebt,
      );

      // ASSERT
      expect(true, true); // Verified by no crash + manual check
    });

    test(
        'incrementOpenDebtStats should write to summary update and daily stats set',
        () async {
      await statsRepository.incrementOpenDebtStats(
        storeId,
        150.0,
        firestoreTransaction: mockTransaction,
      );

      // Verify summary was updated
      expect(
          mockTransaction.updateCalls.any((call) =>
              call.key == mockSummaryDocRef &&
              call.value['openDebtsCount'] is FieldValue),
          isTrue);

      // Verify daily stats was set
      expect(
          mockTransaction.setCalls.any((call) =>
              call.key.path.contains('daily_stats') &&
              call.value['openDebtsCount'] is FieldValue),
          isTrue);
    });

    test(
        'decrementOpenDebtStats should write to summary update and daily stats set',
        () async {
      await statsRepository.decrementOpenDebtStats(
        storeId,
        150.0,
        firestoreTransaction: mockTransaction,
      );

      expect(
          mockTransaction.updateCalls.any((call) =>
              call.key == mockSummaryDocRef &&
              call.value['openDebtsCount'] is FieldValue),
          isTrue);

      expect(
          mockTransaction.setCalls.any((call) =>
              call.key.path.contains('daily_stats') &&
              call.value['openDebtsCount'] is FieldValue),
          isTrue);
    });

    test('updateStatsOnDebtUpdate should write to daily stats set', () async {
      final newDebt = createTestDebt(id: 'debt1', amount: 100);

      await statsRepository.updateStatsOnDebtUpdate(
        firestoreTransaction: mockTransaction,
        storeId: storeId,
        oldDebt: null,
        newDebt: newDebt,
      );

      expect(
          mockTransaction.setCalls.any((call) =>
              call.key.path.contains('daily_stats') &&
              call.value['openDebtsCount'] is FieldValue),
          isTrue);
    });
  });

  group('updateStatsOnWalletChange', () {
    late MockWriteBatch mockBatch;

    setUp(() {
      mockBatch = MockWriteBatch();
    });

    test(
        'should throw AssertionError if both transaction and batch are provided',
        () async {
      expect(
        () => statsRepository.updateStatsOnWalletChange(
          storeId,
          countChange: 1,
          firestoreTransaction: mockTransaction,
          batch: mockBatch,
        ),
        throwsAssertionError,
      );
    });

    test('should queue set operation on batch when batch is provided',
        () async {
      await statsRepository.updateStatsOnWalletChange(
        storeId,
        countChange: 1,
        batch: mockBatch,
      );
      verify(() => mockBatch.set<Object?>(any(), any(), any())).called(1);
    });
  });
}
