import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

void main() {
  late EmployeeProvider employeeProvider;
  late MockEmployeeRepository mockEmployeeRepository;

  const storeId = 'test_store';

  setUp(() {
    mockEmployeeRepository = MockEmployeeRepository();
    employeeProvider =
        EmployeeProvider(employeeRepository: mockEmployeeRepository);

    // Default mock behavior for watchEmployees
    when(() => mockEmployeeRepository.watchEmployees(any(),
            searchQuery: any(named: 'searchQuery'),
            activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) => Stream.value([]));
  });

  group('Client-Side Search Filtering (TDD - Phase 2)', () {
    test(
        'EmployeeProvider should call watchEmployees with searchQuery when setSearchQuery is called',
        () async {
      // 1. Initial setStoreId should call watchEmployees with default params
      employeeProvider.setStoreId(storeId);

      verify(() => mockEmployeeRepository.watchEmployees(storeId,
          searchQuery: null, activeOnly: true)).called(1);

      // 2. Setting search query should trigger a NEW call to watchEmployees
      const query = 'Alice';
      employeeProvider.setSearchQuery(query);

      // We expect watchEmployees to be called again with the query
      verify(() => mockEmployeeRepository.watchEmployees(storeId,
          searchQuery: query, activeOnly: true)).called(1);
    });

    test(
        'EmployeeProvider should call watchEmployees with activeOnly when toggleActiveFilter is called',
        () async {
      employeeProvider.setStoreId(storeId);

      verify(() => mockEmployeeRepository.watchEmployees(storeId,
          searchQuery: null, activeOnly: true)).called(1);

      // Toggle active filter (should change activeOnly to false)
      employeeProvider.toggleActiveFilter();

      verify(() => mockEmployeeRepository.watchEmployees(storeId,
          searchQuery: null, activeOnly: false)).called(1);
    });

    test('filteredEmployees should return the list provided by the stream',
        () async {
      final mockEmployees = [
        UserModel(
            userId: '1',
            storeId: storeId,
            role: UserRole.employee,
            fullName: 'Alice',
            createdAt: DateTime.now(),
            lastLogin: DateTime.now()),
      ];

      when(() => mockEmployeeRepository.watchEmployees(any(),
              searchQuery: any(named: 'searchQuery'),
              activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) => Stream.value(mockEmployees));

      employeeProvider.setStoreId(storeId);

      // Give the stream a moment to emit
      await Future.delayed(Duration.zero);

      expect(employeeProvider.filteredEmployees, equals(mockEmployees));
    });
  });
}
