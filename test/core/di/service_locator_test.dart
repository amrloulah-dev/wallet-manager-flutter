import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/data/repositories/system_config_repository.dart';
import 'package:walletmanager/data/repositories/device_repository.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/data/services/wallet_cache_manager.dart';
import 'package:walletmanager/domain/usecases/wallet_usecase.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('Service Locator Tests', () {
    late MockFlutterSecureStorage mockSecureStorage;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      mockSecureStorage = MockFlutterSecureStorage();
      when(() => mockSecureStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async => {});

      await sl.reset();
      LocalStorageService.reset();
      await LocalStorageService.instance
          .initialize(secureStorage: mockSecureStorage);
      await setupServiceLocator();
    });

    test('should register all 12 repositories as lazy singletons', () {
      expect(sl.isRegistered<AuthRepository>(), isTrue);
      expect(sl.isRegistered<WalletRepository>(), isTrue);
      expect(sl.isRegistered<TransactionRepository>(), isTrue);
      expect(sl.isRegistered<DebtRepository>(), isTrue);
      expect(sl.isRegistered<EmployeeRepository>(), isTrue);
      expect(sl.isRegistered<StoreRepository>(), isTrue);
      expect(sl.isRegistered<StatsRepository>(), isTrue);
      expect(sl.isRegistered<SubscriptionRepository>(), isTrue);
      expect(sl.isRegistered<SystemConfigRepository>(), isTrue);
      expect(sl.isRegistered<DeviceRepository>(), isTrue);
      expect(sl.isRegistered<LicenseKeyRepository>(), isTrue);
      expect(sl.isRegistered<UserRepository>(), isTrue);
    });

    test('should verify LocalStorageService is registered', () {
      expect(sl.isRegistered<LocalStorageService>(), isTrue);
    });

    test('should verify WalletCacheManager is registered', () {
      expect(sl.isRegistered<WalletCacheManager>(), isTrue);
    });

    test('should verify WalletUseCase is registered', () {
      expect(sl.isRegistered<WalletUseCase>(), isTrue);
    });

    test('should verify Firebase services are registered', () {
      expect(sl.isRegistered<FirebaseFirestore>(), isTrue);
      expect(sl.isRegistered<FirebaseAuth>(), isTrue);
    });
  });
}
