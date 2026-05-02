import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/core/services/identity_service.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/data/repositories/device_repository.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/core/services/database_sync_service.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

class MockUserRepository extends Mock implements UserRepository {}
class MockStoreRepository extends Mock implements StoreRepository {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockAuthRepository extends Mock implements AuthRepository {}
class MockDeviceRepository extends Mock implements DeviceRepository {}
class MockLicenseKeyRepository extends Mock implements LicenseKeyRepository {}
class MockSubscriptionRepository extends Mock implements SubscriptionRepository {}
class MockUser extends Mock implements User {}
class MockFirebaseService extends Mock implements FirebaseService {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockUserRepository mockUserRepo;
  late MockStoreRepository mockStoreRepo;
  late MockLocalStorageService mockStorage;
  late AuthProvider authProvider;
  late MockAuthRepository mockAuthRepo;
  late MockDeviceRepository mockDeviceRepo;
  late MockLicenseKeyRepository mockLicenseRepo;
  late MockSubscriptionRepository mockSubRepo;
  
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  late UserModel mockEmployee;
  late StoreModel mockStore;

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockUserRepo = MockUserRepository();
    mockStoreRepo = MockStoreRepository();
    mockStorage = MockLocalStorageService();
    mockAuthRepo = MockAuthRepository();
    mockDeviceRepo = MockDeviceRepository();
    mockLicenseRepo = MockLicenseKeyRepository();
    mockSubRepo = MockSubscriptionRepository();
    mockAuth = MockFirebaseAuth();
    final mockFirebaseService = MockFirebaseService();
    final mockFirestore = MockFirebaseFirestore();
    
    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    sl.allowReassignment = true;
    sl.registerSingleton<FirebaseService>(mockFirebaseService);
    sl.registerSingleton<FirebaseAuth>(mockAuth);
    sl.registerSingleton<SubscriptionRepository>(mockSubRepo);
    
    when(() => mockAuthRepo.getCurrentUser()).thenReturn(null);

    final databaseSyncService = DatabaseSyncService(
      authRepository: mockAuthRepo,
      storeRepository: mockStoreRepo,
      userRepository: mockUserRepo,
      deviceRepository: mockDeviceRepo,
      localStorage: mockStorage,
    );

    authProvider = AuthProvider(
      authRepository: mockAuthRepo,
      databaseSyncService: databaseSyncService,
      licenseKeyRepository: mockLicenseRepo,
      userRepository: mockUserRepo,
      storeRepository: mockStoreRepo,
      localStorage: mockStorage,
    );
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();
    
    when(() => mockUser.uid).thenReturn('test-uid');
    when(() => mockUserCredential.user).thenReturn(mockUser);
    
    IdentityService.authOverride = mockAuth;

    mockStore = StoreModel(
      storeId: 'store-123',
      storeName: 'Test Store',
      storePassword: 'hashed',
      ownerId: 'owner-123',
      ownerName: 'Owner',
      ownerEmail: 'owner@store.com',
      createdAt: DateTime.now(),
      subscription: StoreSubscription(
        planId: SubscriptionPlan.free,
        status: SubscriptionStatus.active,
        trialConsumed: false,
        maxWallets: 3,
        maxEmployees: 1,
        smsEnabled: false,
      ),
      settings: StoreSettings(currency: 'SAR', timezone: 'Asia/Riyadh'),
      stats: StoreStats(lastUpdated: DateTime.now()),
    );

    mockEmployee = UserModel(
      userId: 'emp-123',
      storeId: 'store-123',
      role: UserRole.employee,
      fullName: 'Test Employee',
      phone: '123456789',
      pin: 'hashed_pin',
      firebaseUid: 'test-uid',
      isActive: true,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      permissions: UserPermissions(
        createTransaction: true,
        viewAllTransactions: true,
        viewDebts: false,
        createDebt: false,
        collectDebt: false,
      ),
    );

    when(() => mockUserRepo.updateLastLogin(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveSession(
       userId: any(named: 'userId'),
       storeId: any(named: 'storeId'),
       userRole: any(named: 'userRole'),
       userName: any(named: 'userName'),
       storeName: any(named: 'storeName'),
    )).thenAnswer((_) async {});
  });

  group('AuthProvider Employee Login', () {
    test('login with firebaseUid authenticates via IdentityService', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_${mockEmployee.phone}_${mockStore.storeId}@store.com',
            password: 'hashed_pin',
          )).thenAnswer((_) async => mockUserCredential);

      final success = await authProvider.loginAsEmployee(mockEmployee, mockStore);

      expect(success, isTrue);
      verify(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_${mockEmployee.phone}_${mockStore.storeId}@store.com',
            password: 'hashed_pin',
          )).called(1);
    });

    test('login without firebaseUid falls back to local pin silently and triggers background provision', () async {
      final legacyEmployee = mockEmployee.copyWith(firebaseUid: '');
      
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'emp_${legacyEmployee.phone}_${mockStore.storeId}@store.com',
            password: 'hashed_pin',
          )).thenAnswer((_) async => mockUserCredential);
          
      when(() => mockUserRepo.updateUser(any(), any())).thenAnswer((_) async {});

      final success = await authProvider.loginAsEmployee(legacyEmployee, mockStore);

      expect(success, isTrue);
      
      verifyNever(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_${legacyEmployee.phone}_${mockStore.storeId}@store.com',
            password: 'hashed_pin',
          ));
          
      await Future.delayed(const Duration(milliseconds: 50));
      verify(() => mockAuth.createUserWithEmailAndPassword(
            email: 'emp_${legacyEmployee.phone}_${mockStore.storeId}@store.com',
            password: 'hashed_pin',
          )).called(1);
    });

    test('failed login shows user-visible error via AppErrorHandler', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_${mockEmployee.phone}_${mockStore.storeId}@store.com',
            password: 'hashed_pin',
          )).thenThrow(FirebaseAuthException(code: 'wrong-password'));
      when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});
      when(() => mockStorage.clearSession()).thenAnswer((_) async {});

      final success = await authProvider.loginAsEmployee(mockEmployee, mockStore);

      expect(success, isFalse);
      expect(authProvider.errorMessage, equals('auth_error_invalid_credentials'));
    });
  });
}
