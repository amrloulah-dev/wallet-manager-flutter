// T053-T054: Notification Batching Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/device_repository.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockStoreRepository extends Mock implements StoreRepository {}
class MockUserRepository extends Mock implements UserRepository {}
class MockDeviceRepository extends Mock implements DeviceRepository {}
class MockLicenseKeyRepository extends Mock implements LicenseKeyRepository {}
class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  final sl = GetIt.instance;

  setUpAll(() {
    AnalyticsService.isTestMode = true;
    AppErrorHandler.isTestMode = true;
  });

  setUp(() {
    sl.reset();
    sl.registerSingleton<AuthRepository>(MockAuthRepository());
    sl.registerSingleton<StoreRepository>(MockStoreRepository());
    sl.registerSingleton<UserRepository>(MockUserRepository());
    sl.registerSingleton<DeviceRepository>(MockDeviceRepository());
    sl.registerSingleton<LicenseKeyRepository>(MockLicenseKeyRepository());
    sl.registerSingleton<LocalStorageService>(MockLocalStorageService());

    // Setup basic expectations
    final mockStorage = sl<LocalStorageService>();
    when(() => mockStorage.userId).thenReturn(null);
    when(() => mockStorage.storeId).thenReturn(null);
    when(() => mockStorage.userRole).thenReturn(null);

    final mockAuth = sl<AuthRepository>();
    when(() => mockAuth.getCurrentUser()).thenReturn(null);
    when(() => mockAuth.authStateChanges()).thenAnswer((_) => const Stream.empty());
  });

  group('T053-T054 Notification Batching', () {
    // ── AuthProvider disposal safety ──────────────────────────────────────────

    group('AuthProvider._safeNotify disposal guard', () {
      test('_safeNotify does not fire after dispose()', () async {
        final authProvider = AuthProvider();
        
        int callCount = 0;
        authProvider.addListener(() {
          callCount++;
        });

        authProvider.dispose();
        
        // This will attempt to notifyListeners internally.
        expect(() => authProvider.logout(), returnsNormally);
        
        expect(callCount, 0, reason: 'Must not emit notification after dispose');
      });
    });
  });
}
