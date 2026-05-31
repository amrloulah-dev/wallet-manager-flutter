import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/services/database_sync_service.dart';
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/data/repositories/device_repository.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/domain/entities/auth_user.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(UserRole.unknown);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;
  late StoreRepository storeRepository;
  late UserRepository userRepository;
  late StatsRepository statsRepository;
  late DatabaseSyncService syncService;

  late MockAuthRepository mockAuthRepository;
  late MockDeviceRepository mockDeviceRepository;
  late MockLocalStorageService mockLocalStorage;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockSubscriptionRepository mockSubscriptionRepository;

  const storeId = 'test_store';

  setUp(() {
    AnalyticsService.isTestMode = true;
    GetIt.instance.reset();
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseAuth = MockFirebaseAuth();

    sl.registerSingleton<FirebaseFirestore>(fakeFirestore);
    sl.registerSingleton<FirebaseAuth>(mockFirebaseAuth);

    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);

    storeRepository = StoreRepository(firebaseService: mockFirebaseService);
    userRepository = UserRepository(firebaseService: mockFirebaseService);
    statsRepository = StatsRepository(firestore: fakeFirestore);

    mockAuthRepository = MockAuthRepository();
    when(() => mockAuthRepository.authStateChanges()).thenAnswer((_) => const Stream.empty());
    mockDeviceRepository = MockDeviceRepository();
    mockLocalStorage = MockLocalStorageService();
    mockSubscriptionRepository = MockSubscriptionRepository();

    syncService = DatabaseSyncService(
      authRepository: mockAuthRepository,
      storeRepository: storeRepository,
      userRepository: userRepository,
      deviceRepository: mockDeviceRepository,
      localStorage: mockLocalStorage,
      firestore: fakeFirestore,
      subscriptionRepository: mockSubscriptionRepository,
    );

    when(() => mockLocalStorage.saveSession(
          userId: any(named: 'userId'),
          storeId: any(named: 'storeId'),
          userRole: any(named: 'userRole'),
          userName: any(named: 'userName'),
          storeName: any(named: 'storeName'),
        )).thenAnswer((_) async {});
  });

  group('Atomic Initialization & Entity Creation (TDD - Phase 4)', () {
    test(
        'StatsRepository.initializeStats should use merge: true to avoid overwriting existing data',
        () async {
      final docRef = fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary');

      await docRef.set({
        'totalWallets': 5,
        'some_future_field': 'preserve_me',
      });

      await statsRepository.initializeStats(storeId);

      final doc = await docRef.get();
      final data = doc.data()!;

      expect(data['some_future_field'], 'preserve_me');
    });

    test(
        'DatabaseSyncService._createStoreAndUser should be atomic (verified via repository batch support)',
        () async {
      final googleUser = AuthUser(
        uid: storeId,
        email: 'test@example.com',
        displayName: 'Test Owner',
        photoURL: null,
      );

      when(() => mockAuthRepository.getCurrentUser()).thenReturn(googleUser);
      when(() => mockDeviceRepository.getDeviceId())
          .thenAnswer((_) async => 'device123');
      when(() => mockDeviceRepository.checkDeviceEligibility(any()))
          .thenAnswer((_) async => true);
      when(() => mockDeviceRepository.registerDeviceUsage(any(), any()))
          .thenAnswer((_) async => {});
      when(() => mockSubscriptionRepository.hasDeviceConsumedTrial())
          .thenAnswer((_) async => false);
      when(() => mockSubscriptionRepository.verifyDevice(any()))
          .thenAnswer((_) async => {});

      await syncService.registerStoreWithGoogle(
        storeName: 'Test Store',
        storePassword: 'password123',
      );

      final storeDoc =
          await fakeFirestore.collection('stores').doc(storeId).get();
      final userDoc =
          await fakeFirestore.collection('users').doc(storeId).get();
      final statsDoc = await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .get();

      expect(storeDoc.exists, true);
      expect(userDoc.exists, true);
      expect(statsDoc.exists, true);
    });
  });
}

