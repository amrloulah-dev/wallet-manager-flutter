import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/providers/employee_provider.dart';

import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

class MockAuthProvider extends Mock implements AuthProvider {}

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

class FakeUserPermissions extends Fake implements UserPermissions {}

void main() {
  late MockEmployeeRepository mockRepository;
  late MockAuthProvider mockAuth;
  late EmployeeProvider employeeProvider;
  late UserModel mockEmployee;

  setUpAll(() {
    registerFallbackValue(FakeUserPermissions());
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockRepository = MockEmployeeRepository();
    mockAuth = MockAuthProvider();
    when(() => mockAuth.isOwner).thenReturn(true);

    employeeProvider = EmployeeProvider(employeeRepository: mockRepository);
    employeeProvider.updateAuthProvider(mockAuth);

    mockEmployee = UserModel(
      userId: 'emp-123',
      storeId: 'store-123',
      role: UserRole.employee, // ENUM refactor
      fullName: 'Test Employee',
      phone: '123456789',
      pin: 'hashed_pin',
      isActive: true,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      permissions: UserPermissions(
        createTransaction: true,
        viewAllTransactions: true,
        viewDebts: false,
        createDebt: false,
        collectDebt: false,
      ),
    );

    registerFallbackValue(mockEmployee);

    // Seed the internal list of employees
    when(() => mockRepository.getEmployeesByStoreId(
            storeId: any(named: 'storeId'),
            searchQuery: any(named: 'searchQuery'),
            activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) async => [mockEmployee]);
    employeeProvider.setStoreId('store-123');
  });

  group('EmployeeProvider Identity Orchestration', () {
    test('addEmployee calls repository addEmployee after validation', () async {
      when(() => mockRepository.addEmployee(
            storeId: 'store-123',
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            pin: any(named: 'pin'),
            permissions: any(named: 'permissions'),
          )).thenAnswer((_) async => mockEmployee);

      final success = await employeeProvider.addEmployee(
        fullName: 'Test Employee',
        phone: '123456789',
        pin: '123456',
        permissions: mockEmployee.permissions!,
      );

      expect(success, isTrue);
      verify(() => mockRepository.addEmployee(
            storeId: 'store-123',
            fullName: 'Test Employee',
            phone: '123456789',
            pin: '123456',
            permissions: mockEmployee.permissions!,
          )).called(1);
    });

    test('addEmployee propagates gracefully if repository addEmployee throws',
        () async {
      when(() => mockRepository.addEmployee(
            storeId: 'store-123',
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            pin: any(named: 'pin'),
            permissions: any(named: 'permissions'),
          )).thenThrow(Exception('Provisioning failed'));

      final result = await employeeProvider.addEmployee(
        fullName: 'Test Employee',
        phone: '123456789',
        pin: '123456',
        permissions: mockEmployee.permissions!,
      );

      expect(result, isFalse);
      expect(employeeProvider.hasError, isTrue);
    });

    test('resetEmployeePIN calls syncCredential after success', () async {
      await Future.delayed(Duration.zero); // wait for stream
      when(() => mockRepository.resetEmployeePIN(
          userId: any(named: 'userId'),
          newPin: any(named: 'newPin'))).thenAnswer((_) async => true);
      when(() => mockRepository.syncCredential(any(), any()))
          .thenAnswer((_) async {});

      await employeeProvider.resetEmployeePIN(
          userId: mockEmployee.userId, newPin: '654321');

      verify(() => mockRepository.resetEmployeePIN(
          userId: mockEmployee.userId, newPin: any(named: 'newPin'))).called(1);
      verify(() => mockRepository.syncCredential(mockEmployee, '654321'))
          .called(1);
    });

    test('deactivateEmployee calls cleanupIdentity after success', () async {
      await Future.delayed(Duration.zero); // wait for stream
      when(() => mockRepository.deactivateEmployee(any()))
          .thenAnswer((_) async {});
      when(() => mockRepository.cleanupIdentity(any()))
          .thenAnswer((_) async {});

      await employeeProvider.deactivateEmployee(mockEmployee.userId);

      verify(() => mockRepository.deactivateEmployee(mockEmployee.userId))
          .called(1);
      verify(() => mockRepository.cleanupIdentity(mockEmployee)).called(1);
    });

    test('addEmployee inserts the new employee at the top of the local list',
        () async {
      final newEmp = UserModel(
        userId: 'emp-456',
        storeId: 'store-123',
        role: UserRole.employee,
        fullName: 'New Employee',
        phone: '987654321',
        pin: 'new_pin_hash',
        isActive: true,
        createdAt: DateTime.now().add(const Duration(seconds: 10)),
        permissions: mockEmployee.permissions!,
      );

      when(() => mockRepository.addEmployee(
            storeId: 'store-123',
            fullName: 'New Employee',
            phone: '987654321',
            pin: '123456',
            permissions: any(named: 'permissions'),
          )).thenAnswer((_) async => newEmp);

      when(() => mockRepository.provisionIdentity(any()))
          .thenAnswer((_) async {});

      expect(employeeProvider.employees.length, 1);
      expect(employeeProvider.employees.first.userId, 'emp-123');

      final result = await employeeProvider.addEmployee(
        fullName: 'New Employee',
        phone: '987654321',
        pin: '123456',
        permissions: mockEmployee.permissions!,
      );

      expect(result, true);
      expect(employeeProvider.employees.length, 2);
      expect(employeeProvider.employees.first.userId, 'emp-456');
    });
  });

  group('Employee Suspension on Limit Change', () {
    late MockSubscriptionProvider mockSubProvider;
    late UserModel e1;
    late UserModel e2;
    late UserModel e3;

    setUp(() {
      mockSubProvider = MockSubscriptionProvider();

      e1 = UserModel(
        userId: 'e1',
        storeId: 'store-123',
        role: UserRole.employee,
        fullName: 'Employee 1',
        phone: '111',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        lastLogin: DateTime.now(),
      );

      e2 = UserModel(
        userId: 'e2',
        storeId: 'store-123',
        role: UserRole.employee,
        fullName: 'Employee 2',
        phone: '222',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        lastLogin: DateTime.now(),
      );

      e3 = UserModel(
        userId: 'e3',
        storeId: 'store-123',
        role: UserRole.employee,
        fullName: 'Employee 3',
        phone: '333',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        lastLogin: DateTime.now(),
      );
    });

    test(
        'optimistically suspends excess employees (newest first) and writes to Firestore',
        () async {
      employeeProvider.setEmployeesForTesting([e1, e2, e3]);

      when(() => mockSubProvider.maxEmployees).thenReturn(2);
      when(() => mockRepository.updateEmployee('e3', {'isSuspended': true}))
          .thenAnswer((_) async => {});

      // Trigger update
      employeeProvider.updateSubscriptionProvider(mockSubProvider);

      // Verify that e3 is suspended in memory (isEmployeeFrozen returns true)
      expect(employeeProvider.isEmployeeFrozen(e1), isFalse);
      expect(employeeProvider.isEmployeeFrozen(e2), isFalse);
      expect(employeeProvider.isEmployeeFrozen(e3), isTrue);

      await Future.delayed(Duration.zero);

      verify(() => mockRepository.updateEmployee('e3', {'isSuspended': true}))
          .called(1);
    });

    test('rolls back to active status on Firestore write failure', () async {
      employeeProvider.setEmployeesForTesting([e1, e2, e3]);

      when(() => mockSubProvider.maxEmployees).thenReturn(2);
      when(() => mockRepository.updateEmployee('e3', {'isSuspended': true}))
          .thenThrow(Exception('Firestore write failed'));

      // Trigger update
      employeeProvider.updateSubscriptionProvider(mockSubProvider);

      // Verify that e3 is rolled back and is NOT frozen after failure
      await Future.delayed(Duration.zero);
      expect(employeeProvider.isEmployeeFrozen(e3), isFalse);
    });

    test(
        '_fetchEmployees unlocks loading status and sets error on permission-denied',
        () async {
      when(() =>
          mockRepository.getEmployeesByStoreId(
              storeId: 'store-denied',
              searchQuery: any(named: 'searchQuery'),
              activeOnly: any(named: 'activeOnly'))).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'));

      employeeProvider.setStoreId('store-denied');
      await Future.delayed(Duration.zero);

      expect(employeeProvider.isLoading, isFalse);
      expect(employeeProvider.hasError, isTrue);
      expect(employeeProvider.errorMessage, 'employee_error_permission_denied');
      expect(employeeProvider.employees, isEmpty);
    });
  });
}
