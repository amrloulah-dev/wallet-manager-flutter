import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/services/identity_service.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/subscription_plan_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EmployeeRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockPlatformSettingsProvider mockPlatformSettingsProvider;
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

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
    mockAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    IdentityService.authOverride = mockAuth;

    when(() => mockAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => mockUserCredential);
    when(() => mockUserCredential.user).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('auth_uid_mock');
    when(() => mockUser.getIdToken()).thenAnswer((_) async => 'fake_token');

    final sl = GetIt.instance;
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      sl.unregister<PlatformSettingsProvider>();
    }
    sl.registerSingleton<PlatformSettingsProvider>(
        mockPlatformSettingsProvider);

    // Mock platform settings default
    const settings = PlatformSettingsModel.defaults();
    when(() => mockPlatformSettingsProvider.settings).thenReturn(settings);
  });

  tearDown(() {
    IdentityService.authOverride = null;
  });

  group('EmployeeRepository Atomic Stats & Deactivate Verification', () {
    test(
        'deactivateEmployee should decrement totalEmployees in stats summary doc AND delete pin_locks doc',
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

      final hashedPin = await PasswordHasher.hashPassword('123456');
      final pinLockPath = FirebaseConstants.pinLockPath(storeId, hashedPin);

      // Pre-set pin_lock doc
      await fakeFirestore.doc(pinLockPath).set({
        'userId': userId,
        'createdAt': 'timestamp',
      });

      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId)
          .set({
        'userId': userId,
        'storeId': storeId,
        'isActive': true,
        'role': 'employee',
        'pin': hashedPin,
      });

      // Execute deactivation
      await repository.deactivateEmployee(userId);

      // Verify final state
      final storeSnap = await fakeFirestore.doc(storePath).get();
      final statsSnap = await fakeFirestore.doc(statsPath).get();
      final pinLockSnap = await fakeFirestore.doc(pinLockPath).get();

      // Store doc stats should NOT change
      expect(storeSnap.data()?['stats']?['totalEmployees'], 10);
      // Summary doc stats should decrement to 9
      expect(statsSnap.data()?['totalEmployees'], 9);
      // pin_locks doc MUST be deleted to free up the seat lock
      expect(pinLockSnap.exists, isFalse);
    });

    test('addEmployee enforces capacity limits from catalog (under limit)',
        () async {
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
        'pin': await PasswordHasher.hashPassword('000000'),
      });

      // Mock catalog plan limit of 5 employees
      final mockSettings = PlatformSettingsModel(
        isRegistrationOpen: true,
        instapayLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkCommercialLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkNewLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkOldLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
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
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      // Should succeed since current = 1 < limit = 5
      final employee = await repository.addEmployee(
        storeId: storeId,
        fullName: 'New Employee',
        phone: '1234567890',
        pin: '123456',
        permissions: defaultPermissions,
      );

      expect(employee.fullName, 'New Employee');
    });

    test('addEmployee enforces capacity limits from catalog (at limit)',
        () async {
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
          'pin': await PasswordHasher.hashPassword('00000$i'),
        });
      }

      // Mock catalog plan limit of 2 employees
      final mockSettings = PlatformSettingsModel(
        isRegistrationOpen: true,
        instapayLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkCommercialLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkNewLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkOldLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
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
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      // Should fail since current = 2 >= limit = 2
      expect(
        () => repository.addEmployee(
          storeId: storeId,
          fullName: 'New Employee',
          phone: '1234567890',
          pin: '123456',
          permissions: defaultPermissions,
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('addEmployee enforces capacity limits from catalog (unlimited -1)',
        () async {
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
          'pin': await PasswordHasher.hashPassword('00000$i'),
        });
      }

      // Mock catalog plan limit of -1 (unlimited)
      final mockSettings = PlatformSettingsModel(
        isRegistrationOpen: true,
        instapayLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkCommercialLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkNewLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
        networkOldLimits: const NetworkLimits(
            dailyReceive: 0,
            dailySend: 0,
            maxPerTransaction: 0,
            monthlyReceive: 0,
            monthlySend: 0),
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
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      // Should succeed since limit is -1 (unlimited)
      final employee = await repository.addEmployee(
        storeId: storeId,
        fullName: 'New Employee',
        phone: '1234567890',
        pin: '123456',
        permissions: defaultPermissions,
      );

      expect(employee.fullName, 'New Employee');
    });

    test('updateEmployee updates user fields in Firestore', () async {
      final userId = 'emp-update-123';
      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId)
          .set({
        'userId': userId,
        'storeId': 'store-123',
        'isActive': true,
        'role': 'employee',
        'fullName': 'Old Name',
      });

      await repository.updateEmployee(
          userId, {'isSuspended': true, 'fullName': 'New Name'});

      final doc = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId)
          .get();

      expect(doc.data()?['isSuspended'], true);
      expect(doc.data()?['fullName'], 'New Name');
      expect(doc.data()?['updatedAt'], isNotNull);
    });
  });
}
