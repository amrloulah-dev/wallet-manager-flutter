import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:walletmanager/data/repositories/auth_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/device_repository.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/errors/error_severity.dart';
import 'package:walletmanager/core/services/identity_service.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/services/time_service.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/data/services/firebase_service.dart';

class AuthSessionResult {
  final UserModel user;
  final StoreModel store;
  final bool isExpired;

  AuthSessionResult({
    required this.user,
    required this.store,
    this.isExpired = false,
  });
}

class DatabaseSyncService {
  final AuthRepository _authRepository;
  final StoreRepository _storeRepository;
  final UserRepository _userRepository;
  final DeviceRepository _deviceRepository;
  final LocalStorageService _localStorage;
  final FirebaseFirestore _firestore;
  final SubscriptionRepository _subscriptionRepository;

  DatabaseSyncService({
    required AuthRepository authRepository,
    required StoreRepository storeRepository,
    required UserRepository userRepository,
    required DeviceRepository deviceRepository,
    required LocalStorageService localStorage,
    FirebaseFirestore? firestore,
    SubscriptionRepository? subscriptionRepository,
  })  : _authRepository = authRepository,
        _storeRepository = storeRepository,
        _userRepository = userRepository,
        _deviceRepository = deviceRepository,
        _localStorage = localStorage,
        _firestore = firestore ?? sl<FirebaseService>().firestore,
        _subscriptionRepository =
            subscriptionRepository ?? sl<SubscriptionRepository>();

  bool _isSubExpired(StoreSubscription sub) =>
      sub.isExpiredAt(TimeService.now());

  Future<AuthSessionResult?> tryAutoLogin() async {
    final savedUserId = _localStorage.userId;
    final savedStoreId = _localStorage.storeId;
    final savedUserRole = _localStorage.userRole;

    if (savedUserId != null && savedStoreId != null) {
      if (savedUserRole == UserRole.owner) {
        // ENUM refactor
        final firebaseUser = _authRepository.getCurrentUser();
        if (firebaseUser != null) {
          return await _finalizeOwnerLogin(firebaseUser.uid);
        }
      } else if (savedUserRole == UserRole.employee) {
        // ENUM refactor
        final user = await _userRepository.getUserById(savedUserId);
        final store = await _storeRepository.getStoreById(savedStoreId);

        if (user != null && store != null) {
          bool isExpired = store.subscription.isExpiredAt(TimeService.now());
          if (!isExpired) {
            await _ensureEmployeePermissions(user);
            await _userRepository.updateLastLogin(user.userId);
          }
          return AuthSessionResult(
              user: user, store: store, isExpired: isExpired);
        }
      }
    }

    final firebaseUser = _authRepository.getCurrentUser();
    if (firebaseUser != null) {
      return await _finalizeOwnerLogin(firebaseUser.uid);
    }

    return null;
  }

  Future<AuthSessionResult> _finalizeOwnerLogin(String uid) async {
    final userModel = await _userRepository.getUserByFirebaseUid(uid);
    if (userModel == null || !userModel.isOwner) {
      throw AuthException('auth_error_user_not_found');
    }

    final store = await _storeRepository.getStoreById(userModel.storeId);
    if (store == null) {
      throw AuthException('auth_error_store_not_found');
    }

    if (!store.isActive) throw StoreInactiveException();

    final isExpired = _isSubExpired(store.subscription);
    if (!isExpired) {
      await _userRepository.updateLastLogin(userModel.userId);
      AnalyticsService.setUserId(userModel.userId);
      AnalyticsService.setUserProperty(
          name: 'role', value: userModel.role.name); // ENUM refactor
      AnalyticsService.logLogin('email_password');

      await _localStorage.saveSession(
        userId: userModel.userId,
        storeId: store.storeId,
        userRole: userModel.role, // ENUM refactor
        userName: userModel.fullName,
        storeName: store.storeName,
      );
    }

    return AuthSessionResult(
        user: userModel, store: store, isExpired: isExpired);
  }

  Future<AuthSessionResult> loginOwnerWithEmail(
      String email, String password) async {
    try {
      final userCredential =
          await _authRepository.signInWithEmail(email, password);
      final user = userCredential.user!;
      return await _finalizeOwnerLogin(user.uid);
    } catch (e, stack) {
      AppErrorHandler.logSilentError(e.toString(), 'DatabaseSyncService.loginOwnerWithEmail', stackTrace: stack);
      await _authRepository.signOut();
      rethrow;
    }
  }

  Future<AuthSessionResult?> loginWithGoogleOrNull() async {
    final userCredential = await _authRepository.signInWithGoogle();
    if (userCredential?.user == null) return null;

    final googleUser = userCredential!.user!;
    final user = await _userRepository.getUserByFirebaseUid(googleUser.uid);

    if (user == null || !user.isOwner) return null;

    final store = await _storeRepository.getStoreById(user.storeId);
    if (store == null) {
      await _authRepository.signOut();
      return null;
    }
    if (!store.isActive) throw StoreInactiveException();

    final isExpired = _isSubExpired(store.subscription);
    if (!isExpired) {
      await _userRepository.updateLastLogin(user.userId);
      AnalyticsService.setUserId(user.userId);
      AnalyticsService.setUserProperty(
          name: 'role', value: user.role.name); // ENUM refactor
      AnalyticsService.logLogin('google');

      await _localStorage.saveSession(
        userId: user.userId,
        storeId: store.storeId,
        userRole: user.role, // ENUM refactor
        userName: user.fullName,
        storeName: store.storeName,
      );
    }

    return AuthSessionResult(user: user, store: store, isExpired: isExpired);
  }

  Future<AuthSessionResult> loginAsEmployee(
      UserModel employee, StoreModel store) async {
    if (!store.isActive) throw StoreInactiveException();

    bool identityAuthSuccess = false;
    if (employee.firebaseUid != null && employee.firebaseUid!.isNotEmpty) {
      final uid = await IdentityService.authenticateEmployee(
        phone: employee.phone ?? '',
        storeId: store.storeId,
        pin: employee.pin ?? '',
      );

      if (uid != null) {
        identityAuthSuccess = true;
      } else {
        throw AuthException('auth_error_invalid_credentials');
      }
    }

    if (!identityAuthSuccess &&
        (employee.firebaseUid == null || employee.firebaseUid!.isEmpty)) {
      try {
        final newUid = await _lazyProvision(employee);
        await _userRepository
            .updateUser(employee.userId, {'firebaseUid': newUid});
        employee = employee.copyWith(firebaseUid: newUid);
      } catch (e, stack) {
        AppErrorHandler.logSilentError(e.toString(), 'DatabaseSyncService.loginAsEmployee', stackTrace: stack);
        await _authRepository.signOut();
        rethrow;
      }
    }

    final isExpired = _isSubExpired(store.subscription);
    if (!isExpired) {
      await _userRepository.updateLastLogin(employee.userId);
      AnalyticsService.setUserId(employee.userId);
      AnalyticsService.setUserProperty(
          name: 'role', value: UserRole.employee.name); // ENUM refactor
      AnalyticsService.logLogin('pin_code');

      await _localStorage.saveSession(
        userId: employee.userId,
        storeId: store.storeId,
        userRole: UserRole.employee, // ENUM refactor
        userName: employee.fullName,
        storeName: store.storeName,
      );
    }

    return AuthSessionResult(
        user: employee, store: store, isExpired: isExpired);
  }

  Future<AuthSessionResult> finalizeEmployeeSession(UserModel employee) async {
    final firebaseUser = _authRepository.getCurrentUser();
    if (firebaseUser == null) {
      throw AuthException(
          "No authenticated Google user found. Please sign in first.");
    }

    await _ensureEmployeePermissions(employee);

    final updatedEmployee = await _userRepository.getUserById(employee.userId);
    if (updatedEmployee == null) {
      throw ServerException(
          'Could not re-fetch employee details after permission check.');
    }

    final store = await _storeRepository.getStoreById(updatedEmployee.storeId);
    if (store == null) {
      throw ServerException(
          'The store associated with this employee could not be found.');
    }

    if (!store.isActive) throw StoreInactiveException();

    final isExpired = _isSubExpired(store.subscription);
    if (!isExpired) {
      await _localStorage.saveSession(
        userId: updatedEmployee.userId,
        storeId: store.storeId,
        userRole: updatedEmployee.role, // ENUM refactor
        userName: updatedEmployee.fullName,
        storeName: store.storeName,
      );
      await _userRepository.updateLastLogin(updatedEmployee.userId);
    }

    return AuthSessionResult(
        user: updatedEmployee, store: store, isExpired: isExpired);
  }

  Future<AuthSessionResult> registerStoreWithGoogle({
    required String storeName,
    required String storePassword,
  }) async {
    final googleUser = _authRepository.getCurrentUser();
    if (googleUser == null) {
      throw AuthException('يجب تسجيل الدخول أولاً.');
    }

    final deviceId = await _deviceRepository.getDeviceId();
    var isEligibleForTrial =
        await _deviceRepository.checkDeviceEligibility(deviceId);

    if (isEligibleForTrial) {
      final hasConsumed =
          await _subscriptionRepository.hasDeviceConsumedTrial();
      if (hasConsumed) {
        isEligibleForTrial = false;
      }
    }

    final existingStore =
        await _storeRepository.getStoreByOwnerId(googleUser.uid);
    if (existingStore != null) {
      throw AuthException('هذا الحساب يمتلك متجرًا بالفعل.');
    }

    final result = await _createStoreAndUser(
      uid: googleUser.uid,
      email: googleUser.email!,
      name: googleUser.displayName ?? 'مالك جديد',
      photoUrl: googleUser.photoURL,
      storeName: storeName,
      storePassword: storePassword,
      isEligibleForTrial: isEligibleForTrial,
    );

    AnalyticsService.logSignUp('google');

    try {
      await _deviceRepository.registerDeviceUsage(
          deviceId, result.store.storeId);
      await _subscriptionRepository.verifyDevice(result.store.storeId);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'cache_write',
          stackTrace: stack);
    }

    return result;
  }

  Future<AuthSessionResult> registerStoreWithEmail({
    required String ownerName,
    required String email,
    required String password,
    required String storeName,
    required String storePassword,
  }) async {
    final deviceId = await _deviceRepository.getDeviceId();
    var isEligibleForTrial =
        await _deviceRepository.checkDeviceEligibility(deviceId);

    if (isEligibleForTrial) {
      final hasConsumed =
          await _subscriptionRepository.hasDeviceConsumedTrial();
      if (hasConsumed) {
        isEligibleForTrial = false;
      }
    }

    UserCredential userCredential =
        await _authRepository.createUserWithEmail(email, password);
    final user = userCredential.user!;

    await user.updateDisplayName(ownerName);

    final result = await _createStoreAndUser(
      uid: user.uid,
      email: email,
      name: ownerName,
      photoUrl: null,
      storeName: storeName,
      storePassword: storePassword,
      isEligibleForTrial: isEligibleForTrial,
    );

    AnalyticsService.logSignUp('email');

    try {
      await _deviceRepository.registerDeviceUsage(
          deviceId, result.store.storeId);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'device_registration',
          stackTrace: stack);
    }

    return result;
  }

  Future<AuthSessionResult> _createStoreAndUser({
    required String uid,
    required String email,
    required String name,
    required String? photoUrl,
    required String storeName,
    required String storePassword,
    bool isEligibleForTrial = true,
  }) async {
    final storeId = uid;
    final userId = uid;

    final placeholderSubscription = StoreSubscription(
      planId: SubscriptionPlan.trial, // ENUM refactor
      status: SubscriptionStatus.active,
      endDate: DateTime.now().add(const Duration(days: 14)),
      trialConsumed: false,
      maxWallets: 999,
      maxEmployees: 999,
      smsEnabled: true,
    );

    final newStore = StoreModel(
      storeId: storeId,
      storeName: storeName,
      storePassword: PasswordHasher.hashPassword(storePassword),
      ownerId: userId,
      ownerName: name,
      ownerEmail: email,
      ownerPhoto: photoUrl,
      createdAt: DateTime.now(),
      subscription: placeholderSubscription,
      settings: StoreSettings(),
      stats: StoreStats(
        totalWallets: 0,
        activeWallets: 0,
        totalTransactionsToday: 0,
        totalCommissionToday: 0.0,
        lastUpdated: DateTime.now(),
      ),
    );

    final newOwner = UserModel(
      userId: userId,
      storeId: storeId,
      role: UserRole.owner, // ENUM refactor
      fullName: name,
      email: email,
      firebaseUid: uid,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );

    // Phase 4: Atomic Batch Creation
    final batch = _firestore.batch();
    await _storeRepository.createStore(newStore,
        isEligibleForTrial: isEligibleForTrial, batch: batch);
    await _userRepository.createUser(newOwner, batch: batch);
    await batch.commit();

    final freshStore = await _storeRepository.getStoreById(storeId);
    final resolvedStore = freshStore ?? newStore;

    await _localStorage.saveSession(
      userId: userId,
      storeId: storeId,
      userRole: UserRole.owner, // ENUM refactor
      userName: newOwner.fullName,
      storeName: resolvedStore.storeName,
    );

    return AuthSessionResult(user: newOwner, store: resolvedStore);
  }

  Future<void> _ensureEmployeePermissions(UserModel employee) async {
    if (employee.isEmployee) {
      if (employee.email == null || employee.email!.isEmpty) {
        if (employee.permissions == null) {
          await _userRepository.updateUser(employee.userId, {
            'permissions': UserPermissions.defaultPermissions().toMap(),
          });
        }
      }
    }
  }

  Future<String> _lazyProvision(UserModel employee) async {
    final phone = employee.phone ?? '';
    final storeId = employee.storeId;
    final pin = employee.pin ?? '';

    try {
      final uid = await IdentityService.provisionIdentity(
          phone: phone, storeId: storeId, pin: pin);
      if (uid != null) return uid;
      throw Exception('Initial provisioning returned null');
    } catch (e, stack) {
      AppErrorHandler.logSilentError(e.toString(), 'DatabaseSyncService._lazyProvision_initial', stackTrace: stack);
      await Future.delayed(const Duration(seconds: 1));
      try {
        final uid = await IdentityService.provisionIdentity(
            phone: phone, storeId: storeId, pin: pin);
        if (uid != null) return uid;
        throw Exception('Retry provisioning returned null');
      } catch (retryError, retryStack) {
        AppErrorHandler.logSilentError(retryError.toString(), 'DatabaseSyncService._lazyProvision_retry', stackTrace: retryStack);
        throw Exception('Failed to provision employee identity.');
      }
    }
  }
}
