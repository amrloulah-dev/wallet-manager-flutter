import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/subscription_plan_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';

class MockPlatformSettingsProvider extends Mock implements PlatformSettingsProvider {}

void main() {
  late EmployeeRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockPlatformSettingsProvider mockPlatformSettingsProvider;

  final defaultPermissions = UserPermissions(
    createTransaction: true,
    editTransaction: true,
    viewAllTransactions: true,
    viewDebts: true,
    createDebt: true,
    collectDebt: true,
    deleteDebt: true,
    viewWallets: true,
    viewWalletBalance: true,
    createWallet: true,
    addBalance: true,
    editWallet: true,
    viewDashboardStats: true,
  );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = EmployeeRepository(firestore: fakeFirestore);
    mockPlatformSettingsProvider = MockPlatformSettingsProvider();

    final sl = GetIt.instance;
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      sl.unregister<PlatformSettingsProvider>();
    }
    sl.registerSingleton<PlatformSettingsProvider>(mockPlatformSettingsProvider);

    // Mock platform settings default
    const settings = PlatformSettingsModel.defaults();
    when(() => mockPlatformSettingsProvider.settings).thenReturn(settings);
  });

  group('EmployeeRepository Atomic Stats Verification', () {
    test(
        'deactivateEmployee should decrement totalEmployees only in stats summary doc, NOT store doc',
        () async {
      final storeId = 's1';
      final userId = 'u1';
      final statsPath = FirebaseConstants.statsSummaryPath(storeId);
      final storePath = '${FirebaseConstants.storesCollection}/$storeId';

      // Setup initial state
      await fakeFirestore.doc(storePath).set({
        'storeId': storeId,
        'stats': {'totalEmployees': 10},
      });

      await fakeFirestore.doc(statsPath).set({
        'totalEmployees': 10,
      });

      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId)
          .set({
        'userId': userId,
        'storeId': storeId,
        'isActive': true,
        'role': 'employee',
        'pin': await PasswordHasher.hashPassword('1234'),
      });

      // Execute deactivation
      await repository.deactivateEmployee(userId);

      // Verify final state
      final storeSnap = await fakeFirestore.doc(storePath).get();
      final statsSnap = await fakeFirestore.doc(statsPath).get();

      // Store doc stats should NOT change
      expect(storeSnap.data()?['stats']?['totalEmployees'], 10);
      // Summary doc stats should decrement to 9
      expect(statsSnap.data()?['totalEmployees'], 9);
    });

    test('addEmployee enforces capacity limits from catalog (under limit)', () async {
      final storeId = 'store_under';
      final storePath = '${FirebaseConstants.storesCollection}/$storeId';

      await fakeFirestore.doc(storePath).set({
        'storeId': storeId,
        'subscription': {'planId': 'pro_yearly'},
      });

      // 1 employee exists
      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('emp1')
          .set({
        'userId': 'emp1',
        'storeId': storeId,
        'isActive': true,
        'role': 'employee',
        'pin': await PasswordHasher.hashPassword('0000'),
      });

      // Mock catalog plan limit of 5 employees
      final mockSettings = PlatformSettingsModel(
        isRegistrationOpen: true,
        instapayLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkCommercialLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkNewLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkOldLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        minCrossNetworkFee: 0,
        maxCrossNetworkFee: 0,
        minInstapayFee: 0,
        maxInstapayFee: 0,
        sameNetworkFee: 0,
        crossNetworkFeeRate: 0,
        instapayFeeRate: 0,
        lifetimeCountLimit: 50,
        gracePeriodHours: 48,
        trialDays: 14,
        plans: {
          'pro_yearly': const SubscriptionPlanModel(
            name: 'Pro Yearly',
            description: '',
            isActive: true,
            price: 100,
            maxWallets: 50,
            maxEmployees: 5,
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings).thenReturn(mockSettings);

      // Should succeed since current = 1 < limit = 5
      final employee = await repository.addEmployee(
        storeId: storeId,
        fullName: 'New Employee',
        phone: '1234567890',
        pin: '1234',
        permissions: defaultPermissions,
      );

      expect(employee.fullName, 'New Employee');
    });

    test('addEmployee enforces capacity limits from catalog (at limit)', () async {
      final storeId = 'store_at_limit';
      final storePath = '${FirebaseConstants.storesCollection}/$storeId';

      await fakeFirestore.doc(storePath).set({
        'storeId': storeId,
        'subscription': {'planId': 'pro_yearly'},
      });

      // 2 employees exist
      for (int i = 1; i <= 2; i++) {
        await fakeFirestore
            .collection(FirebaseConstants.usersCollection)
            .doc('emp$i')
            .set({
          'userId': 'emp$i',
          'storeId': storeId,
          'isActive': true,
          'role': 'employee',
          'pin': await PasswordHasher.hashPassword('000$i'),
        });
      }

      // Mock catalog plan limit of 2 employees
      final mockSettings = PlatformSettingsModel(
        isRegistrationOpen: true,
        instapayLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkCommercialLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkNewLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkOldLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        minCrossNetworkFee: 0,
        maxCrossNetworkFee: 0,
        minInstapayFee: 0,
        maxInstapayFee: 0,
        sameNetworkFee: 0,
        crossNetworkFeeRate: 0,
        instapayFeeRate: 0,
        lifetimeCountLimit: 50,
        gracePeriodHours: 48,
        trialDays: 14,
        plans: {
          'pro_yearly': const SubscriptionPlanModel(
            name: 'Pro Yearly',
            description: '',
            isActive: true,
            price: 100,
            maxWallets: 50,
            maxEmployees: 2,
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings).thenReturn(mockSettings);

      // Should fail since current = 2 >= limit = 2
      expect(
        () => repository.addEmployee(
          storeId: storeId,
          fullName: 'New Employee',
          phone: '1234567890',
          pin: '1234',
          permissions: defaultPermissions,
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('addEmployee enforces capacity limits from catalog (unlimited -1)', () async {
      final storeId = 'store_unlimited';
      final storePath = '${FirebaseConstants.storesCollection}/$storeId';

      await fakeFirestore.doc(storePath).set({
        'storeId': storeId,
        'subscription': {'planId': 'pro_yearly'},
      });

      // 5 employees exist
      for (int i = 1; i <= 5; i++) {
        await fakeFirestore
            .collection(FirebaseConstants.usersCollection)
            .doc('emp$i')
            .set({
          'userId': 'emp$i',
          'storeId': storeId,
          'isActive': true,
          'role': 'employee',
          'pin': await PasswordHasher.hashPassword('000$i'),
        });
      }

      // Mock catalog plan limit of -1 (unlimited)
      final mockSettings = PlatformSettingsModel(
        isRegistrationOpen: true,
        instapayLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkCommercialLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkNewLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        networkOldLimits: const NetworkLimits(dailyReceive: 0, dailySend: 0, maxPerTransaction: 0, monthlyReceive: 0, monthlySend: 0),
        minCrossNetworkFee: 0,
        maxCrossNetworkFee: 0,
        minInstapayFee: 0,
        maxInstapayFee: 0,
        sameNetworkFee: 0,
        crossNetworkFeeRate: 0,
        instapayFeeRate: 0,
        lifetimeCountLimit: 50,
        gracePeriodHours: 48,
        trialDays: 14,
        plans: {
          'pro_yearly': const SubscriptionPlanModel(
            name: 'Pro Yearly',
            description: '',
            isActive: true,
            price: 100,
            maxWallets: 50,
            maxEmployees: -1,
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings).thenReturn(mockSettings);

      // Should succeed since limit is -1 (unlimited)
      final employee = await repository.addEmployee(
        storeId: storeId,
        fullName: 'New Employee',
        phone: '1234567890',
        pin: '1234',
        permissions: defaultPermissions,
      );

      expect(employee.fullName, 'New Employee');
    });
  });
}
