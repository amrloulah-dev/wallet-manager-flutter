import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  late UserRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);
    repository = UserRepository(firebaseService: mockFirebaseService);
  });

  group('UserRepository Atomic Stats Verification', () {
    test(
        'updateEmployeeStats should update stats atomically without pre-fetching user',
        () async {
      final userId = 'u1';
      final userPath = '${FirebaseConstants.usersCollection}/$userId';

      // Setup initial state
      await fakeFirestore.doc(userPath).set({
        'userId': userId,
        'role': 'employee',
        'createdAt': Timestamp.now(),
        'lastLogin': Timestamp.now(),
        'stats': {
          'totalTransactions': 5,
          'totalCommission': 50.0,
          'totalDebtsCreated': 2,
        }
      });

      // Execute update
      await repository.updateEmployeeStats(
        userId: userId,
        incrementTransactions: 1,
        incrementCommission: 10.0,
        incrementDebts: 1,
      );

      // Verify final state
      final userSnap = await fakeFirestore.doc(userPath).get();
      final stats = userSnap.data()?['stats'];

      expect(stats['totalTransactions'], 6);
      expect(stats['totalCommission'], 60.0);
      expect(stats['totalDebtsCreated'], 3);
    });
  });
}
