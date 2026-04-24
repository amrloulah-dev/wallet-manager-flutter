import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import '../core/utils/password_hasher.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/store_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/license_key_repository.dart';
import '../data/repositories/subscription_repository.dart';
import '../data/models/store_model.dart';
import '../data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import '../data/services/local_storage_service.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../core/services/identity_service.dart';
import '../core/errors/app_exceptions.dart';
import '../core/services/analytics_service.dart';
import '../services/time_service.dart';
import 'base_provider.dart';

enum AuthStatus {
  idle,
  loading,
  authenticated,
  unauthenticated,
  error,
  expired
}

class AuthProvider extends BaseProvider {
  // Repositories
  final AuthRepository _authRepository;
  final StoreRepository _storeRepository;
  final UserRepository _userRepository;
  final DeviceRepository _deviceRepository;
  final LicenseKeyRepository _licenseKeyRepository;
  final LocalStorageService _localStorage;

  // State
  User? _firebaseUser;
  UserModel? _currentUser;
  StoreModel? _currentStore;

  // Status
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  // Constructor
  AuthProvider({
    AuthRepository? authRepository,
    StoreRepository? storeRepository,
    UserRepository? userRepository,
    DeviceRepository? deviceRepository,
    LicenseKeyRepository? licenseKeyRepository,
    LocalStorageService? localStorage,
  })  : _authRepository = authRepository ?? sl<AuthRepository>(),
        _storeRepository = storeRepository ?? sl<StoreRepository>(),
        _userRepository = userRepository ?? sl<UserRepository>(),
        _deviceRepository = deviceRepository ?? sl<DeviceRepository>(),
        _licenseKeyRepository =
            licenseKeyRepository ?? sl<LicenseKeyRepository>(),
        _localStorage = localStorage ?? sl<LocalStorageService>() {
    Future.microtask(() => tryAutoLogin());
  }

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get currentUser => _currentUser;
  StoreModel? get currentStore => _currentStore;

  // Robust getter for currentUserId - Primary source is FirebaseAuth, then internal state, then LocalStorage
  String? get currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ??
        _currentUser?.userId ??
        _localStorage.userId;
  }

  /// Returns null if no user is signed in or fetch failed.
  /// Ensures the UserModel is loaded.
  /// If in memory -> returns it.
  /// If missing but Auth exists -> Fetches from Firestore with Retry.
  Future<UserModel?> ensureUserLoaded() async {
    debugPrint('🚀 [AUTH START] ensureUserLoaded() initiated');
    // 1. Memory Check (Zero Cost)
    if (_currentUser != null) {
      debugPrint('✅ [AUTH SUCCESS] ensureUserLoaded: User already in memory.');
      return _currentUser;
    }

    // 2. Auth Session Check (Firebase - Owner)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      debugPrint('⏳ [AUTH DATA] ensureUserLoaded: Firebase user found, fetching from repository...');
      _firebaseUser = firebaseUser;
      final user = await _fetchWithRetry(firebaseUser.uid);
      if (user != null) {
        debugPrint('✅ [AUTH SUCCESS] ensureUserLoaded: Fetched owner profile.');
      } else {
        debugPrint('⚠️ [AUTH ERROR] ensureUserLoaded: Failed to fetch owner profile.');
      }
      return user;
    }

    // 3. LocalStorage Check (Employee - Virtual)
    final savedUserId = _localStorage.userId;
    if (savedUserId != null) {
      debugPrint('⏳ [AUTH DATA] ensureUserLoaded: LocalStorage userId found, fetching from repository...');
      final user = await _fetchWithRetry(savedUserId);
      if (user != null) {
        debugPrint('✅ [AUTH SUCCESS] ensureUserLoaded: Fetched employee profile.');
      } else {
        debugPrint('⚠️ [AUTH ERROR] ensureUserLoaded: Failed to fetch employee profile.');
      }
      return user;
    }

    debugPrint('⚠️ [AUTH ABORT] ensureUserLoaded: No session found.');
    return null;
  }

  Future<UserModel?> _fetchWithRetry(String uid) async {
    try {
      // Attempt 1
      UserModel? user = await _fetchUserFromRepo(uid);
      if (user != null) {
        _updateLocalState(user);
        return user;
      }

      // Wait 1 second
      await Future.delayed(const Duration(seconds: 1));

      // Attempt 2
      user = await _fetchUserFromRepo(uid);
      if (user != null) {
        _updateLocalState(user);
        return user;
      }
    } catch (e, stack) {
      AppErrorHandler.handle(e, severity: ErrorSeverity.medium, operation: 'auto_login', stackTrace: stack);
      // Silent error handling - user will be prompted to login if needed
    } finally {
      if (_status == AuthStatus.loading) {
        _setStatus(AuthStatus.idle); // Without overriding actual loaded state if we use idle
      }
      safeNotify();
    }
    return null;
  }

  Future<UserModel?> _fetchUserFromRepo(String uid) async {
    return await _userRepository.getUserByFirebaseUid(uid);
  }

  void _updateLocalState(UserModel user) {
    _currentUser = user;
    if (_currentStore == null) {
      _storeRepository.getStoreById(user.storeId).then((store) {
        _currentStore = store;
        safeNotify();
      });
    }
    // Note: notifyListeners() batching assumes safeNotify() will be called at the end of the public method
  }

  // License Getters
  String get licenseKey => _currentStore?.subscription.planId ?? 'N/A';
  DateTime get licenseExpiryDate =>
      _currentStore?.subscription.endDate ?? DateTime.now();

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// T058: Single time-resolution entry point for expiry checks in AuthProvider.
  /// Keeps StoreSubscription a pure POJO — never call sub.isExpiredAt() directly outside here.
  bool _isSubExpired(StoreSubscription sub) => sub.isExpiredAt(TimeService.now());

  // Helper Getters
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isSubscriptionExpired =>
      _status == AuthStatus.expired ||
      (_currentStore != null && _isSubExpired(_currentStore!.subscription));
  bool get isLoading => _status == AuthStatus.loading;
  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get isEmployee => _currentUser?.isEmployee ?? false;

  String? get currentStoreId => _currentStore?.storeId;

  // Trial Status
  bool get isTrial => _currentStore?.subscription.planId == 'trial';
  int? get trialDaysRemaining {
    if (!isTrial || _currentStore?.subscription.endDate == null) return null;
    final expiry = _currentStore!.subscription.endDate!;
    // T058: Use NTP-resolved server time for trial countdown
    final remaining = expiry.difference(TimeService.now());
    return remaining.inDays >= 0 ? remaining.inDays + 1 : 0;
  }

  // ===== Methods =====

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email) async {
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setError('auth_error_invalid_email');
      return;
    }

    _setStatus(AuthStatus.loading);
    try {
      await _authRepository.sendPasswordResetEmail(email);
      _setStatus(AuthStatus.idle);
      _errorMessage = null; // Clear any previous error
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          setError('auth_error_account_not_found', e);
        case 'invalid-email':
          setError('auth_error_invalid_email', e);
        case 'too-many-requests':
          setError('auth_error_too_many_requests', e);
        default:
          setError(e.message ?? 'auth_operation_failed', e);
      }
    } catch (e, stack) {
      setError('auth_operation_failed', e, stack);
    }
  }

  /// Validate saved session on app startup
  Future<void> tryAutoLogin() async {
    debugPrint('🚀 [AUTH START] tryAutoLogin() initiated');
    _setStatus(AuthStatus.loading);
    AnalyticsService.logAppOpen();
    try {
      // 1. Read saved session data
      final savedUserId = _localStorage.userId;
      final savedStoreId = _localStorage.storeId;
      final savedUserRole = _localStorage.userRole;

      // 2. Validate Session
      if (savedUserId != null &&
          savedStoreId != null &&
          savedUserRole != null) {
        debugPrint('⏳ [AUTH DATA] tryAutoLogin: Found saved session ($savedUserRole)');
        // --- Owner Flow ---
        if (savedUserRole == 'owner') {
          final firebaseUser = _authRepository.getCurrentUser();
          if (firebaseUser != null) {
            _firebaseUser = firebaseUser;
            // Reload owner data from Firestore
            final success = await _finalizeOwnerLogin(firebaseUser.uid);
            if (success) {
              debugPrint('✅ [AUTH SUCCESS] tryAutoLogin: Owner session restored.');
              _setStatus(AuthStatus.authenticated);
              return;
            }
          }
        }
        // --- Employee Flow ---
        else if (savedUserRole == 'employee') {
          // Employees might not have a direct Firebase Auth user (PIN based)
          // Verify against Firestore directly
          final user = await _userRepository.getUserById(savedUserId);
          final store = await _storeRepository.getStoreById(savedStoreId);

          if (user != null && store != null) {
            debugPrint('✅ [AUTH SUCCESS] tryAutoLogin: Employee session restored.');
            // Basic Validation
            _currentUser = user;
            _currentStore = store;

            if (store.subscription.isExpiredAt(TimeService.now())) {
              debugPrint('⚠️ [AUTH EXPIRED] tryAutoLogin: Subscription expired.');
              _setStatus(AuthStatus.expired);
              return;
            }

            // Ensure permissions are up to date
            await _ensureEmployeePermissions(user);

            // Update last login
            await _userRepository.updateLastLogin(user.userId);

            _setStatus(AuthStatus.authenticated);

            // ── Streams-Driven Sync (Phase 1) ──
            // Manual AppEvents listener removed. Data sync is now handled by stream listeners
            // established in respective providers.

            return;
          }
        }
      }

      // 3. Fallback: Firebase User exists but no local session (Owner Recovery)
      final firebaseUser = _authRepository.getCurrentUser();
      if (firebaseUser != null) {
        debugPrint('⏳ [AUTH DATA] tryAutoLogin: Firebase user found, attempting owner recovery...');
        _firebaseUser = firebaseUser;
        // Try to recover owner session
        final recovered = await _finalizeOwnerLogin(firebaseUser.uid);
        if (recovered) {
          debugPrint('✅ [AUTH SUCCESS] tryAutoLogin: Owner recovered via Firebase.');
          _setStatus(AuthStatus.authenticated);
          return;
        }
      }

      debugPrint('⚠️ [AUTH ABORT] tryAutoLogin: No valid session found.');
      // If all attempts fail
      _setStatus(AuthStatus.unauthenticated);
    } catch (e, stack) {
      debugPrint('❌ [AUTH FATAL] tryAutoLogin Error: $e');
      debugPrint('🔍 [STACK TRACE]: $stack');
      AppErrorHandler.handle(e, severity: ErrorSeverity.medium, operation: 'check_auth_status', stackTrace: stack);
      await logout();
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<void> _ensureEmployeePermissions(UserModel employee) async {
    if (employee.isEmployee) {
      if (employee.email == null || employee.email!.isEmpty) {
        // Only update if permissions are not already set, to avoid unnecessary writes.
        // Note: A more robust check might be needed if permissions can be an empty object vs. null.
        if (employee.permissions == null) {
          await _userRepository.updateUser(employee.userId, {
            'permissions': UserPermissions.defaultPermissions().toMap(),
          });
        }
      }
    }
  }

  Future<String?> registerStoreWithGoogle({
    required String storeName,
    required String storePassword,
  }) async {
    _setStatus(AuthStatus.loading);
    try {
      final googleUser = _authRepository.getCurrentUser();
      if (googleUser == null) {
        throw AuthException('يجب تسجيل الدخول أولاً.');
      }
      _firebaseUser = googleUser;

      // 1. Check Device Eligibility (H002: no longer throws, passes flag instead)
      final deviceId = await _deviceRepository.getDeviceId();
      var isEligibleForTrial =
          await _deviceRepository.checkDeviceEligibility(deviceId);

      // Anti-Fraud: Read-before-Write cross-validation via SubscriptionRepository
      if (isEligibleForTrial) {
        final hasConsumed = await SubscriptionRepository().hasDeviceConsumedTrial();
        if (hasConsumed) {
          isEligibleForTrial = false;
        }
      }

      final existingStore =
          await _storeRepository.getStoreByOwnerId(googleUser.uid);
      if (existingStore != null) {
        throw AuthException('هذا الحساب يمتلك متجرًا بالفعل.');
      }

      final storeId = await _createStoreAndUser(
        uid: googleUser.uid,
        email: googleUser.email!,
        name: googleUser.displayName ?? 'مالك جديد',
        photoUrl: googleUser.photoURL,
        storeName: storeName,
        storePassword: storePassword,
        isEligibleForTrial: isEligibleForTrial,
      );

      AnalyticsService.logSignUp('google');

      // 2. Register Device Usage (Best effort)
      try {
        await _deviceRepository.registerDeviceUsage(deviceId, storeId);
        // T050: Explicitly record device hardware identifier
        await SubscriptionRepository().verifyDevice(storeId);
      } catch (e, stack) {
        AppErrorHandler.handle(e, severity: ErrorSeverity.low, operation: 'cache_write', stackTrace: stack);
        // Log error but don't fail the whole registration as store is already created
      }

      return storeId;
    } catch (e) {
      // Clean up local state on error
      await logout();

      // Propagate specific exceptions to UI
      if (e is StoreInactiveException) {
        rethrow;
      }

      // For others, wrap or generic
      throw e is AppException ? e : ServerException('حدث خطأ غير متوقع: $e');
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
      // 1. Check Device Eligibility (H002: no longer throws, passes flag instead)
      final deviceId = await _deviceRepository.getDeviceId();
      var isEligibleForTrial =
          await _deviceRepository.checkDeviceEligibility(deviceId);

      // Anti-Fraud: Read-before-Write cross-validation via SubscriptionRepository
      if (isEligibleForTrial) {
        final hasConsumed = await SubscriptionRepository().hasDeviceConsumedTrial();
        if (hasConsumed) {
          isEligibleForTrial = false;
        }
      }

      UserCredential userCredential;
      try {
        userCredential =
            await _authRepository.createUserWithEmail(email, password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw EmailAlreadyInUseException();
        } else if (e.code == 'weak-password') {
          throw WeakPasswordException();
        }
        rethrow;
      }
      final user = userCredential.user!;
      _firebaseUser = user;

      // Ensure display name is set
      await user.updateDisplayName(ownerName);

      final storeId = await _createStoreAndUser(
        uid: user.uid,
        email: email,
        name: ownerName,
        photoUrl: null,
        storeName: storeName,
        storePassword: storePassword,
        isEligibleForTrial: isEligibleForTrial,
      );

      AnalyticsService.logSignUp('email');

      // 2. Register Device Usage
      try {
        await _deviceRepository.registerDeviceUsage(deviceId, storeId);
      } catch (e, stack) {
        AppErrorHandler.handle(e, severity: ErrorSeverity.low, operation: 'device_registration', stackTrace: stack);
      }

      return storeId;
    } catch (e) {
      await logout();

      // Propagate specific exceptions to UI
      if (e is EmailAlreadyInUseException ||
          e is WeakPasswordException) {
        rethrow;
      }

      throw e is AppException ? e : ServerException('حدث خطأ غير متوقع: $e');
    }
  }

  Future<String> _createStoreAndUser({
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

    // NOTE: License details here are DUMMY PLACEHOLDERS.
    // The StoreRepository.createStore method will overwrite these with
    // the canonical Trial or Free tier based on isEligibleForTrial.
    final placeholderSubscription = StoreSubscription(
      planId: "trial",
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
      createdAt: Timestamp.now(),
      subscription: placeholderSubscription,
      settings: StoreSettings(),
      stats: StoreStats(
        totalWallets: 0,
        activeWallets: 0,
        totalTransactionsToday: 0,
        totalCommissionToday: 0.0,
        lastUpdated: Timestamp.now(),
      ),
    );

    final newOwner = UserModel(
      userId: userId,
      storeId: storeId,
      role: 'owner',
      fullName: name,
      email: email,
      firebaseUid: uid,
      createdAt: Timestamp.now(),
      lastLogin: Timestamp.now(),
    );

    await _storeRepository.createStore(newStore, isEligibleForTrial: isEligibleForTrial);
    await _userRepository.createUser(newOwner);

    // 2. Direct Fetch (Bypass internal provider state checks)
    final freshStore = await _storeRepository.getStoreById(storeId);

    _currentUser = newOwner;
    if (freshStore != null) {
      _currentStore = freshStore;
    } else {
      _currentStore = newStore; // Fallback
    }

    await _localStorage.saveSession(
      userId: userId,
      storeId: storeId,
      userRole: 'owner',
      userName: newOwner.fullName,
      storeName: newStore.storeName,
    );

    _setStatus(AuthStatus.authenticated);

    return storeId;
  }

  Future<bool> loginOwnerWithEmail(String email, String password) async {
    _setStatus(AuthStatus.loading);
    try {
      final userCredential =
          await _authRepository.signInWithEmail(email, password);
      final user = userCredential.user!;
      _firebaseUser = user;

      return await _finalizeOwnerLogin(user.uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        throw UserNotFoundException();
      } else if (e.code == 'wrong-password') {
        throw WrongPasswordException();
      }
      throw AuthException('فشل تسجيل الدخول: ${e.message}');
    } catch (e, stack) {
      setError('auth_error_login_failed');
      AppErrorHandler.handle(e, severity: ErrorSeverity.critical, operation: 'owner_login', stackTrace: stack);
      await _authRepository.signOut();
      rethrow;
    }
  }

  Future<bool> _finalizeOwnerLogin(String uid) async {
    final userModel = await _userRepository.getUserByFirebaseUid(uid);
    if (userModel == null || !userModel.isOwner) {
      throw AuthException('auth_error_user_not_found');
    }

    final store = await _storeRepository.getStoreById(userModel.storeId);
    if (store == null) {
      throw AuthException('auth_error_store_not_found');
    }

    if (!store.isActive) throw StoreInactiveException();

    _currentUser = userModel;
    _currentStore = store;

    if (_isSubExpired(store.subscription)) {
      _setStatus(AuthStatus.expired);
      return true; // Login successful but expired
    }

    await _userRepository.updateLastLogin(userModel.userId);
    AnalyticsService.setUserId(userModel.userId);
    AnalyticsService.setUserProperty(name: 'role', value: userModel.role);
    AnalyticsService.logLogin('email_password');

    await _localStorage.saveSession(
      userId: userModel.userId,
      storeId: store.storeId,
      userRole: userModel.role,
      userName: userModel.fullName,
      storeName: store.storeName,
    );

    _setStatus(AuthStatus.authenticated);
    return true;
  }

  Future<bool> loginAsEmployee(UserModel employee, StoreModel store) async {
    _setStatus(AuthStatus.loading);
    try {
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
          AppErrorHandler.handle(
            Exception('Employee authentication failed in identity service'),
            severity: ErrorSeverity.critical,
            operation: 'AuthProvider.loginAsEmployee',
          );
          setError('auth_error_invalid_credentials');
          return false;
        }
      }

      if (!identityAuthSuccess &&
          (employee.firebaseUid == null || employee.firebaseUid!.isEmpty)) {
        // Secure the Login Flow (Feature 004): Await provisioning
        try {
          final newUid = await _lazyProvision(employee);
          await _userRepository
              .updateUser(employee.userId, {'firebaseUid': newUid});
          // Update the local object so subsequent logic has the UID
          employee = employee.copyWith(firebaseUid: newUid);
        } catch (e) {
          // Cleanup incomplete session
          await FirebaseAuth.instance.signOut();
          rethrow; // Re-throw for UI/Catch block to handle
        }
      }

      _currentUser = employee;
      _currentStore = store;

      if (_isSubExpired(store.subscription)) {
        _setStatus(AuthStatus.expired);
        return true;
      }

      await _userRepository.updateLastLogin(employee.userId);
      AnalyticsService.setUserId(employee.userId);
      AnalyticsService.setUserProperty(name: 'role', value: 'employee');
      AnalyticsService.logLogin('pin_code');

      await _localStorage.saveSession(
        userId: employee.userId,
        storeId: store.storeId,
        userRole: 'employee', // Explicitly set role
        userName: employee.fullName,
        storeName: store.storeName,
      );

      _setStatus(AuthStatus.authenticated);
      return true;
    } catch (e, stack) {
      final msg = e is AppException ? e.message : 'auth_error_employee_login_failed';
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.critical,
        operation: 'AuthProvider.loginAsEmployee',
      );
      setError(msg);
      await logout();
      return false;
    } finally {
      // Ensure loading is false (Task 2)
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
      if (store == null) {
        throw AuthException('auth_error_store_not_found');
      }
      _setStatus(AuthStatus.idle); // Not authenticated yet, just found store
      return store;
    } catch (e) {
      setError(
          e is AppException ? e.message : 'auth_error_store_lookup_failed');
      return null;
    }
  }

  Future<bool> loginWithGoogleOrNull() async {
    _setStatus(AuthStatus.loading);
    try {
      final userCredential = await _authRepository.signInWithGoogle();
      if (userCredential?.user == null) {
        _setStatus(AuthStatus.unauthenticated);
        return false;
      }
      final googleUser = userCredential!.user!;
      _firebaseUser = googleUser;

      final user = await _userRepository.getUserByFirebaseUid(googleUser.uid);
      if (user == null || !user.isOwner) {
        // This case is for owner login. If no user found, it's not a valid owner login.
        // For employee login, a different flow is initiated from the UI.
        _setStatus(AuthStatus.unauthenticated);
        return false;
      }

      final store = await _storeRepository.getStoreById(user.storeId);
      if (store == null) {
        await _authRepository.signOut();
        _setStatus(AuthStatus.unauthenticated);
        return false;
      }

      // Store status check
      if (!store.isActive) {
        throw StoreInactiveException();
      }

      _currentUser = user;
      _currentStore = store;

      // License check
      if (_isSubExpired(store.subscription)) {
        _setStatus(AuthStatus.expired);
        return true;
      }

      await _userRepository.updateLastLogin(user.userId);
      AnalyticsService.setUserId(user.userId);
      AnalyticsService.setUserProperty(name: 'role', value: user.role);
      AnalyticsService.logLogin('google');

      await _localStorage.saveSession(
        userId: user.userId,
        storeId: store.storeId,
        userRole: user.role,
        userName: user.fullName,
        storeName: store.storeName,
      );

      _setStatus(AuthStatus.authenticated);
      return true;
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.medium,
          operation: 'google_login_or_null',
          stackTrace: stack);
      await _authRepository.signOut();
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<void> loginWithGoogle() async {
    final success = await loginWithGoogleOrNull();
    if (!success) {
      setError('لا يوجد حساب مرتبط بهذا البريد الإلكتروني.');
    }
  }

  Future<String?> verifyStorePassword(String password) async {
    _setStatus(AuthStatus.loading);
    try {
      final stores = await _storeRepository.getStoresByPassword(password);
      if (stores.isNotEmpty) {
        final store = stores.first;
        _setStatus(AuthStatus.idle);
        return store.storeId;
      } else {
        throw InvalidCredentialsException();
      }
    } catch (e) {
      setError(e is AppException ? e.message : 'كلمة سر المتجر غير صحيحة.');
      return null;
    }
  }

  Future<void> finalizeEmployeeSession({required UserModel employee}) async {
    _setLoading(true);
    try {
      if (_firebaseUser == null) {
        throw AuthException(
            "No authenticated Google user found. Please sign in first.");
      }

      // Conditionally assign permissions before finalizing the session
      await _ensureEmployeePermissions(employee);

      // Re-fetch the employee and store to ensure all data is up-to-date
      final updatedEmployee =
          await _userRepository.getUserById(employee.userId);
      if (updatedEmployee == null) {
        throw ServerException(
            'Could not re-fetch employee details after permission check.');
      }

      final store =
          await _storeRepository.getStoreById(updatedEmployee.storeId);
      if (store == null) {
        throw ServerException(
            'The store associated with this employee could not be found.');
      }

      // Store status check
      if (!store.isActive) {
        throw StoreInactiveException();
      }

      _currentUser = updatedEmployee;
      _currentStore = store;

      // License check
      if (_isSubExpired(store.subscription)) {
        _setStatus(AuthStatus.expired);
        return;
      }

      await _localStorage.saveSession(
        userId: updatedEmployee.userId,
        storeId: store.storeId,
        userRole: updatedEmployee.role,
        userName: updatedEmployee.fullName,
        storeName: store.storeName,
      );

      await _userRepository.updateLastLogin(updatedEmployee.userId);

      _setStatus(AuthStatus.authenticated);
    } catch (e) {
      setError(e is AppException
          ? e.message
          : 'Failed to finalize employee session.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> activateNewLicense(String newKey) async {
    _setLoading(true);
    try {
      if (_currentStore == null) {
        throw AuthException('لا يوجد متجر نشط');
      }

      // 1. Verify Key
      final keyData = await _licenseKeyRepository.verifyLicenseKey(newKey);
      if (keyData == null) {
        throw AuthException('المفتاح غير صحيح');
      }
      if (keyData.isUsed) {
        throw AuthException('المفتاح مستخدم من قبل');
      }

      // 2. Activate Key
      await _licenseKeyRepository.activateLicenseKey(
        keyId: keyData.keyId,
        storeId: _currentStore!.storeId,
      );

      // 3. Refresh Data (Fetch updated store profile with Premium status)
      await refreshUserData();

      AnalyticsService.logLicenseUpgraded(
          _currentStore?.subscription.planId ?? 'premium');

      _setLoading(false);
    } catch (e) {
      _setLoading(false); // Ensure loading is cleared on error
      setError(e is AppException ? e.message : 'فشل تفعيل المفتاح: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _authRepository.signOut();
      await _localStorage.clearSession();
      _clearState();
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      setError('حدث خطأ أثناء تسجيل الخروج');
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
      } catch (e) {
        setError('فشل تحديث البيانات.');
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
    await _userRepository.updateEmployeeStats(
      userId: userId,
      incrementTransactions: incrementTransactions,
      incrementCommission: incrementCommission,
      incrementDebts: incrementDebts,
    );
  }

  /// Refactor Provisioning Logic (Feature 004)
  /// Implements a single retry followed by a fail-fast block.
  Future<String> _lazyProvision(UserModel employee) async {
    final phone = employee.phone ?? '';
    final storeId = employee.storeId;
    final pin = employee.pin ?? '';

    try {
      // Attempt 1
      final uid = await IdentityService.provisionIdentity(
        phone: phone,
        storeId: storeId,
        pin: pin,
      );
      if (uid != null) return uid;
      throw Exception('Initial provisioning returned null');
    } catch (e) {
      // Smart Retry: wait 1 second
      await Future.delayed(const Duration(seconds: 1));

      try {
        // Attempt 2
        final uid = await IdentityService.provisionIdentity(
          phone: phone,
          storeId: storeId,
          pin: pin,
        );
        if (uid != null) return uid;
        throw Exception('Retry provisioning returned null');
      } catch (retryError) {
        // Fail-Fast: throw explicit exception to block login
        throw Exception(
            'Failed to provision employee identity. Please check your internet connection and try again.');
      }
    }
  }

  void _setStatus(AuthStatus status) {
  if (_status == status) return; // منع التحديثات المتكررة لنفس الحالة
  _status = status;
  
  // 🔴 الإجبار على التحديث 🔴
  // ده بيخلي فلاتر يحط تحديث الشاشة في الـ Event Loop القادم غصب عنه
  WidgetsBinding.instance.addPostFrameCallback((_) {
     safeNotify();
  });
}

  void _setLoading(bool loading) {
    _status = loading ? AuthStatus.loading : AuthStatus.idle;
    // safeNotify() removed for batching
  }

  @override
  void setError(String message, [Object? error, StackTrace? stack]) {
    debugPrint('💥 [AUTH ERROR] $message | Error: $error');
    if (stack != null) debugPrint('🔍 [STACK TRACE]: $stack');
    _errorMessage = message;
    _status = AuthStatus.error;
    super.setError(message, error, stack);
    safeNotify();
  }

  void _clearState() {
    _firebaseUser = null;
    _currentUser = null;
    _currentStore = null;
  }
}
