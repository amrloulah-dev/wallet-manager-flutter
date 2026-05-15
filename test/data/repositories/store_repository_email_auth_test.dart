import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('StoreRepository Email Auth (Phase 11.5)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late StoreRepository storeRepository;
    late MockFirebaseService mockFirebaseService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockFirebaseService = MockFirebaseService();
      when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);
      
      storeRepository = StoreRepository(firebaseService: mockFirebaseService);
    });

    test('getStoreByEmail should return the correct store document', () async {
      const email = 'owner@example.com';
      const password = 'password123';
      final hashedPassword = await PasswordHasher.hashPassword(password);

      await fakeFirestore.collection(FirebaseConstants.storesCollection).doc('store_1').set({
        FirebaseConstants.storeId: 'store_1',
        FirebaseConstants.storePassword: hashedPassword,
        FirebaseConstants.ownerEmail: email,
        'storeName': 'Secure Store',
        'isActive': true,
      });

      final store = await storeRepository.getStoreByEmail(email);

      expect(store, isNotNull);
      expect(store!.ownerEmail, email);
      expect(store.storeId, 'store_1');
    });

    test('getStoreByEmail should return null if no store matches', () async {
      final store = await storeRepository.getStoreByEmail('nonexistent@example.com');
      expect(store, isNull);
    });
  });
}
