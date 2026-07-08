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
    sl.registerSingleton<PlatformSettingsProvider>(mockPlatformSettingsProvider);

    when(() => mockAuthProvider.addListener(any())).thenReturn(null);
    when(() => mockAuthProvider.removeListener(any())).thenReturn(null);
    when(() => mockAuthProvider.refreshUserData()).thenAnswer((_) async {});
    when(() => mockSubscriptionRepository.getLatestSubscriptionRequest(any()))
        .thenAnswer((_) async => null);

    // Default settings stub
    const settings = PlatformSettingsModel.defaults();
    when(() => mockPlatformSettingsProvider.settings).thenReturn(settings);
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
            maxEmployees: -1, // Unlimited
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

      expect(provider.canAddEmployee(0), isTrue);
      expect(provider.canAddEmployee(999), isTrue);
    });
  });
}
