import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
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

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionRepository mockSubscriptionRepository;

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

    when(() => mockAuthProvider.addListener(any())).thenReturn(null);
    when(() => mockAuthProvider.removeListener(any())).thenReturn(null);
    when(() => mockAuthProvider.refreshUserData()).thenAnswer((_) async {});
    when(() => mockSubscriptionRepository.getLatestSubscriptionRequest(any()))
        .thenAnswer((_) async => null);
  });

  test('maxWallets and maxEmployees return 2 and 0 when expired', () {
    final sub = StoreSubscription(
      planId: SubscriptionPlan.proYearly,
      status: SubscriptionStatus.expired,
      endDate: DateTime.now().subtract(const Duration(days: 10)),
      trialConsumed: true,
      maxWallets: 50,
      maxEmployees: 20,
      smsEnabled: true,
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
      maxWallets: 50,
      maxEmployees: 20,
      smsEnabled: true,
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
        maxWallets: 50,
        maxEmployees: 5,
        smsEnabled: true,
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
        maxWallets: 50,
        maxEmployees: -1, // Unlimited
        smsEnabled: true,
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

      expect(provider.canAddEmployee(0), isTrue);
      expect(provider.canAddEmployee(999), isTrue);
    });
  });
}
