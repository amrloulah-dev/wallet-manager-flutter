import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/providers/app_events.dart';
import '../core/utils/password_hasher.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/store_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/models/store_model.dart';
import '../data/models/user_model.dart';
import '../data/services/local_storage_service.dart';
import '../core/errors/app_exceptions.dart';

enum AuthStatus { idle, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  // Repositories
  final AuthRepository _authRepository;
  final StoreRepository _storeRepository;
  final UserRepository _userRepository;
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
    LocalStorageService? localStorage,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _storeRepository = storeRepository ?? StoreRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _localStorage = localStorage ?? LocalStorageService() {
    checkAuthState();
  }

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get currentUser => _currentUser;
  StoreModel? get currentStore => _currentStore;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;

  // Helper Getters
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get isEmployee => _currentUser?.isEmployee ?? false;
  String? get currentUserId => _currentUser?.userId;
  String? get currentStoreId => _currentStore?.storeId;

  // ===== Methods =====

  /// Validate saved session on app startup
  Future<void> checkAuthState() async {
    _setStatus(AuthStatus.loading);
    try {
      final firebaseUser = _authRepository.getCurrentUser();
      if (firebaseUser == null) {
        _setStatus(AuthStatus.unauthenticated);
        return;
      }
      _firebaseUser = firebaseUser;

      final savedUserId = _localStorage.userId;
      final savedStoreId = _localStorage.storeId;
      final savedUserRole = _localStorage.userRole;

      // Prioritize validating a complete, existing session
      if (savedUserId != null &&
          savedStoreId != null &&
          savedUserRole != null) {
        final user = await _userRepository.getUserById(savedUserId);
        final store = await _storeRepository.getStoreById(savedStoreId);

        if (user != null && store != null && user.isActive) {
          // Store status check
          if (!store.isActive) {
            throw StoreInactiveException();
          }

          // License check
          if (store.license.isExpired) {
            throw LicenseExpiredException();
          }

          if (savedUserRole == 'employee' && user.isEmployee) {
            if (store.ownerId == firebaseUser.uid) {
              // Finalize as employee
              _currentUser = user;
              _currentStore = store;
              await _ensureEmployeePermissions(user);
              final updatedUser =
                  await _userRepository.getUserById(user.userId);
              _currentUser = updatedUser ?? user;
              _setStatus(AuthStatus.authenticated);
              return; // Exit successfully
            }
          } else if (savedUserRole == 'owner' && user.isOwner) {
            if (user.firebaseUid == firebaseUser.uid) {
              // Finalize as owner
              _currentUser = user;
              _currentStore = store;
              _setStatus(AuthStatus.authenticated);
              return; // Exit successfully
            }
          }
        }
        // If any check above fails, the session is corrupt/invalid, fall through.
      }

      // Fallback for incomplete/invalid session: try to recover as owner ONLY.
      final owner =
          await _userRepository.getUserByFirebaseUid(firebaseUser.uid);
      if (owner != null && owner.isOwner) {
        final store = await _storeRepository.getStoreById(owner.storeId);
        if (store != null) {
          _currentUser = owner;
          _currentStore = store;
          await _localStorage.saveSession(
            userId: owner.userId,
            storeId: store.storeId,
            userRole: owner.role,
            userName: owner.fullName,
            storeName: store.storeName,
          );
          _setStatus(AuthStatus.authenticated);
          return;
        }
      }

      // If all session validation and recovery attempts fail, logout.
      await logout();
    } catch (e) {
      await logout();
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
    required String licenseKey,
    required String licenseKeyId,
  }) async {
    _setStatus(AuthStatus.loading);
    try {
      final googleUser = _authRepository.getCurrentUser();
      if (googleUser == null) {
        throw AuthException('يجب تسجيل الدخول أولاً.');
      }
      _firebaseUser = googleUser;

      final existingStore =
          await _storeRepository.getStoreByOwnerId(googleUser.uid);
      if (existingStore != null) {
        throw AuthException('هذا الحساب يمتلك متجرًا بالفعل.');
      }

      return await _createStoreAndUser(
        uid: googleUser.uid,
        email: googleUser.email!,
        name: googleUser.displayName ?? 'مالك جديد',
        photoUrl: googleUser.photoURL,
        storeName: storeName,
        storePassword: storePassword,
        licenseKey: licenseKey,
        licenseKeyId: licenseKeyId,
      );
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
    required String licenseKey,
    required String licenseKeyId,
  }) async {
    _setStatus(AuthStatus.loading);
    try {
      final userCredential =
          await _authRepository.createUserWithEmail(email, password);
      final user = userCredential.user!;
      _firebaseUser = user;

      // Ensure display name is set
      await user.updateDisplayName(ownerName);

      return await _createStoreAndUser(
        uid: user.uid,
        email: email,
        name: ownerName,
        photoUrl: null,
        storeName: storeName,
        storePassword: storePassword,
        licenseKey: licenseKey,
        licenseKeyId: licenseKeyId,
      );
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
    required String licenseKey,
    required String licenseKeyId,
  }) async {
    final storeId = uid;
    final userId = uid;

    final newStore = StoreModel(
      storeId: storeId,
      storeName: storeName,
      storePassword: PasswordHasher.hashPassword(storePassword),
      ownerId: userId,
      ownerName: name,
      ownerEmail: email,
      ownerPhoto: photoUrl,
      createdAt: Timestamp.now(),
      license: StoreLicense(
        licenseKey: licenseKey,
        licenseType: 'premium',
        status: 'active',
        startDate: Timestamp.now(),
        expiryDate:
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
        lastCheck: Timestamp.now(),
      ),
      settings: StoreSettings(),
      stats: StoreStats(
        totalWallets: 0,
        activeWallets: 0,
        totalTransactionsToday: 0,
        totalCommissionToday: 0.0,
        lastUpdated: Timestamp.now(),
      ),
      activeLicenseKey: licenseKey,
      licenseKeyId: licenseKeyId,
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
    if (store.license.isExpired) throw LicenseExpiredException();

    _currentUser = userModel;
    _currentStore = store;

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
      if (store.license.isExpired) throw LicenseExpiredException();

      _currentUser = employee;
      _currentStore = store;

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

      // License check
      if (store.license.isExpired) {
        throw LicenseExpiredException();
      }

      _currentUser = user;
      _currentStore = store;

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

      // License check
      if (store.license.isExpired) {
        throw LicenseExpiredException();
      }

      _currentUser = updatedEmployee;
      _currentStore = store;

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
