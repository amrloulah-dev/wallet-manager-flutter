import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Reproduction of Salted Hashing Query Bug', () {
    late FakeFirebaseFirestore fakeFirestore;
    late EmployeeRepository employeeRepository;
    late StoreRepository storeRepository;
    late MockFirebaseService mockFirebaseService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockFirebaseService = MockFirebaseService();
      when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);

      employeeRepository = EmployeeRepository(firestore: fakeFirestore);
      storeRepository = StoreRepository(firebaseService: mockFirebaseService);
      AppErrorHandler.isTestMode = true; // Disable toast and reporting in tests
    });

    test('getEmployeeByPIN should find employee with salted hash', () async {
      const pin = '1234';
      const storeId = 'store_1';
      final hashedPin = await PasswordHasher.hashPassword(pin);

      await fakeFirestore.collection(FirebaseConstants.usersCollection).add({
        FirebaseConstants.storeId: storeId,
        FirebaseConstants.role: UserRole.employee.name,
        FirebaseConstants.pin: hashedPin,
        FirebaseConstants.isActive: true,
        'fullName': 'Test Employee',
        'createdAt': Timestamp.now(),
        'lastLogin': Timestamp.now(),
      });

      final employee = await employeeRepository.getEmployeeByPIN(
        storeId: storeId,
        pin: pin,
      );

      expect(employee, isNotNull, reason: 'Employee should be found by PIN');
    });

    test('getStoresByPassword should find store with salted hash', () async {
      const password = 'password123';
      final hashedPassword = await PasswordHasher.hashPassword(password);

      await fakeFirestore.collection(FirebaseConstants.storesCollection).add({
        FirebaseConstants.storeId: 'store_1',
        FirebaseConstants.storePassword: hashedPassword,
        'storeName': 'Test Store',
        'ownerId': 'owner_1',
        'ownerName': 'Owner',
        'ownerEmail': 'owner@test.com',
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      final stores = await storeRepository.getStoresByPassword(password);

      expect(stores, isNotEmpty, reason: 'Store should be found by password');
    });
  });
}
