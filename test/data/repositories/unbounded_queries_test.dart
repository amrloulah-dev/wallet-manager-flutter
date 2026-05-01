import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;
  late UserRepository userRepository;
  late EmployeeRepository employeeRepository;

  const storeId = 'test_store';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);

    userRepository = UserRepository(firebaseService: mockFirebaseService);
    employeeRepository = EmployeeRepository(firestore: fakeFirestore);
  });

  group('Unbounded Queries (TDD - Phase 4)', () {
    test('UserRepository.getUsersByStoreId should respect limit', () async {
      final now = Timestamp.now();
      // Setup: Create 30 users
      for (int i = 0; i < 30; i++) {
        await fakeFirestore.collection('users').doc('user_$i').set({
          'userId': 'user_$i',
          'storeId': storeId,
          'role': UserRole.employee.name,
          'isActive': true,
          'fullName': 'User $i',
          'createdAt': now,
          'lastLogin': now,
        });
      }

      final users = await userRepository.getUsersByStoreId(storeId);
      
      expect(users.length, lessThanOrEqualTo(20));
    });

    test('EmployeeRepository.getEmployeesByStoreId should respect limit', () async {
      final now = Timestamp.now();
      // Setup: Create 30 employees
      for (int i = 0; i < 30; i++) {
        await fakeFirestore.collection('users').doc('emp_$i').set({
          'userId': 'emp_$i',
          'storeId': storeId,
          'role': UserRole.employee.name,
          'isActive': true,
          'fullName': 'Employee $i',
          'createdAt': now,
          'lastLogin': now,
        });
      }

      final employees = await employeeRepository.getEmployeesByStoreId(storeId: storeId);
      
      expect(employees.length, lessThanOrEqualTo(20));
    });
  });
}
