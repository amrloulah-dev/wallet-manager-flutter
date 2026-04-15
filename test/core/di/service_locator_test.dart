import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  group('Service Locator Tests', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      sl.reset();
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
  });
}
