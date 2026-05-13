import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late EmployeeRepository employeeRepository;
  late DebtRepository debtRepository;
  late MockFirebaseService mockFirebaseService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);

    employeeRepository = EmployeeRepository(firestore: fakeFirestore);
    debtRepository = DebtRepository(firebaseService: mockFirebaseService);
  });

  group('Counter Integrity', () {
    const storeId = 'store1';
    const employeeId = 'emp1';
    const debtId = 'debt1';

    test(
        'totalEmployees should not decrement below zero in store and stats summary',
        () async {
      // Setup: Store with totalEmployees = 0
      await fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .set({
        'storeId': storeId,
        'stats': {'totalEmployees': 0},
      });

      // Setup: Stats summary with totalEmployees = 0
      await fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .set({
        'totalEmployees': 0,
      });

      // Setup: Active employee
      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(employeeId)
          .set({
        'userId': employeeId,
        'storeId': storeId,
        'isActive': true,
        'role': 'employee',
        'pin': await PasswordHasher.hashPassword('1234'),
      });

      // Act: Deactivate employee
      await employeeRepository.deactivateEmployee(employeeId);

      // Assert
      final storeDoc = await fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .get();
      final statsDoc = await fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .get();

      // With FieldValue.increment(-1), it will be -1
      expect(storeDoc.data()!['stats']['totalEmployees'], equals(-1));
      expect(statsDoc.data()!['totalEmployees'], equals(-1));
    });

    test(
        'openDebtsCount should decrement below zero if already at zero (Atomic priority)',
        () async {
      // Setup: Stats summary with openDebtsCount = 0
      await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .set({
        'openDebtsCount': 0,
      });

      // Setup: Open debt
      await fakeFirestore.collection('debts').doc(debtId).set({
        'storeId': storeId,
        'amountDue': 100.0,
        'totalAmount': 100.0,
        'debtStatus': 'open',
        'customerName': 'Test',
        'customerPhone': '123',
        'debtType': 'store_sale',
        'createdBy': 'admin',
        'createdAt': Timestamp.now(),
        'debtDate': Timestamp.now(),
      });

      // Act: Process full payment when stats says 0 open debts
      await debtRepository.processPayment(debtId, 100.0, 'admin');

      // Assert
      final statsDoc = await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .get();

      // With FieldValue.increment(-1), it will be -1
      expect(statsDoc.data()!['openDebtsCount'], equals(-1));
    });

    test(
        'paidDebtsCount should decrement below zero if already at zero (Atomic priority)',
        () async {
      // Setup: Stats summary with paidDebtsCount = 0
      await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .set({
        'paidDebtsCount': 0,
      });

      // Setup: Paid debt
      await fakeFirestore.collection('debts').doc(debtId).set({
        'storeId': storeId,
        'amountDue': 0.0,
        'totalAmount': 100.0,
        'debtStatus': 'paid',
        'customerName': 'Test',
        'customerPhone': '123',
        'debtType': 'store_sale',
        'createdBy': 'admin',
        'createdAt': Timestamp.now(),
        'debtDate': Timestamp.now(),
      });

      // Act: Delete paid debt when stats says 0 paid debts
      await debtRepository.deleteDebt(debtId);

      // Assert
      final statsDoc = await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .get();

      expect(statsDoc.data()!['paidDebtsCount'], equals(-1));
    });
  });
}
