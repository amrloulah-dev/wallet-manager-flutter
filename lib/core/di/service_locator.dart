import 'package:get_it/get_it.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/license_key_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/repositories/store_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/repositories/system_config_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/services/local_storage_service.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services
  final localStorage = LocalStorageService();
  await localStorage.initialize();
  sl.registerSingleton<LocalStorageService>(localStorage);

  // Repositories — Lazy Singletons
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  sl.registerLazySingleton<WalletRepository>(() => WalletRepository());
  sl.registerLazySingleton<TransactionRepository>(() => TransactionRepository());
  sl.registerLazySingleton<DebtRepository>(() => DebtRepository());
  sl.registerLazySingleton<EmployeeRepository>(() => EmployeeRepository());
  sl.registerLazySingleton<StoreRepository>(() => StoreRepository());
  sl.registerLazySingleton<StatsRepository>(() => StatsRepository());
  sl.registerLazySingleton<SubscriptionRepository>(() => SubscriptionRepository());
  sl.registerLazySingleton<SystemConfigRepository>(() => SystemConfigRepository());
  sl.registerLazySingleton<DeviceRepository>(() => DeviceRepository());
  sl.registerLazySingleton<LicenseKeyRepository>(() => LicenseKeyRepository());
  sl.registerLazySingleton<UserRepository>(() => UserRepository());
}
