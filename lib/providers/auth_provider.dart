import 'package:flutter/foundation.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import '../domain/entities/auth_user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/store_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/license_key_repository.dart';
import '../data/services/local_storage_service.dart';
import '../data/models/store_model.dart';
import '../data/models/user_model.dart';
import '../core/errors/app_exceptions.dart';
import '../core/services/database_sync_service.dart';
import '../core/services/analytics_service.dart';
import '../services/time_service.dart';
import '../core/utils/password_hasher.dart';
import 'base_provider.dart';
import '../core/enums/subscription_enums.dart';

enum AuthStatus {
  idle,
  loading,
  authenticated,
  unauthenticated,
  error,
  expired
}

class AuthProvider extends BaseProvider {
  // Services
  final AuthRepository _authRepository;
  final DatabaseSyncService _databaseSyncService;

  final StoreRepository _storeRepository;
  final UserRepository _userRepository;
  final LicenseKeyRepository _licenseKeyRepository;
  final LocalStorageService _localStorage;

  // State
  AuthUser? _firebaseUser;
  UserModel? _currentUser;
  StoreModel? _currentStore;

  // Status
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  // Constructor
  AuthProvider({
    AuthRepository? authRepository,
    DatabaseSyncService? databaseSyncService,
    StoreRepository? storeRepository,
    UserRepository? userRepository,
    LicenseKeyRepository? licenseKeyRepository,
    LocalStorageService? localStorage,
  })  : _authRepository = authRepository ?? sl<AuthRepository>(),
        _databaseSyncService = databaseSyncService ?? sl<DatabaseSyncService>(),
        _storeRepository = storeRepository ?? sl<StoreRepository>(),
        _userRepository = userRepository ?? sl<UserRepository>(),
        _licenseKeyRepository =
            licenseKeyRepository ?? sl<LicenseKeyRepository>(),
        _localStorage = localStorage ?? sl<LocalStorageService>() {
    Future.microtask(() => tryAutoLogin());
  }

  // Getters
  AuthUser? get firebaseUser => _firebaseUser;
  UserModel? get currentUser => _currentUser;
  StoreModel? get currentStore => _currentStore;

  String? get currentUserId {
    return _authRepository.getCurrentUser()?.uid ??
        _currentUser?.userId ??
        _localStorage.userId;
  }

  Future<UserModel?> ensureUserLoaded() async {
    if (_currentUser != null) {
      return _currentUser;
    }
    await tryAutoLogin();
    return _currentUser;
  }

  // License Getters
  String get licenseKey =>
      _currentStore?.subscription.planId.name ?? 'N/A'; // ENUM refactor
  DateTime get licenseExpiryDate =>
      _currentStore?.subscription.endDate ?? DateTime.now();

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;

  bool _isSubExpired(StoreSubscription sub) =>
      sub.isExpiredAt(TimeService.now());

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isSubscriptionExpired =>
      _status == AuthStatus.expired ||
      (_currentStore != null && _isSubExpired(_currentStore!.subscription));
  bool get isLoading => _status == AuthStatus.loading;
  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get isEmployee => _currentUser?.isEmployee ?? false;

  String? get currentStoreId => _currentStore?.storeId;

  bool get isTrial =>
      _currentStore?.subscription.planId ==
      SubscriptionPlan.trial; // ENUM refactor
  int? get trialDaysRemaining {
    if (!isTrial || _currentStore?.subscription.endDate == null) return null;
    final expiry = _currentStore!.subscription.endDate!;
    final remaining = expiry.difference(TimeService.now());
    return remaining.inDays >= 0 ? remaining.inDays + 1 : 0;
  }

  // ===== Methods =====

  Future<void> sendPasswordReset(String email) async {
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setError('auth_error_invalid_email');
      return;
    }
    _setStatus(AuthStatus.loading);
    try {
      await _authRepository.sendPasswordResetEmail(email);
      _setStatus(AuthStatus.idle);
      _errorMessage = null;
    } catch (e, stack) {
      if (e is UserNotFoundException) {
        setError('auth_error_account_not_found', e, stack);
      } else if (e is AuthException) {
        setError(e.message, e, stack);
      } else if (e is AppException) {
        setError(e.message, e, stack);
      } else {
        setError('auth_operation_failed', e, stack);
      }
    }
  }

  void _applySessionResult(AuthSessionResult? result) {
    if (result != null) {
      _currentUser = result.user;
      _currentStore = result.store;
      _firebaseUser = _authRepository.getCurrentUser();
      if (result.isExpired) {
        _setStatus(AuthStatus.expired);
      } else {
        _setStatus(AuthStatus.authenticated);
      }
    } else {
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<void> tryAutoLogin() async {
    _setStatus(AuthStatus.loading);
    AnalyticsService.logAppOpen();
    try {
      final result = await _databaseSyncService.tryAutoLogin();
      _applySessionResult(result);
    } catch (e, stack) {
      setError('auth_error_auto_login_failed', e, stack);
      await logout();
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<String?> registerStoreWithGoogle({
    required String storeName,
    required String storePassword,
  }) async {
    _setStatus(AuthStatus.loading);
    try {
      final result = await _databaseSyncService.registerStoreWithGoogle(
        storeName: storeName,
        storePassword: storePassword,
      );
      _applySessionResult(result);
      return result.store.storeId;
    } catch (e, stack) {
      setError('auth_error_registration_failed', e, stack);
      await logout();
      return null;
    } finally {
      if (_status == AuthStatus.loading) {
        _setStatus(AuthStatus.idle);
      }
    }
  }

  Future<String?> registerStoreWithEmail({
    required String ownerName,
    required String email,
    required String password,
    required String storeName,
    required String storePassword,
  }) async {
    _setStatus(AuthStatus.loading);
    try {
      final result = await _databaseSyncService.registerStoreWithEmail(
        ownerName: ownerName,
        email: email,
        password: password,
        storeName: storeName,
        storePassword: storePassword,
      );
      _applySessionResult(result);
      return result.store.storeId;
    } catch (e, stack) {
      setError('auth_error_registration_failed', e, stack);
      await logout();
      return null;
    } finally {
      if (_status == AuthStatus.loading) {
        _setStatus(AuthStatus.idle);
      }
    }
  }

  Future<bool> loginOwnerWithEmail(String email, String password) async {
    _setStatus(AuthStatus.loading);
    try {
      final result =
          await _databaseSyncService.loginOwnerWithEmail(email, password);
      _applySessionResult(result);
      return true;
    } catch (e, stack) {
      setError('auth_error_login_failed', e, stack);
      await logout();
      return false;
    } finally {
      if (_status == AuthStatus.loading) {
        _setStatus(AuthStatus.idle);
      }
    }
  }

  Future<bool> loginAsEmployee(UserModel employee, StoreModel store) async {
    _setStatus(AuthStatus.loading);
    try {
      final result =
          await _databaseSyncService.loginAsEmployee(employee, store);
      _applySessionResult(result);
      return true;
    } catch (e, stack) {
      setError(
          e is AppException ? e.message : 'auth_error_employee_login_failed',
          e,
          stack);
      await logout();
      return false;
    } finally {
      if (_status == AuthStatus.loading) {
        _setStatus(AuthStatus.idle);
      }
      safeNotify();
    }
  }

  Future<StoreModel?> findStoreByEmail(String email) async {
    _setStatus(AuthStatus.loading);
    try {
      final store = await _storeRepository.getStoreByEmail(email);
      if (store == null) throw AuthException('auth_error_store_not_found');
      return store;
    } catch (e, stack) {
      setError(
          e is AppException ? e.message : 'auth_error_store_lookup_failed',
          e,
          stack);
      return null;
    } finally {
      if (_status == AuthStatus.loading) {
        _setStatus(AuthStatus.idle);
      }
    }
  }

  Future<bool> loginWithGoogleOrNull() async {
    _setStatus(AuthStatus.loading);
    try {
      final result = await _databaseSyncService.loginWithGoogleOrNull();
      if (result == null) {
        setError('auth_error_account_not_found');
        return false;
      } else {
        _applySessionResult(result);
        return true;
      }
    } catch (e, stack) {
      setError('auth_error_google_login_failed', e, stack);
      await logout();
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<String?> verifyStorePassword(String email, String password) async {
    _setStatus(AuthStatus.loading);
    try {
      final store = await _storeRepository.getStoreByEmail(email);
      if (store != null) {
        final isValid = await PasswordHasher.verifyPassword(password, store.storePassword);
        if (isValid) {
          _setStatus(AuthStatus.idle);
          return store.storeId;
        }
      }
      throw InvalidCredentialsException();
    } catch (e, stack) {
      setError(
          e is AppException ? e.message : 'auth_error_invalid_store_password',
          e,
          stack);
      return null;
    }
  }

  Future<void> finalizeEmployeeSession({required UserModel employee}) async {
    _setStatus(AuthStatus.loading);
    try {
      final result =
          await _databaseSyncService.finalizeEmployeeSession(employee);
      _applySessionResult(result);
    } catch (e, stack) {
      setError(
          e is AppException
              ? e.message
              : 'Failed to finalize employee session.',
          e,
          stack);
      _setStatus(AuthStatus.idle);
    }
  }

  Future<void> activateNewLicense(String newKey) async {
    _setStatus(AuthStatus.loading);
    try {
      if (_currentStore == null) {
        throw AuthException('auth_error_store_not_active');
      }
      final keyData = await _licenseKeyRepository.verifyLicenseKey(newKey);
      if (keyData == null) throw AuthException('auth_error_invalid_key');
      if (keyData.isUsed) throw AuthException('auth_error_key_already_used');

      await _licenseKeyRepository.activateLicenseKey(
        keyId: keyData.keyId,
        storeId: _currentStore!.storeId,
      );

      await refreshUserData();
      AnalyticsService.logLicenseUpgraded(
          _currentStore?.subscription.planId.name ?? 'premium');
      _setStatus(AuthStatus.idle);
    } catch (e, stack) {
      _setStatus(AuthStatus.idle);
      setError(e is AppException ? e.message : 'auth_operation_failed', e,
          stack);
    }
  }

  Future<void> logout() async {
    try {
      await _authRepository.signOut();
      await _localStorage.clearSession();
      _clearState();
      _setStatus(AuthStatus.unauthenticated);
    } catch (e, stack) {
      setError('auth_error_logout_failed', e, stack);
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      safeNotify();
    }
  }

  Future<void> refreshUserData() async {
    if (_currentUser != null && _currentStore != null) {
      try {
        _currentUser = await _userRepository.getUserById(_currentUser!.userId);
        _currentStore =
            await _storeRepository.getStoreById(_currentStore!.storeId);
      } catch (e, stack) {
        setError('auth_error_update_failed', e, stack);
      } finally {
        safeNotify();
      }
    }
  }

  Future<void> updateEmployeeStats({
    required String userId,
    int? incrementTransactions,
    double? incrementCommission,
    int? incrementDebts,
  }) async {
    try {
      await _userRepository.updateEmployeeStats(
        userId: userId,
        incrementTransactions: incrementTransactions,
        incrementCommission: incrementCommission,
        incrementDebts: incrementDebts,
      );
    } catch (e, stack) {
      setError('auth_error_update_stats_failed', e, stack);
    }
  }

  void _setStatus(AuthStatus status) {
    if (_status == status) return;
    _status = status;
    // Reset error when starting a new operation
    if (status == AuthStatus.loading) {
      _errorMessage = null;
    }
    safeNotify();
  }

  @override
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'auth_operation']) {
    if (kDebugMode) {
      debugPrint('💥 [AUTH ERROR] $errorCode | Error: $error');
    }
    _errorMessage = errorCode;
    _status = AuthStatus.error;
    super.setError(errorCode, error, stack, showToast, operation);
    safeNotify();
  }

  void _clearState() {
    _firebaseUser = null;
    _currentUser = null;
    _currentStore = null;
  }
}
