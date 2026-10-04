import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/data/repositories/device_repository.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/core/services/database_sync_service.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockStoreRepository extends Mock implements StoreRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockLicenseKeyRepository extends Mock implements LicenseKeyRepository {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

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

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockUserRepo = MockUserRepository();
    mockStoreRepo = MockStoreRepository();
    mockStorage = MockLocalStorageService();
    mockAuthRepo = MockAuthRepository();
    when(() => mockAuthRepo.authStateChanges())
        .thenAnswer((_) => const Stream.empty());
    mockDeviceRepo = MockDeviceRepository();
    mockLicenseRepo = MockLicenseKeyRepository();
    mockSubRepo = MockSubscriptionRepository();
    final mockFirebaseService = MockFirebaseService();
    final mockFirestore = MockFirebaseFirestore();

    final mockAuth = MockFirebaseAuth();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockStorage.userId).thenReturn(null);
    when(() => mockStorage.storeId).thenReturn(null);
    when(() => mockStorage.userRole).thenReturn(UserRole.unknown);

    sl.allowReassignment = true;
    sl.registerSingleton<FirebaseService>(mockFirebaseService);
    sl.registerSingleton<FirebaseAuth>(mockAuth);
    sl.registerSingleton<SubscriptionRepository>(mockSubRepo);

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
  });

  group('AuthProvider.sendPasswordReset', () {
    test('throws error if email is empty', () async {
      await authProvider.sendPasswordReset('');
      expect(authProvider.errorMessage, equals('auth_error_invalid_email'));
    });

    test('throws error if email format is invalid', () async {
      await authProvider.sendPasswordReset('invalid-email');
      expect(authProvider.errorMessage, equals('auth_error_invalid_email'));
    });

    test('calls repository when email is valid', () async {
      when(() => mockAuthRepo.sendPasswordResetEmail(any()))
          .thenAnswer((_) async => {});

      await authProvider.sendPasswordReset('test@example.com');

      verify(() => mockAuthRepo.sendPasswordResetEmail('test@example.com'))
          .called(1);
      expect(authProvider.errorMessage, isNull);
    });

    test('maps user-not-found error code correctly', () async {
      when(() => mockAuthRepo.sendPasswordResetEmail(any()))
          .thenThrow(UserNotFoundException());

      await authProvider.sendPasswordReset('nonexistent@example.com');

      expect(authProvider.errorMessage, equals('auth_error_account_not_found'));
    });

    test('maps invalid-email error code correctly', () async {
      when(() => mockAuthRepo.sendPasswordResetEmail(any()))
          .thenThrow(AuthException('auth_error_invalid_email'));

      await authProvider.sendPasswordReset('bad@email.com');

      expect(authProvider.errorMessage, equals('auth_error_invalid_email'));
    });

    test('maps too-many-requests error code correctly', () async {
      when(() => mockAuthRepo.sendPasswordResetEmail(any()))
          .thenThrow(AuthException('auth_error_too_many_requests'));

      await authProvider.sendPasswordReset('busy@example.com');

      expect(authProvider.errorMessage, equals('auth_error_too_many_requests'));
    });
  });
}
