import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';

void main() {
  late EmployeeRepository repository;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = EmployeeRepository(firestore: fakeFirestore);
  });

  group('EmployeeRepository Atomic Stats Verification', () {
    test(
        'deactivateEmployee should decrement totalEmployees atomically in store and stats summary',
        () async {
      final storeId = 's1';
      final userId = 'u1';
      final statsPath = FirebaseConstants.statsSummaryPath(storeId);
      final storePath = FirebaseConstants.storesCollection + '/$storeId';

      // Setup initial state
      await fakeFirestore.doc(storePath).set({
        'storeId': storeId,
        'stats': {'totalEmployees': 10},
      });

      await fakeFirestore.doc(statsPath).set({
        'totalEmployees': 10,
      });

      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId)
          .set({
        'userId': userId,
        'storeId': storeId,
        'isActive': true,
        'role': 'employee',
        'pin': PasswordHasher.hashPassword('1234'),
      });

      // Execute deactivation
      await repository.deactivateEmployee(userId);

      // Verify final state
      final storeSnap = await fakeFirestore.doc(storePath).get();
      final statsSnap = await fakeFirestore.doc(statsPath).get();

      expect(storeSnap.data()?['stats']['totalEmployees'], 9);
      expect(statsSnap.data()?['totalEmployees'], 9);
    });
  });
}
