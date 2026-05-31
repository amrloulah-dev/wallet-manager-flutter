import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/core/services/database_sync_service.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/store_model.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockStoreRepository extends Mock implements StoreRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDatabaseSyncService extends Mock implements DatabaseSyncService {}

class MockLicenseKeyRepository extends Mock implements LicenseKeyRepository {}

class MockFirebaseService extends Mock implements FirebaseService {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserModel extends Mock implements UserModel {}

class MockStoreModel extends Mock implements StoreModel {}

class UserModelFake extends Fake implements UserModel {}

class StoreModelFake extends Fake implements StoreModel {}

class TestAuthProvider extends AuthProvider {
  StackTrace? lastStack;
  Object? lastError;

  TestAuthProvider({
    required super.authRepository,
    required super.databaseSyncService,
    required super.licenseKeyRepository,
    required super.userRepository,
    required super.storeRepository,
    required super.localStorage,
  });

  @override
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'auth_operation']) {
    lastStack = stack;
    lastError = error;
    super.setError(errorCode, error, stack, showToast, operation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockUserRepository mockUserRepo;
  late MockStoreRepository mockStoreRepo;
  late MockLocalStorageService mockStorage;
  late TestAuthProvider authProvider;
  late MockAuthRepository mockAuthRepo;
  late MockDatabaseSyncService mockDatabaseSyncService;
  late MockLicenseKeyRepository mockLicenseRepo;

  setUpAll(() {
    registerFallbackValue(UserModelFake());
    registerFallbackValue(StoreModelFake());
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockUserRepo = MockUserRepository();
    mockStoreRepo = MockStoreRepository();
    mockStorage = MockLocalStorageService();
    mockAuthRepo = MockAuthRepository();
    when(() => mockAuthRepo.authStateChanges()).thenAnswer((_) => const Stream.empty());
    mockDatabaseSyncService = MockDatabaseSyncService();
    mockLicenseRepo = MockLicenseKeyRepository();

    final mockFirebaseService = MockFirebaseService();
    final mockFirestore = MockFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});
    when(() => mockStorage.clearSession()).thenAnswer((_) async {});

    // Stub tryAutoLogin to avoid microtask crash in constructor
    when(() => mockDatabaseSyncService.tryAutoLogin())
        .thenAnswer((_) async => null);

    sl.allowReassignment = true;
    sl.registerSingleton<FirebaseService>(mockFirebaseService);
    sl.registerSingleton<FirebaseAuth>(mockAuth);

    authProvider = TestAuthProvider(
      authRepository: mockAuthRepo,
      databaseSyncService: mockDatabaseSyncService,
      licenseKeyRepository: mockLicenseRepo,
      userRepository: mockUserRepo,
      storeRepository: mockStoreRepo,
      localStorage: mockStorage,
    );
  });

  group('AuthProvider Error Propagation', () {
    test('tryAutoLogin propagates stack trace on error', () async {
      final exception = Exception('AutoLogin failed');
      when(() => mockDatabaseSyncService.tryAutoLogin()).thenThrow(exception);

      await authProvider.tryAutoLogin();

      expect(authProvider.lastError, equals(exception));
      expect(authProvider.lastStack, isNotNull);
    });

    test('loginWithGoogleOrNull propagates stack trace on error', () async {
      final exception = Exception('Google login failed');
      when(() => mockDatabaseSyncService.loginWithGoogleOrNull())
          .thenThrow(exception);

      await authProvider.loginWithGoogleOrNull();

      expect(authProvider.lastError, equals(exception));
      expect(authProvider.lastStack, isNotNull);
    });

    test('registerStoreWithGoogle propagates stack trace on error', () async {
      final exception = Exception('Registration failed');
      when(() => mockDatabaseSyncService.registerStoreWithGoogle(
            storeName: any(named: 'storeName'),
            storePassword: any(named: 'storePassword'),
          )).thenThrow(exception);

      try {
        await authProvider.registerStoreWithGoogle(
            storeName: 'Test', storePassword: 'password');
      } catch (_) {}

      expect(authProvider.lastError, equals(exception));
      expect(authProvider.lastStack, isNotNull);
    });

    test('loginAsEmployee propagates stack trace on error', () async {
      final exception = Exception('Employee login failed');
      final mockEmployee = MockUserModel();
      final mockStore = MockStoreModel();
      when(() => mockDatabaseSyncService.loginAsEmployee(any(), any()))
          .thenThrow(exception);

      await authProvider.loginAsEmployee(mockEmployee, mockStore);

      expect(authProvider.lastError, equals(exception));
      expect(authProvider.lastStack, isNotNull);
    });

    test('updateEmployeeStats propagates stack trace on error', () async {
      final exception = Exception('Update stats failed');
      when(() => mockUserRepo.updateEmployeeStats(
            userId: any(named: 'userId'),
            incrementTransactions: any(named: 'incrementTransactions'),
            incrementCommission: any(named: 'incrementCommission'),
            incrementDebts: any(named: 'incrementDebts'),
          )).thenThrow(exception);

      await authProvider.updateEmployeeStats(userId: 'user123');

      expect(authProvider.lastError, equals(exception));
      expect(authProvider.lastStack, isNotNull);
    });
  });
}

