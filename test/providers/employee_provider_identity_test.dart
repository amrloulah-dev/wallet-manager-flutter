import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

void main() {
  late MockEmployeeRepository mockRepository;
  late EmployeeProvider employeeProvider;
  late UserModel mockEmployee;

  setUp(() {
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
      createdAt: Timestamp.now(),
      lastLogin: Timestamp.now(),
      permissions: UserPermissions(
        createTransaction: true,
        viewAllTransactions: true,
        viewDebts: false,
        createDebt: false,
        collectDebt: false,
      ),
    );

    registerFallbackValue(mockEmployee);
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
      when(() => mockRepository.resetEmployeePIN(userId: any(named: 'userId'), newPin: any(named: 'newPin')))
          .thenAnswer((_) async => true);
      when(() => mockRepository.syncCredential(any(), any()))
          .thenAnswer((_) async {});

      // Note: testing syncCredential requires employee to exist in provider's internal list,
      // which we skip here due to stream mocking complexity in this simple test.
      // We just call it to ensure it compiles.
      await employeeProvider.resetEmployeePIN(userId: mockEmployee.userId, newPin: '4321');

      verify(() => mockRepository.resetEmployeePIN(userId: mockEmployee.userId, newPin: any(named: 'newPin'))).called(1);
      verify(() => mockRepository.syncCredential(mockEmployee, '4321')).called(1);
    });

    test('deactivateEmployee calls cleanupIdentity after success', () async {
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
