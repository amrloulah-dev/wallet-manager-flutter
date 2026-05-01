import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DebtRepository repository;
  late MockFirebaseService mockFirebaseService;

  const storeId = 'test_store';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);

    repository = DebtRepository(firebaseService: mockFirebaseService);
  });

  group('DebtRepository Stateless Pagination', () {
    test('getDebtsByDateRange should be stateless and use passed lastDocument', () async {
      // 1. Seed data (25 debts)
      for (int i = 0; i < 25; i++) {
        final date = DateTime(2023, 1, 1).add(Duration(minutes: i));
        await fakeFirestore.collection(FirebaseConstants.debts).add({
          'storeId': storeId,
          'createdAt': Timestamp.fromDate(date),
          'debtDate': Timestamp.fromDate(date),
          'amountDue': 100.0,
          'totalAmount': 100.0,
          'customerName': 'Customer $i',
          'debtStatus': 'open',
          'debtType': 'transaction',
          'createdBy': 'user1',
          'customerPhone': '1234567890',
        });
      }

      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2023, 1, 2);

      // 2. Fetch first page (should return 20 items)
      final firstPage = await repository.getDebtsByDateRange(storeId, startDate, endDate);
      
      expect(firstPage.items.length, 20);
      expect(firstPage.lastDocument, isNotNull);
      
      final lastDocFirstPage = firstPage.lastDocument;

      // 3. Fetch second page using lastDocument
      final secondPage = await repository.getDebtsByDateRange(
        storeId, 
        startDate, 
        endDate, 
        lastDocument: lastDocFirstPage,
      );

      expect(secondPage.items.length, 5);
      expect(secondPage.lastDocument, isNotNull);
      
      // 4. Verify that fetching again without lastDocument still returns first page (statelessness)
      final firstPageAgain = await repository.getDebtsByDateRange(storeId, startDate, endDate);
      expect(firstPageAgain.items.first.customerName, firstPage.items.first.customerName);
    });
  });
}
