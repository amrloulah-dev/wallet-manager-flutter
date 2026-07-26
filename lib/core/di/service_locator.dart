import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
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
import '../../data/services/wallet_cache_manager.dart';
import '../../providers/auth_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/app_events.dart';
import '../../domain/usecases/identity_migration_usecase.dart';
import '../../domain/usecases/overlay_usecase.dart';
import '../../domain/usecases/transaction_fee_calculator.dart';
import '../../domain/usecases/wallet_usecase.dart';
import '../../core/services/database_sync_service.dart';

import '../../data/services/firebase_service.dart';
import '../../core/utils/cache_manager.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── 1. External Services ──────────────────────────────────
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerFactoryParam<FirebaseAuth, FirebaseApp?, void>(
    (app, _) => app != null
        ? FirebaseAuth.instanceFor(app: app)
        : FirebaseAuth.instance,
  );
  sl.registerLazySingleton<FirebaseService>(() => FirebaseService());
  sl.registerLazySingleton<CacheManager>(() => CacheManager());

  // ── 2. Local Services ─────────────────────────────────────
  final localStorage = LocalStorageService();
  await localStorage.initialize();
  sl.registerSingleton<LocalStorageService>(localStorage);
  sl.registerLazySingleton<WalletCacheManager>(
      () => WalletCacheManager(storage: localStorage));
  sl.registerLazySingleton<AppEvents>(() => AppEvents());

  // ── 3. Repositories ───────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  sl.registerLazySingleton<WalletRepository>(() => WalletRepository());
  sl.registerLazySingleton<TransactionRepository>(
      () => TransactionRepository());
  sl.registerLazySingleton<DebtRepository>(() => DebtRepository());
  sl.registerLazySingleton<EmployeeRepository>(() => EmployeeRepository());
  sl.registerLazySingleton<StoreRepository>(() => StoreRepository());
  sl.registerLazySingleton<StatsRepository>(() => StatsRepository());
  sl.registerLazySingleton<SubscriptionRepository>(
      () => SubscriptionRepository());
  sl.registerLazySingleton<SystemConfigRepository>(
      () => SystemConfigRepository());
  sl.registerLazySingleton<DeviceRepository>(() => DeviceRepository());
  sl.registerLazySingleton<LicenseKeyRepository>(() => LicenseKeyRepository());
  sl.registerLazySingleton<UserRepository>(() => UserRepository());

  // ── 4. Composite Services (depend on repositories) ────────
  sl.registerLazySingleton<DatabaseSyncService>(() => DatabaseSyncService(
        authRepository: sl<AuthRepository>(),
        storeRepository: sl<StoreRepository>(),
        userRepository: sl<UserRepository>(),
        deviceRepository: sl<DeviceRepository>(),
        localStorage: sl<LocalStorageService>(),
        firestore: sl<FirebaseFirestore>(),
        subscriptionRepository: sl<SubscriptionRepository>(),
      ));

  // ── 5. Providers (depend on repositories & composite services) ──
  sl.registerLazySingleton<AuthProvider>(() => AuthProvider());
  sl.registerLazySingleton<PlatformSettingsProvider>(
      () => PlatformSettingsProvider());

  // ── 6. UseCases (depend on providers & repositories) ─────
  sl.registerLazySingleton<TransactionFeeCalculator>(
      () => TransactionFeeCalculator());
  sl.registerLazySingleton<WalletUseCase>(() => WalletUseCase(
        authProvider: sl<AuthProvider>(),
      ));
  sl.registerLazySingleton<OverlayUseCase>(() => OverlayUseCase(
        transactionRepository: sl<TransactionRepository>(),
        localStorage: sl<LocalStorageService>(),
      ));
  sl.registerLazySingleton<IdentityMigrationUseCase>(
      () => IdentityMigrationUseCase());
}
