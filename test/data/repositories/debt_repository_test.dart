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

  group('DebtRepository - Query Filtering (BUG-02)', () {
    test(
        'getDebtsByDateRange should filter by debtType and debtStatus correctly',
        () async {
      final storeId = 's1';
      final startDate = DateTime.now().subtract(const Duration(days: 5));
      final endDate = DateTime.now().add(const Duration(days: 5));

      // Add a mix of debts
      // 1. Store Sale & Open
      await fakeFirestore.collection(FirebaseConstants.debts).doc('d1').set({
        'debtId': 'd1',
        'storeId': storeId,
        'amountDue': 100.0,
        'totalAmount': 100.0,
        'debtStatus': 'open',
        'debtType': 'storeSale',
        'customerName': 'Cust 1',
        'customerPhone': '123',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'debtDate': Timestamp.fromDate(DateTime.now()),
      });

      // 2. Transaction & Paid
      await fakeFirestore.collection(FirebaseConstants.debts).doc('d2').set({
        'debtId': 'd2',
        'storeId': storeId,
        'amountDue': 0.0,
        'totalAmount': 100.0,
        'debtStatus': 'paid',
        'debtType': 'transaction',
        'customerName': 'Cust 2',
        'customerPhone': '123',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'debtDate': Timestamp.fromDate(DateTime.now()),
      });

      // 3. Store Sale & Paid
      await fakeFirestore.collection(FirebaseConstants.debts).doc('d3').set({
        'debtId': 'd3',
        'storeId': storeId,
        'amountDue': 0.0,
        'totalAmount': 150.0,
        'debtStatus': 'paid',
        'debtType': 'storeSale',
        'customerName': 'Cust 3',
        'customerPhone': '123',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'debtDate': Timestamp.fromDate(DateTime.now()),
      });

      // Query 1: Filter by Store Sale & Open
      final res1 = await repository.getDebtsByDateRange(
        storeId,
        startDate,
        endDate,
        debtType: 'storeSale',
        debtStatus: 'open',
      );
      expect(res1.items.length, 1);
      expect(res1.items.first.debtId, 'd1');

      // Query 2: Filter by Paid (any type)
      final res2 = await repository.getDebtsByDateRange(
        storeId,
        startDate,
        endDate,
        debtType: 'all',
        debtStatus: 'paid',
      );
      expect(res2.items.length, 2);
      expect(res2.items.any((d) => d.debtId == 'd2'), true);
      expect(res2.items.any((d) => d.debtId == 'd3'), true);

      // Query 3: Filter by Store Sale (any status)
      final res3 = await repository.getDebtsByDateRange(
        storeId,
        startDate,
        endDate,
        debtType: 'storeSale',
        debtStatus: 'all',
      );
      expect(res3.items.length, 2);
      expect(res3.items.any((d) => d.debtId == 'd1'), true);
      expect(res3.items.any((d) => d.debtId == 'd3'), true);
    });
  });
}
