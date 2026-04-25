import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/providers/employee_provider.dart';

import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

class FakeUserPermissions extends Fake implements UserPermissions {}

void main() {
  late MockEmployeeRepository mockRepository;
  late EmployeeProvider employeeProvider;
  late UserModel mockEmployee;

  setUpAll(() {
    registerFallbackValue(FakeUserPermissions());
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockRepository = MockEmployeeRepository();
    employeeProvider = EmployeeProvider(employeeRepository: mockRepository);
    
    mockEmployee = UserModel(
      userId: 'emp-123',
      storeId: 'store-123',
      role: 'employee',
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
    when(() => mockRepository.watchEmployees(any())).thenAnswer((_) => Stream.value([mockEmployee]));
    employeeProvider.setStoreId('store-123');
  });

  group('EmployeeProvider Identity Orchestration', () {
    test('addEmployee calls provisionIdentity after success', () async {
      when(() => mockRepository.addEmployee(
            storeId: 'store-123',
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            pin: any(named: 'pin'),
            permissions: any(named: 'permissions'),
          )).thenAnswer((_) async => mockEmployee);

      when(() => mockRepository.provisionIdentity(any())).thenAnswer((_) async {});

      await employeeProvider.addEmployee(
        fullName: 'Test Employee',
        phone: '123456789',
        pin: '1234',
        permissions: mockEmployee.permissions!,
      );

      verify(() => mockRepository.provisionIdentity(mockEmployee)).called(1);
    });

    test('addEmployee propagates gracefully if provisionIdentity throws', () async {
      when(() => mockRepository.addEmployee(
            storeId: 'store-123',
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            pin: any(named: 'pin'),
            permissions: any(named: 'permissions'),
          )).thenAnswer((_) async => mockEmployee);

      when(() => mockRepository.provisionIdentity(any())).thenThrow(Exception('Provisioning failed'));

      // Should not throw
      await employeeProvider.addEmployee(
        fullName: 'Test Employee',
        phone: '123456789',
        pin: '1234',
        permissions: mockEmployee.permissions!,
      );

      // Verify provision was still called, even if it failed silently in background
      verify(() => mockRepository.provisionIdentity(mockEmployee)).called(1);
    });

    test('resetEmployeePIN calls syncCredential after success', () async {
      await Future.delayed(Duration.zero); // wait for stream
      when(() => mockRepository.resetEmployeePIN(userId: any(named: 'userId'), newPin: any(named: 'newPin')))
          .thenAnswer((_) async => true);
      when(() => mockRepository.syncCredential(any(), any()))
          .thenAnswer((_) async {});

      await employeeProvider.resetEmployeePIN(userId: mockEmployee.userId, newPin: '4321');

      verify(() => mockRepository.resetEmployeePIN(userId: mockEmployee.userId, newPin: any(named: 'newPin'))).called(1);
      verify(() => mockRepository.syncCredential(mockEmployee, '4321')).called(1);
    });

    test('deactivateEmployee calls cleanupIdentity after success', () async {
       await Future.delayed(Duration.zero); // wait for stream
       when(() => mockRepository.deactivateEmployee(any()))
          .thenAnswer((_) async {});
       when(() => mockRepository.cleanupIdentity(any()))
          .thenAnswer((_) async {});

       await employeeProvider.deactivateEmployee(mockEmployee.userId);

       verify(() => mockRepository.deactivateEmployee(mockEmployee.userId)).called(1);
       verify(() => mockRepository.cleanupIdentity(mockEmployee)).called(1);
    });
  });
}
