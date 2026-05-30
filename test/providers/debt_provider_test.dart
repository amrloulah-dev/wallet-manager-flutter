import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/debt_provider.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walletmanager/core/enums/debt_enums.dart';

class MockDebtRepository extends Mock implements DebtRepository {}

class MockAuthProvider extends Mock implements AuthProvider {}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}

void main() {
  late DebtProvider provider;
  late MockDebtRepository mockDebtRepo;
  late MockAuthProvider mockAuth;

  const storeId = 'test_store';

  setUp(() {
    mockDebtRepo = MockDebtRepository();
    mockAuth = MockAuthProvider();

    provider = DebtProvider(
      authProvider: mockAuth,
      debtRepository: mockDebtRepo,
    );
  });

  group('DebtProvider - Stateless Pagination', () {
    test('fetchInitialDebts should initialize lastDocument', () async {
      // ARRANGE
      final mockDoc = MockDocumentSnapshot();
      final result = PaginatedResult<DebtModel>(
        items: [],
        lastDocument: mockDoc,
      );

      registerFallbackValue(DateTime(2020));
      when(() => mockDebtRepo.getDebtsByDateRange(
            any(),
            any(),
            any(),
            lastDocument: null,
            debtType: any(named: 'debtType'),
            debtStatus: any(named: 'debtStatus'),
          )).thenAnswer((_) async => result);

      when(() => mockDebtRepo.fetchDebtStatistics(
            storeId: any(named: 'storeId'),
            type: any(named: 'type'),
          )).thenAnswer((_) async => {});

      // ACT
      provider.setStoreId(storeId);
      await provider.fetchInitialDebts();

      // ASSERT
      verify(() => mockDebtRepo.getDebtsByDateRange(
            storeId,
            any(),
            any(),
            lastDocument: null,
            debtType: any(named: 'debtType'),
            debtStatus: any(named: 'debtStatus'),
          )).called(2); // Once from setStoreId, once from fetchInitialDebts
    });

    test('fetchMoreDebts should pass lastDocument to repository', () async {
      // ARRANGE
      final mockDoc1 = MockDocumentSnapshot();
      final result1 = PaginatedResult<DebtModel>(
        items: List.generate(20, (i) => MockDebtModel()),
        lastDocument: mockDoc1,
      );

      final mockDoc2 = MockDocumentSnapshot();
      final result2 = PaginatedResult<DebtModel>(
        items: [],
        lastDocument: mockDoc2,
      );

      registerFallbackValue(DateTime(2020));
      when(() => mockDebtRepo.getDebtsByDateRange(
            any(),
            any(),
            any(),
            lastDocument: null,
            debtType: any(named: 'debtType'),
            debtStatus: any(named: 'debtStatus'),
          )).thenAnswer((_) async => result1);

      when(() => mockDebtRepo.getDebtsByDateRange(
            any(),
            any(),
            any(),
            lastDocument: mockDoc1,
            debtType: any(named: 'debtType'),
            debtStatus: any(named: 'debtStatus'),
          )).thenAnswer((_) async => result2);

      when(() => mockDebtRepo.fetchDebtStatistics(
            storeId: any(named: 'storeId'),
            type: any(named: 'type'),
          )).thenAnswer((_) async => {});

      // ACT
      provider.setStoreId(storeId);
      await provider.fetchInitialDebts(); // First load
      await provider.fetchMoreDebts(); // Second load

      // ASSERT
      verify(() => mockDebtRepo.getDebtsByDateRange(
            storeId,
            any(),
            any(),
            lastDocument: mockDoc1,
            debtType: any(named: 'debtType'),
            debtStatus: any(named: 'debtStatus'),
          )).called(1);
    });
  });

  group('DebtProvider - Filters & Tabs (BUG-02)', () {
    test(
        'setDebtType should clear debts, reset lastDocument, and call repository with correct debtType',
        () async {
      // ARRANGE
      final mockDoc = MockDocumentSnapshot();
      final result = PaginatedResult<DebtModel>(
        items: [MockDebtModel()],
        lastDocument: mockDoc,
      );

      registerFallbackValue(DateTime(2020));
      when(() => mockDebtRepo.getDebtsByDateRange(
            any(),
            any(),
            any(),
            lastDocument: any(named: 'lastDocument'),
            debtType: any(named: 'debtType'),
            debtStatus: any(named: 'debtStatus'),
          )).thenAnswer((_) async => result);

      when(() => mockDebtRepo.fetchDebtStatistics(
            storeId: any(named: 'storeId'),
            type: any(named: 'type'),
          )).thenAnswer((_) async => {});

      provider.setStoreId(storeId);
      await provider.fetchInitialDebts();

      // Ensure we have loaded some debts initially
      expect(provider.debts.length, 1);

      // ACT
      provider.setDebtType(DebtType.storeSale);

      // ASSERT
      expect(provider.debts.isEmpty, true);
      expect(provider.isLoading, true);

      // Wait for fetchInitialDebts to complete
      await Future.delayed(Duration.zero);

      verify(() => mockDebtRepo.getDebtsByDateRange(
            storeId,
            any(),
            any(),
            lastDocument: null,
            debtType: 'storeSale',
            debtStatus: null,
          )).called(1);
    });

    test(
        'setFilter should clear debts, reset lastDocument, and call repository with correct debtStatus',
        () async {
      // ARRANGE
      final mockDoc = MockDocumentSnapshot();
      final result = PaginatedResult<DebtModel>(
        items: [MockDebtModel()],
        lastDocument: mockDoc,
      );

      registerFallbackValue(DateTime(2020));
      when(() => mockDebtRepo.getDebtsByDateRange(
            any(),
            any(),
            any(),
            lastDocument: any(named: 'lastDocument'),
            debtType: any(named: 'debtType'),
            debtStatus: any(named: 'debtStatus'),
          )).thenAnswer((_) async => result);

      when(() => mockDebtRepo.fetchDebtStatistics(
            storeId: any(named: 'storeId'),
            type: any(named: 'type'),
          )).thenAnswer((_) async => {});

      provider.setStoreId(storeId);
      await provider.fetchInitialDebts();

      // ACT
      provider.setFilter('open');

      // ASSERT
      expect(provider.debts.isEmpty, true);
      expect(provider.isLoading, true);

      // Wait for fetchInitialDebts to complete
      await Future.delayed(Duration.zero);

      verify(() => mockDebtRepo.getDebtsByDateRange(
            storeId,
            any(),
            any(),
            lastDocument: null,
            debtType: 'transaction',
            debtStatus: 'open',
          )).called(1);
    });
  });
}

class MockDebtModel extends Mock implements DebtModel {
  @override
  String get debtId => 'test';
  @override
  bool get isOpen => true;
  @override
  bool get isPaid => false;
}
