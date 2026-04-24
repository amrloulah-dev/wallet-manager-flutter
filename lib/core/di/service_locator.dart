import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../../data/repositories/overlay_repository.dart';
import '../../data/services/local_storage_service.dart';
import '../../domain/usecases/overlay_usecase.dart';
import '../../domain/usecases/transaction_fee_calculator.dart';
import '../../core/services/database_sync_service.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External Services
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerFactoryParam<FirebaseAuth, FirebaseApp?, void>(
    (app, _) => app != null ? FirebaseAuth.instanceFor(app: app) : FirebaseAuth.instance,
  );

  // Services
  final localStorage = LocalStorageService();
  await localStorage.initialize();
  sl.registerSingleton<LocalStorageService>(localStorage);

  sl.registerLazySingleton<DatabaseSyncService>(() => DatabaseSyncService(
    authRepository: sl<AuthRepository>(),
    storeRepository: sl<StoreRepository>(),
    userRepository: sl<UserRepository>(),
    deviceRepository: sl<DeviceRepository>(),
    localStorage: sl<LocalStorageService>(),
  ));

  // UseCases
  sl.registerLazySingleton<TransactionFeeCalculator>(() => TransactionFeeCalculator());


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
  sl.registerLazySingleton<OverlayRepository>(() => OverlayRepository());

  // UseCases
  sl.registerLazySingleton<OverlayUseCase>(() => OverlayUseCase(
    transactionRepository: sl<TransactionRepository>(),
    overlayRepository: sl<OverlayRepository>(),
  ));
}
