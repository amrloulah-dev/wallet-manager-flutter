import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockEmployeeRepository extends Mock implements EmployeeRepository {}
class MockAuthProvider extends Mock implements AuthProvider {}
class FakeTransactionModel extends Fake implements TransactionModel {}

void main() {
  late MockTransactionRepository mockTxRepo;
  late MockEmployeeRepository mockEmployeeRepo;
  late MockAuthProvider mockAuth;

  setUpAll(() {
    registerFallbackValue(UserRole.employee);
    registerFallbackValue(UserPermissions.defaultPermissions());
    registerFallbackValue(FakeTransactionModel());
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockTxRepo = MockTransactionRepository();
    mockEmployeeRepo = MockEmployeeRepository();
    mockAuth = MockAuthProvider();

    when(() => mockAuth.currentStoreId).thenReturn('s1');
  });

  group('Provider Permission Guards Tests', () {
    test('TransactionProvider.createTransaction should return false and set error if user lacks createTransaction permission', () async {
      final employee = UserModel(
        userId: 'u1',
        storeId: 's1',
        role: UserRole.employee,
        fullName: 'Employee',
        permissions: UserPermissions.defaultPermissions().copyWith(createTransaction: false),
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      when(() => mockAuth.currentUser).thenReturn(employee);
      when(() => mockAuth.isOwner).thenReturn(false);

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        storeId: 's1',
      );
      provider.updateAuthState(mockAuth);

      // Act
      final result = await provider.createTransaction(
          walletId: 'w1', 
          amount: 100.0, 
          commission: 5.0,
          transactionType: TransactionType.deposit,
      );

      // Assert
      expect(result, isFalse);
      expect(provider.hasError, isTrue);
      expect(provider.errorMessage, equals('permission_denied')); 
    });

    test('EmployeeProvider.addEmployee should throw PermissionDeniedException if user is not owner', () async {
       final employee = UserModel(
        userId: 'u1',
        storeId: 's1',
        role: UserRole.employee,
        fullName: 'Employee',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      when(() => mockAuth.currentUser).thenReturn(employee);
      when(() => mockAuth.isOwner).thenReturn(false);

      final provider = EmployeeProvider(
        employeeRepository: mockEmployeeRepo,
      );
      provider.updateAuthProvider(mockAuth);

      expect(
        () => provider.addEmployee(
          fullName: 'New', 
          phone: '123', 
          pin: '1234',
          permissions: UserPermissions.defaultPermissions(),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
   group('Provider Permission Success Cases', () {
    test('TransactionProvider.createTransaction should succeed if user is owner', () async {
      final owner = UserModel(
        userId: 'o1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Owner',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      when(() => mockAuth.currentUser).thenReturn(owner);
      when(() => mockAuth.isOwner).thenReturn(true);
      when(() => mockTxRepo.generateId()).thenReturn('t1');
      when(() => mockTxRepo.createTransaction(any())).thenAnswer((_) async {});

      final provider = TransactionProvider(
        transactionRepository: mockTxRepo,
        storeId: 's1',
      );
      provider.updateAuthState(mockAuth);

      final result = await provider.createTransaction(
          walletId: 'w1', 
          amount: 100.0, 
          commission: 5.0,
          transactionType: TransactionType.deposit,
      );

      expect(result, isTrue);
      expect(provider.hasError, isFalse);
    });
  });
  });
}
