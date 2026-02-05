import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/providers/app_events.dart';
import '../core/utils/password_hasher.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/store_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/license_key_repository.dart';
import '../data/models/store_model.dart';
import '../data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import '../data/services/local_storage_service.dart';
import '../core/errors/app_exceptions.dart';

enum AuthStatus {
  idle,
  loading,
  authenticated,
  unauthenticated,
  error,
  expired
}

class AuthProvider extends ChangeNotifier {
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
  })  : _authRepository = authRepository ?? AuthRepository(),
        _storeRepository = storeRepository ?? StoreRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _deviceRepository = deviceRepository ?? DeviceRepository(),
        _licenseKeyRepository = licenseKeyRepository ?? LicenseKeyRepository(),
        _localStorage = localStorage ?? LocalStorageService() {
    tryAutoLogin();
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
    // 1. Memory Check (Zero Cost)
    if (_currentUser != null) return _currentUser;

    // 2. Auth Session Check (Firebase - Owner)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _firebaseUser = firebaseUser;
      return await _fetchWithRetry(firebaseUser.uid);
    }

    // 3. LocalStorage Check (Employee - Virtual)
    final savedUserId = _localStorage.userId;
    if (savedUserId != null) {
      return await _fetchWithRetry(savedUserId);
    }

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
    } catch (e) {
      // Silent error handling - user will be prompted to login if needed
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
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // License Getters
  String get licenseKey => _currentStore?.license.licenseKey ?? 'N/A';
  Timestamp get licenseExpiryDate =>
      _currentStore?.license.expiryDate ?? Timestamp.now();

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;

  // Helper Getters
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isSubscriptionExpired => _status == AuthStatus.expired;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get isEmployee => _currentUser?.isEmployee ?? false;

  String? get currentStoreId => _currentStore?.storeId;

  // Trial Status
  bool get isTrial => _currentStore?.license.licenseType == 'trial';
  int? get trialDaysRemaining {
    if (!isTrial) return null;
    final remaining =
        _currentStore!.license.expiryDate.toDate().difference(DateTime.now());
    return remaining.inDays >= 0 ? remaining.inDays + 1 : 0;
  }

  // ===== Methods =====

  /// Validate saved session on app startup
  Future<void> tryAutoLogin() async {
    _setStatus(AuthStatus.loading);
    try {
      // 1. Read saved session data
      final savedUserId = _localStorage.userId;
      final savedStoreId = _localStorage.storeId;
      final savedUserRole = _localStorage.userRole;

      // 2. Validate Session
      if (savedUserId != null &&
          savedStoreId != null &&
          savedUserRole != null) {
        // --- Owner Flow ---
        if (savedUserRole == 'owner') {
          final firebaseUser = _authRepository.getCurrentUser();
          if (firebaseUser != null) {
            _firebaseUser = firebaseUser;
            // Reload owner data from Firestore
            final success = await _finalizeOwnerLogin(firebaseUser.uid);
            if (success) return;
          }
        }
        // --- Employee Flow ---
        else if (savedUserRole == 'employee') {
          // Employees might not have a direct Firebase Auth user (PIN based)
          // Verify against Firestore directly
          final user = await _userRepository.getUserById(savedUserId);
          final store = await _storeRepository.getStoreById(savedStoreId);

          if (user != null && store != null) {
            // Basic Validation
            _currentUser = user;
            _currentStore = store;

            if (store.license.isExpired) {
              _setStatus(AuthStatus.expired);
              return;
            }

            // Ensure permissions are up to date
            await _ensureEmployeePermissions(user);

            // Update last login
            await _userRepository.updateLastLogin(user.userId);

            _setStatus(AuthStatus.authenticated);

            // Fire events to load data
            appEvents.fireWalletsChanged();
            appEvents.fireTransactionsChanged();
            appEvents.fireDebtsChanged();
            return;
          }
        }
      }

      // 3. Fallback: Firebase User exists but no local session (Owner Recovery)
      final firebaseUser = _authRepository.getCurrentUser();
      if (firebaseUser != null) {
        _firebaseUser = firebaseUser;
        // Try to recover owner session
        final recovered = await _finalizeOwnerLogin(firebaseUser.uid);
        if (recovered) return;
      }

      // If all attempts fail
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
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

      // 1. Check Device Eligibility
      final deviceId = await _deviceRepository.getDeviceId();
      final isEligible =
          await _deviceRepository.checkDeviceEligibility(deviceId);
      if (!isEligible) {
        throw AuthException(
            'لقد تجاوزت الحد المسموح للفترات التجريبية على هذا الجهاز.');
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
      );

      // 2. Register Device Usage (Best effort)
      try {
        await _deviceRepository.registerDeviceUsage(deviceId, storeId);
      } catch (e) {
        // Log error but don't fail the whole registration as store is already created
      }

      return storeId;
    } catch (e) {
      _setError(e is AppException ? e.message : 'حدث خطأ غير متوقع: $e');
      await logout();
      return null;
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
      // 1. Check Device Eligibility BEFORE creating auth user if possible,
      // but usually we need to do it early.
      final deviceId = await _deviceRepository.getDeviceId();
      final isEligible =
          await _deviceRepository.checkDeviceEligibility(deviceId);
      if (!isEligible) {
        throw AuthException(
            'لقد تجاوزت الحد المسموح للفترات التجريبية على هذا الجهاز.');
      }

      final userCredential =
          await _authRepository.createUserWithEmail(email, password);
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
      );

      // 2. Register Device Usage
      try {
        await _deviceRepository.registerDeviceUsage(deviceId, storeId);
      } catch (e) {}

      return storeId;
    } catch (e) {
      _setError(e is AppException ? e.message : 'حدث خطأ غير متوقع: $e');
      // If registration fails halfway, we might want to cleanup the created user
      // but Firebase Auth handles mostly atomic creation.
      // However, if store creation fails, we are in a bad state.
      // For now, logging out cleans up local state.
      await logout();
      return null;
    }
  }

  Future<String> _createStoreAndUser({
    required String uid,
    required String email,
    required String name,
    required String? photoUrl,
    required String storeName,
    required String storePassword,
  }) async {
    final storeId = uid;
    final userId = uid;

    // NOTE: License details here are DUMMY PLACEHOLDERS.
    // The StoreRepository.createStore method will overwrite these with
    // the canonical Trial License.
    final placeholderLicense = StoreLicense(
      licenseKey: "PENDING",
      licenseType: "trial",
      status: "pending",
      startDate: Timestamp.now(),
      expiryDate: Timestamp.now(),
      lastCheck: Timestamp.now(),
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
      license: placeholderLicense,
      settings: StoreSettings(),
      stats: StoreStats(
        totalWallets: 0,
        activeWallets: 0,
        totalTransactionsToday: 0,
        totalCommissionToday: 0.0,
        lastUpdated: Timestamp.now(),
      ),
      activeLicenseKey: "PENDING",
      licenseKeyId: "PENDING",
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

    await _storeRepository.createStore(newStore);
    await _userRepository.createUser(newOwner);

    _currentUser = newOwner;
    _currentStore = newStore;

    await _localStorage.saveSession(
      userId: userId,
      storeId: storeId,
      userRole: 'owner',
      userName: newOwner.fullName,
      storeName: newStore.storeName,
    );

    _setStatus(AuthStatus.authenticated);
    appEvents.fireWalletsChanged();
    appEvents.fireTransactionsChanged();
    appEvents.fireDebtsChanged();

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
    } catch (e) {
      _setError(e is AppException ? e.message : 'فشل تسجيل الدخول.');
      await _authRepository.signOut();
      return false;
    }
  }

  Future<bool> _finalizeOwnerLogin(String uid) async {
    final userModel = await _userRepository.getUserByFirebaseUid(uid);
    if (userModel == null || !userModel.isOwner) {
      throw AuthException('المستخدم غير موجود أو ليس مالكًا.');
    }

    final store = await _storeRepository.getStoreById(userModel.storeId);
    if (store == null) {
      throw AuthException('المتجر غير موجود.');
    }

    if (!store.isActive) throw StoreInactiveException();

    _currentUser = userModel;
    _currentStore = store;

    if (store.license.isExpired) {
      _setStatus(AuthStatus.expired);
      return true; // Login successful but expired
    }

    await _userRepository.updateLastLogin(userModel.userId);
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

      _currentUser = employee;
      _currentStore = store;

      if (store.license.isExpired) {
        _setStatus(AuthStatus.expired);
        return true;
      }

      await _userRepository.updateLastLogin(employee.userId);
      await _localStorage.saveSession(
        userId: employee.userId,
        storeId: store.storeId,
        userRole: 'employee', // Explicitly set role
        userName: employee.fullName,
        storeName: store.storeName,
      );

      _setStatus(AuthStatus.authenticated);
      appEvents.fireWalletsChanged();
      appEvents.fireTransactionsChanged();
      appEvents.fireDebtsChanged();
      return true;
    } catch (e) {
      _setError(e is AppException ? e.message : 'فشل تسجيل دخول الموظف.');
      await logout();
      return false;
    }
  }

  Future<StoreModel?> findStoreByEmail(String email) async {
    _setStatus(AuthStatus.loading);
    try {
      final store = await _storeRepository.getStoreByEmail(email);
      if (store == null) {
        throw AuthException('لم يتم العثور على متجر بهذا البريد الإلكتروني.');
      }
      _setStatus(AuthStatus.idle); // Not authenticated yet, just found store
      return store;
    } catch (e) {
      _setError(
          e is AppException ? e.message : 'حدث خطأ أثناء البحث عن المتجر.');
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
      if (store.license.isExpired) {
        _setStatus(AuthStatus.expired);
        return true;
      }

      await _userRepository.updateLastLogin(user.userId);
      await _localStorage.saveSession(
        userId: user.userId,
        storeId: store.storeId,
        userRole: user.role,
        userName: user.fullName,
        storeName: store.storeName,
      );

      _setStatus(AuthStatus.authenticated);
      return true;
    } catch (e) {
      await _authRepository.signOut();
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<void> loginWithGoogle() async {
    final success = await loginWithGoogleOrNull();
    if (!success) {
      _setError('لا يوجد حساب مرتبط بهذا البريد الإلكتروني.');
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
      _setError(e is AppException ? e.message : 'كلمة سر المتجر غير صحيحة.');
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
      if (store.license.isExpired) {
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
      appEvents.fireWalletsChanged();
      appEvents.fireTransactionsChanged();
      appEvents.fireDebtsChanged();
    } catch (e) {
      _setError(e is AppException
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

      _setLoading(false);
    } catch (e) {
      _setLoading(false); // Ensure loading is cleared on error
      _setError(e is AppException ? e.message : 'فشل تفعيل المفتاح: $e');
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
      _setError('حدث خطأ أثناء تسجيل الخروج');
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> refreshUserData() async {
    if (_currentUser != null && _currentStore != null) {
      try {
        _currentUser = await _userRepository.getUserById(_currentUser!.userId);
        _currentStore =
            await _storeRepository.getStoreById(_currentStore!.storeId);
        notifyListeners();
      } catch (e) {
        _setError('فشل تحديث البيانات.');
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

  void _setStatus(AuthStatus status) {
    _status = status;
    if (status != AuthStatus.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _status = loading ? AuthStatus.loading : AuthStatus.idle;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _clearState() {
    _firebaseUser = null;
    _currentUser = null;
    _currentStore = null;
  }
}
