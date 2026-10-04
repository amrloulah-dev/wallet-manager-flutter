import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

class MockStoreModel extends Mock implements StoreModel {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionRepository mockSubscriptionRepo;
  late MockPlatformSettingsProvider mockPlatformSettingsProvider;
  late MockStoreModel mockStore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    final mockSecureStorage = MockSecureStorage();
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'))).thenAnswer((_) async {});

    await LocalStorageService.instance
        .initialize(secureStorage: mockSecureStorage);

    mockAuthProvider = MockAuthProvider();
    mockSubscriptionRepo = MockSubscriptionRepository();
    mockPlatformSettingsProvider = MockPlatformSettingsProvider();
    mockStore = MockStoreModel();

    final GetIt sl = GetIt.instance;
    await sl.reset();

    sl.registerSingleton<LocalStorageService>(LocalStorageService.instance);
    sl.registerSingleton<PlatformSettingsProvider>(
        mockPlatformSettingsProvider);

    when(() => mockAuthProvider.addListener(any())).thenReturn(null);
    when(() => mockAuthProvider.removeListener(any())).thenReturn(null);
    when(() => mockAuthProvider.refreshUserData()).thenAnswer((_) async {});
    when(() => mockStore.storeId).thenReturn('store-123');

    when(() => mockSubscriptionRepo.getLatestSubscriptionRequest(any()))
        .thenAnswer((_) async => null);

    when(() => mockPlatformSettingsProvider.settings)
        .thenReturn(const PlatformSettingsModel.defaults());
    when(() => mockPlatformSettingsProvider.isInitialized).thenReturn(true);
    when(() => mockPlatformSettingsProvider.addListener(any()))
        .thenReturn(null);
    when(() => mockPlatformSettingsProvider.removeListener(any()))
        .thenReturn(null);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  test(
      'SubscriptionProvider hasSeenSuccessModal returns false when composite key does not match',
      () async {
    final subDate = DateTime(2026, 12, 31);
    final subscription = StoreSubscription(
      planId: SubscriptionPlan.proYearly,
      status: SubscriptionStatus.active,
      endDate: subDate,
      trialConsumed: true,
    );

    when(() => mockAuthProvider.currentStore).thenReturn(mockStore);
    when(() => mockStore.subscription).thenReturn(subscription);

    // Set last seen key to something else
    await LocalStorageService.instance
        .setLastSeenPaymentKey('proYearly_111111111');

    final provider = SubscriptionProvider(
      authProvider: mockAuthProvider,
      repository: mockSubscriptionRepo,
    );

    expect(provider.hasSeenSuccessModal, isFalse);
  });

  test(
      'SubscriptionProvider hasSeenSuccessModal returns true when composite key matches',
      () async {
    final subDate = DateTime(2026, 12, 31);
    final subscription = StoreSubscription(
      planId: SubscriptionPlan.proYearly,
      status: SubscriptionStatus.active,
      endDate: subDate,
      trialConsumed: true,
    );

    final expectedKey = "proYearly_${subDate.millisecondsSinceEpoch}";

    when(() => mockAuthProvider.currentStore).thenReturn(mockStore);
    when(() => mockStore.subscription).thenReturn(subscription);

    // Set matching key in local storage
    await LocalStorageService.instance.setLastSeenPaymentKey(expectedKey);

    final provider = SubscriptionProvider(
      authProvider: mockAuthProvider,
      repository: mockSubscriptionRepo,
    );

    expect(provider.hasSeenSuccessModal, isTrue);
  });

  test(
      'SubscriptionProvider markSuccessModalSeen sets correct composite key in storage',
      () {
    final subDate = DateTime(2026, 12, 31);
    final subscription = StoreSubscription(
      planId: SubscriptionPlan.proYearly,
      status: SubscriptionStatus.active,
      endDate: subDate,
      trialConsumed: true,
    );

    final expectedKey = "proYearly_${subDate.millisecondsSinceEpoch}";

    when(() => mockAuthProvider.currentStore).thenReturn(mockStore);
    when(() => mockStore.subscription).thenReturn(subscription);

    final provider = SubscriptionProvider(
      authProvider: mockAuthProvider,
      repository: mockSubscriptionRepo,
    );
    provider.markSuccessModalSeen();

    expect(LocalStorageService.instance.lastSeenPaymentKey, expectedKey);
  });
}
