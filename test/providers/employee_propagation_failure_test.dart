import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

class TestEmployeeProvider extends EmployeeProvider {
  StackTrace? lastStack;
  Object? lastError;

  TestEmployeeProvider({required super.employeeRepository});

  @override
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'employee_operation']) {
    lastStack = stack;
    lastError = error;
    super.setError(errorCode, error, stack, showToast, operation);
  }
}

void main() {
  late MockEmployeeRepository mockEmployeeRepo;
  late TestEmployeeProvider employeeProvider;

  setUp(() {
    AppErrorHandler.isTestMode = true;
    mockEmployeeRepo = MockEmployeeRepository();
    employeeProvider = TestEmployeeProvider(employeeRepository: mockEmployeeRepo);
  });

  group('EmployeeProvider Error Propagation', () {
    test('deactivateEmployee propagates stack trace on generic error', () async {
      final exception = Exception('Deactivate failed');
      when(() => mockEmployeeRepo.deactivateEmployee(any())).thenThrow(exception);

      // This should NOT crash but call setError with stack
      await employeeProvider.deactivateEmployee('user123');

      expect(employeeProvider.lastError, equals(exception));
      expect(employeeProvider.lastStack, isNotNull);
    });

    test('resetEmployeePIN propagates stack trace on generic error', () async {
      final exception = Exception('Reset failed');
      when(() => mockEmployeeRepo.resetEmployeePIN(
        userId: any(named: 'userId'),
        newPin: any(named: 'newPin'),
      )).thenThrow(exception);

      await employeeProvider.resetEmployeePIN(userId: 'user123', newPin: '1234');

      expect(employeeProvider.lastError, equals(exception));
      expect(employeeProvider.lastStack, isNotNull);
    });
  });
}
