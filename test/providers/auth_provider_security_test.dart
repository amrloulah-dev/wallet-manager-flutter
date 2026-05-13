import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/core/services/database_sync_service.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:walletmanager/core/services/analytics_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockDatabaseSyncService extends Mock implements DatabaseSyncService {}
class MockStoreRepository extends Mock implements StoreRepository {}
class MockUserRepository extends Mock implements UserRepository {}
class MockLicenseKeyRepository extends Mock implements LicenseKeyRepository {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AuthProvider Security Integration Tests', () {
    late AuthProvider authProvider;
    late MockAuthRepository mockAuthRepository;
    late MockDatabaseSyncService mockDatabaseSyncService;
    late MockStoreRepository mockStoreRepository;
    late MockUserRepository mockUserRepository;
    late MockLicenseKeyRepository mockLicenseKeyRepository;
    late LocalStorageService storage;
    late MockFlutterSecureStorage mockSecureStorage;

    setUp(() async {
      AnalyticsService.isTestMode = true;
      SharedPreferences.setMockInitialValues({});
      mockAuthRepository = MockAuthRepository();
      mockDatabaseSyncService = MockDatabaseSyncService();
      mockStoreRepository = MockStoreRepository();
      mockUserRepository = MockUserRepository();
      mockLicenseKeyRepository = MockLicenseKeyRepository();
      mockSecureStorage = MockFlutterSecureStorage();

      when(() => mockSecureStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async => {});
      
      when(() => mockDatabaseSyncService.tryAutoLogin())
          .thenAnswer((_) async => null);
      when(() => mockAuthRepository.signOut())
          .thenAnswer((_) async => {});

      storage = LocalStorageService.instance;
      await storage.initialize(secureStorage: mockSecureStorage);

      authProvider = AuthProvider(
        authRepository: mockAuthRepository,
        databaseSyncService: mockDatabaseSyncService,
        storeRepository: mockStoreRepository,
        userRepository: mockUserRepository,
        licenseKeyRepository: mockLicenseKeyRepository,
        localStorage: storage,
      );
    });

    tearDown(() {
      LocalStorageService.reset();
    });

    test('currentUserId should retrieve value from secure storage via LocalStorageService', () async {
      when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
      when(() => mockSecureStorage.read(key: 'userId')).thenAnswer((_) async => 'secure_123');
      
      // Reload disk to simulate cache update if it was written by another isolate, 
      // but here we just want to ensure it reads through the service.
      await storage.reloadDisk();

      expect(authProvider.currentUserId, 'secure_123');
      verify(() => mockSecureStorage.read(key: 'userId')).called(greaterThan(0));
    });
  });
}
