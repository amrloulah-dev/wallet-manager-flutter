import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late EmployeeRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = EmployeeRepository(firestore: fakeFirestore);
  });

  group('Counter Integrity', () {
    test('totalEmployees should not decrement below zero in store and stats summary', () async {
      const storeId = 'store1';
      const employeeId = 'emp1';

      // Setup: Store with totalEmployees = 0
      await fakeFirestore.collection(FirebaseConstants.storesCollection).doc(storeId).set({
        'storeId': storeId,
        'stats': {'totalEmployees': 0},
      });

      // Setup: Stats summary with totalEmployees = 0
      await fakeFirestore.collection(FirebaseConstants.storesCollection)
          .doc(storeId).collection('stats').doc('summary').set({
        'totalEmployees': 0,
      });

      // Setup: Active employee
      await fakeFirestore.collection(FirebaseConstants.usersCollection).doc(employeeId).set({
        'userId': employeeId,
        'storeId': storeId,
        'isActive': true,
        'role': FirebaseConstants.employeeRole,
        'pin': PasswordHasher.hashPassword('1234'),
      });

      // Act: Deactivate employee
      await repository.deactivateEmployee(employeeId);

      // Assert
      final storeDoc = await fakeFirestore.collection(FirebaseConstants.storesCollection).doc(storeId).get();
      final statsDoc = await fakeFirestore.collection(FirebaseConstants.storesCollection)
          .doc(storeId).collection('stats').doc('summary').get();

      expect(storeDoc.data()!['stats']['totalEmployees'], greaterThanOrEqualTo(0));
      expect(statsDoc.data()!['totalEmployees'], greaterThanOrEqualTo(0));
    });
  });
}
