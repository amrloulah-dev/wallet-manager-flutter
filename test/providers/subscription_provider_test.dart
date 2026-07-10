import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/subscription_plan_model.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionRepository mockSubscriptionRepository;
  late MockPlatformSettingsProvider mockPlatformSettingsProvider;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final mockSecureStorage = MockSecureStorage();
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'))).thenAnswer((_) async {});

    await LocalStorageService.instance
        .initialize(secureStorage: mockSecureStorage);
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockSubscriptionRepository = MockSubscriptionRepository();
    mockPlatformSettingsProvider = MockPlatformSettingsProvider();

    final GetIt sl = GetIt.instance;
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      sl.unregister<PlatformSettingsProvider>();
    }
    sl.registerSingleton<PlatformSettingsProvider>(
        mockPlatformSettingsProvider);

    when(() => mockAuthProvider.addListener(any())).thenReturn(null);
    when(() => mockAuthProvider.removeListener(any())).thenReturn(null);
    when(() => mockAuthProvider.refreshUserData()).thenAnswer((_) async {});
    when(() => mockSubscriptionRepository.getLatestSubscriptionRequest(any()))
        .thenAnswer((_) async => null);

    // Default settings stub
    const settings = PlatformSettingsModel.defaults();
    when(() => mockPlatformSettingsProvider.settings).thenReturn(settings);
    when(() => mockPlatformSettingsProvider.isInitialized).thenReturn(true);
    when(() => mockPlatformSettingsProvider.addListener(any()))
        .thenReturn(null);
    when(() => mockPlatformSettingsProvider.removeListener(any()))
        .thenReturn(null);
  });

  test('maxWallets and maxEmployees return 2 and 0 when expired', () {
    final sub = StoreSubscription(
      planId: SubscriptionPlan.proYearly,
      status: SubscriptionStatus.expired,
      endDate: DateTime.now().subtract(const Duration(days: 10)),
      trialConsumed: true,
      pendingRequestDate: null,
    );

    final store = StoreModel(
      storeId: 'test_store',
      storeName: 'Test Store',
      storePassword: 'hashed_password',
      ownerId: 'owner_id',
      ownerName: 'Owner Name',
      ownerEmail: 'owner@test.com',
      subscription: sub,
      settings: StoreSettings(),
    );

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
        'free': const SubscriptionPlanModel(
          name: 'Dynamic Free Plan',
          description: '',
          isActive: true,
          price: 0,
          maxWallets: 2,
          maxEmployees: 0,
          smsEnabled: false,
        ),
      },
    );
    when(() => mockPlatformSettingsProvider.settings).thenReturn(mockSettings);

    when(() => mockAuthProvider.currentStore).thenReturn(store);
    when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

    final provider = SubscriptionProvider(
      authProvider: mockAuthProvider,
      repository: mockSubscriptionRepository,
    );

    expect(provider.maxWallets, 2);
    expect(provider.maxEmployees, 0);
  });

  test('maxWallets and maxEmployees return actual limits when not expired', () {
    final sub = StoreSubscription(
      planId: SubscriptionPlan.proYearly,
      status: SubscriptionStatus.active,
      endDate: DateTime.now().add(const Duration(days: 10)),
      trialConsumed: true,
      pendingRequestDate: null,
    );

    final store = StoreModel(
      storeId: 'test_store',
      storeName: 'Test Store',
      storePassword: 'hashed_password',
      ownerId: 'owner_id',
      ownerName: 'Owner Name',
      ownerEmail: 'owner@test.com',
      subscription: sub,
      settings: StoreSettings(),
    );

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
          maxEmployees: 20,
          smsEnabled: true,
        ),
      },
    );
    when(() => mockPlatformSettingsProvider.settings).thenReturn(mockSettings);

    when(() => mockAuthProvider.currentStore).thenReturn(store);
    when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

    final provider = SubscriptionProvider(
      authProvider: mockAuthProvider,
      repository: mockSubscriptionRepository,
    );

    expect(provider.maxWallets, 50);
    expect(provider.maxEmployees, 20);
  });

  group('canAddEmployee Boundary Tests', () {
    test('should allow adding employee when count is below limit', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().add(const Duration(days: 10)),
        trialConsumed: true,
        pendingRequestDate: null,
      );

      final store = StoreModel(
        storeId: 'test_store',
        storeName: 'Test Store',
        storePassword: 'hashed_password',
        ownerId: 'owner_id',
        ownerName: 'Owner Name',
        ownerEmail: 'owner@test.com',
        subscription: sub,
        settings: StoreSettings(),
      );

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

      when(() => mockAuthProvider.currentStore).thenReturn(store);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.canAddEmployee(0), isTrue);
      expect(provider.canAddEmployee(4), isTrue);
      expect(provider.canAddEmployee(5), isFalse);
      expect(provider.canAddEmployee(6), isFalse);
    });

    test('should handle unlimited (-1) limit correctly', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().add(const Duration(days: 10)),
        trialConsumed: true,
        pendingRequestDate: null,
      );

      final store = StoreModel(
        storeId: 'test_store',
        storeName: 'Test Store',
        storePassword: 'hashed_password',
        ownerId: 'owner_id',
        ownerName: 'Owner Name',
        ownerEmail: 'owner@test.com',
        subscription: sub,
        settings: StoreSettings(),
      );

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
            maxEmployees: -1, // Unlimited
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      when(() => mockAuthProvider.currentStore).thenReturn(store);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.canAddEmployee(0), isTrue);
      expect(provider.canAddEmployee(999), isTrue);
    });
  });

  group('currentPlanLimits getter', () {
    late StoreModel testStore;

    StoreModel createStoreWithSub({
      required SubscriptionPlan planId,
      required SubscriptionStatus status,
      required DateTime endDate,
      DateTime? pendingRequestDate,
    }) {
      return StoreModel(
        storeId: 'test_store',
        storeName: 'Test Store',
        storePassword: 'hashed_password',
        ownerId: 'owner_id',
        ownerName: 'Owner Name',
        ownerEmail: 'owner@test.com',
        subscription: StoreSubscription(
          planId: planId,
          status: status,
          endDate: endDate,
          trialConsumed: true,
          pendingRequestDate: pendingRequestDate,
        ),
        settings: StoreSettings(),
      );
    }

    test('resolves active plan from catalog via camelCase key', () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().add(const Duration(days: 5)),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
          'proYearly': const SubscriptionPlanModel(
            name: 'Pro Yearly Dynamic',
            description: '',
            isActive: true,
            price: 1500,
            maxWallets: 30,
            maxEmployees: 10,
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.currentPlanLimits.name, equals('Pro Yearly Dynamic'));
      expect(provider.currentPlanLimits.maxWallets, equals(30));
    });

    test('resolves active plan from catalog via snake_case key fallback', () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().add(const Duration(days: 5)),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
            name: 'Pro Yearly Snake Dynamic',
            description: '',
            isActive: true,
            price: 1200,
            maxWallets: 25,
            maxEmployees: 8,
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(
          provider.currentPlanLimits.name, equals('Pro Yearly Snake Dynamic'));
      expect(provider.currentPlanLimits.maxWallets, equals(25));
    });

    test('expired subscription with no pending request returns free plan', () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.expired,
        endDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
          'free': const SubscriptionPlanModel(
            name: 'Dynamic Free Plan',
            description: '',
            isActive: true,
            price: 0,
            maxWallets: 2,
            maxEmployees: 0,
            smsEnabled: false,
          ),
          'pro_yearly': const SubscriptionPlanModel(
            name: 'Pro Yearly Dynamic',
            description: '',
            isActive: true,
            price: 1200,
            maxWallets: 50,
            maxEmployees: 20,
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.currentPlanLimits.name, equals('Dynamic Free Plan'));
      expect(provider.currentPlanLimits.maxWallets, equals(2));
      expect(provider.currentPlanLimits.maxEmployees, equals(0));
    });

    test('expired subscription WITH pending request returns actual plan limits',
        () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.expired,
        endDate: DateTime.now().subtract(const Duration(days: 5)),
        pendingRequestDate: DateTime.now(),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
          'free': const SubscriptionPlanModel(
            name: 'Dynamic Free Plan',
            description: '',
            isActive: true,
            price: 0,
            maxWallets: 2,
            maxEmployees: 0,
            smsEnabled: false,
          ),
          'pro_yearly': const SubscriptionPlanModel(
            name: 'Pro Yearly Dynamic',
            description: '',
            isActive: true,
            price: 1200,
            maxWallets: 50,
            maxEmployees: 20,
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.currentPlanLimits.name, equals('Pro Yearly Dynamic'));
      expect(provider.currentPlanLimits.maxWallets, equals(50));
    });

    test('plan not found in catalog returns catalog free plan', () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().add(const Duration(days: 5)),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
          'free': const SubscriptionPlanModel(
            name: 'Catalog Free Fallback',
            description: '',
            isActive: true,
            price: 0,
            maxWallets: 2,
            maxEmployees: 0,
            smsEnabled: false,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.currentPlanLimits.name, equals('Catalog Free Fallback'));
      expect(provider.currentPlanLimits.maxWallets, equals(2));
    });

    test(
        'both plan and free missing from catalog returns SubscriptionPlanModel.fallback()',
        () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().add(const Duration(days: 5)),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
        plans: const {}, // Empty plans map
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.currentPlanLimits.name, equals('Free'));
      expect(provider.currentPlanLimits.maxWallets, equals(1));
      expect(provider.currentPlanLimits.maxEmployees, equals(1));
      expect(provider.currentPlanLimits.smsEnabled, isFalse);
    });

    test('null subscription returns SubscriptionPlanModel.fallback()', () {
      when(() => mockAuthProvider.currentStore).thenReturn(null);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.currentPlanLimits.name, equals('Free'));
      expect(provider.currentPlanLimits.maxWallets, equals(1));
    });

    test('maxWallets, maxEmployees, isSmsEnabled delegate to currentPlanLimits',
        () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().add(const Duration(days: 5)),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
          'proYearly': const SubscriptionPlanModel(
            name: 'Pro Yearly Dynamic',
            description: '',
            isActive: true,
            price: 1500,
            maxWallets: 30,
            maxEmployees: 10,
            smsEnabled: true,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      expect(provider.maxWallets, equals(30));
      expect(provider.maxEmployees, equals(10));
      expect(provider.isSmsEnabled, isTrue);
    });

    test(
        'maxWallets returns fallback limits when plan missing from catalog (no old hardcoded switch)',
        () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().add(const Duration(days: 5)),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
        plans: const {}, // Empty catalog
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      // In old code, this returned 50 because of the switch fallback.
      // In refactored code, it should return 1 (from fallback).
      expect(provider.maxWallets, equals(1));
      expect(provider.maxEmployees, equals(1));
      expect(provider.isSmsEnabled, isFalse);
    });

    test(
        'unified canAddWallet and canAddEmployee follow catalog free limits when expired',
        () {
      testStore = createStoreWithSub(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.expired,
        endDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      when(() => mockAuthProvider.currentStore).thenReturn(testStore);
      when(() => mockAuthProvider.currentStoreId).thenReturn('test_store');

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
          'free': const SubscriptionPlanModel(
            name: 'Free Plan',
            description: '',
            isActive: true,
            price: 0,
            maxWallets: 1, // Enforced limit of 1
            maxEmployees: 0, // Enforced limit of 0
            smsEnabled: false,
          ),
        },
      );
      when(() => mockPlatformSettingsProvider.settings)
          .thenReturn(mockSettings);

      final provider = SubscriptionProvider(
        authProvider: mockAuthProvider,
        repository: mockSubscriptionRepository,
      );

      // Under old code, expired would allow up to 2 wallets (currentWalletCount < 3)
      // and up to 0 employees (currentEmployeeCount < 1).
      // Under unified code, it uses free limits from catalog: maxWallets (1) and maxEmployees (0).
      expect(provider.canAddWallet(0), isTrue);
      expect(
          provider.canAddWallet(1), isFalse); // Old allowed this because 1 < 3
      expect(provider.canAddEmployee(0),
          isFalse); // Old allowed this because 0 < 1
    });
  });
}
