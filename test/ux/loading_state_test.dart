import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/core/services/database_sync_service.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDatabaseSyncService extends Mock implements DatabaseSyncService {}

class MockStoreRepository extends Mock implements StoreRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockLicenseKeyRepository extends Mock implements LicenseKeyRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockFirebaseService extends Mock implements FirebaseService {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthRepository mockAuthRepo;
  late MockDatabaseSyncService mockDatabaseSyncService;
  late MockStoreRepository mockStoreRepo;
  late MockUserRepository mockUserRepo;
  late MockLicenseKeyRepository mockLicenseRepo;
  late MockLocalStorageService mockStorage;
  late AuthProvider authProvider;

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockAuthRepo = MockAuthRepository();
    mockDatabaseSyncService = MockDatabaseSyncService();
    mockStoreRepo = MockStoreRepository();
    mockUserRepo = MockUserRepository();
    mockLicenseRepo = MockLicenseKeyRepository();
    mockStorage = MockLocalStorageService();

    final mockFirebaseService = MockFirebaseService();
    final mockFirestore = MockFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});
    when(() => mockStorage.clearSession()).thenAnswer((_) async {});
    when(() => mockDatabaseSyncService.tryAutoLogin())
        .thenAnswer((_) async => null);

    sl.allowReassignment = true;
    sl.registerSingleton<FirebaseService>(mockFirebaseService);
    sl.registerSingleton<FirebaseAuth>(mockAuth);

    authProvider = AuthProvider(
      authRepository: mockAuthRepo,
      databaseSyncService: mockDatabaseSyncService,
      storeRepository: mockStoreRepo,
      userRepository: mockUserRepo,
      licenseKeyRepository: mockLicenseRepo,
      localStorage: mockStorage,
    );
  });

  group('Loading State Safety', () {
    test('loginOwnerWithEmail resets loading state on error', () async {
      when(() => mockDatabaseSyncService.loginOwnerWithEmail(any(), any()))
          .thenThrow(Exception('Login failed'));

      try {
        await authProvider.loginOwnerWithEmail('test@example.com', 'password');
      } catch (_) {}

      expect(authProvider.isLoading, isFalse);
    });

    test('findStoreByEmail resets loading state on error', () async {
      when(() => mockStoreRepo.getStoreByEmail(any()))
          .thenThrow(Exception('Lookup failed'));

      await authProvider.findStoreByEmail('test@example.com');

      expect(authProvider.isLoading, isFalse);
    });

    test('registerStoreWithGoogle resets loading state on error', () async {
      when(() => mockDatabaseSyncService.registerStoreWithGoogle(
            storeName: any(named: 'storeName'),
            storePassword: any(named: 'storePassword'),
          )).thenThrow(Exception('Reg failed'));

      try {
        await authProvider.registerStoreWithGoogle(
            storeName: 'Test', storePassword: 'pass');
      } catch (_) {}

      expect(authProvider.isLoading, isFalse);
    });
  });
}
