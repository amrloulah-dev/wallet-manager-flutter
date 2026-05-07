import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/core/enums/debt_enums.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

class MockCacheManager extends Mock implements CacheManager {}

void main() {
  late DebtRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();

    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);

    repository = DebtRepository(
      firebaseService: mockFirebaseService,
      cacheManager: mockCacheManager,
    );
  });

  group('DebtRepository Atomic Decrement Verification', () {
    test('createDebt should increment stats atomically using WriteBatch',
        () async {
      final storeId = 's1';
      final debtId = 'd0';
      final statsPath = FirebaseConstants.statsSummaryPath(storeId);

      // Setup initial stats
      await fakeFirestore.doc(statsPath).set({
        'openDebtsCount': 0,
        'totalOpenAmount': 0.0,
      });

      final debt = DebtModel(
        debtId: debtId,
        storeId: storeId,
        amountDue: 200.0,
        totalAmount: 200.0,
        debtStatus: DebtStatus.open,
        customerName: 'New Customer',
        customerPhone: '456',
        debtType: DebtType.storeSale,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        debtDate: DateTime.now(),
      );

      // Execute
      await repository.createDebt(debt);

      // Verify
      final debtSnap = await fakeFirestore
          .collection(FirebaseConstants.debts)
          .doc(debtId)
          .get();
      expect(debtSnap.exists, true);

      final statsSnap = await fakeFirestore.doc(statsPath).get();
      expect(statsSnap.data()?['openDebtsCount'], 1);
      expect(statsSnap.data()?['totalOpenAmount'], 200.0);
    });

    test(
        'processPayment should decrement openDebtsCount atomically on full payment',
        () async {
      final storeId = 's1';
      final debtId = 'd1';
      final userId = 'u1';
      final statsPath = FirebaseConstants.statsSummaryPath(storeId);

      // Setup initial state
      await fakeFirestore.collection(FirebaseConstants.debts).doc(debtId).set({
        'debtId': debtId,
        'storeId': storeId,
        'amountDue': 100.0,
        'totalAmount': 100.0,
        'debtStatus': DebtStatus.open.name,
        'customerName': 'Customer',
        'customerPhone': '123',
        'debtDate': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.doc(statsPath).set({
        'openDebtsCount': 5,
        'totalOpenAmount': 500.0,
      });

      // Execute full payment
      await repository.processPayment(debtId, 100.0, userId);

      // Verify final state
      final statsSnap = await fakeFirestore.doc(statsPath).get();
      expect(statsSnap.data()?['openDebtsCount'], 4);
    });

    test('deleteDebt should decrement openDebtsCount atomically for open debt',
        () async {
      final storeId = 's1';
      final debtId = 'd2';
      final statsPath = FirebaseConstants.statsSummaryPath(storeId);

      // Setup initial state
      await fakeFirestore.collection(FirebaseConstants.debts).doc(debtId).set({
        'debtId': debtId,
        'storeId': storeId,
        'amountDue': 50.0,
        'totalAmount': 50.0,
        'debtStatus': DebtStatus.open.name,
        'customerName': 'Customer',
        'customerPhone': '123',
        'debtDate': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.doc(statsPath).set({
        'openDebtsCount': 3,
        'totalOpenAmount': 150.0,
      });

      // Execute delete
      await repository.deleteDebt(debtId);

      // Verify final state
      final statsSnap = await fakeFirestore.doc(statsPath).get();
      expect(statsSnap.data()?['openDebtsCount'], 2);
    });
  });
}
