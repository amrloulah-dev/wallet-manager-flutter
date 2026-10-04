import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../data/models/user_model.dart';
import '../data/repositories/employee_repository.dart';
import '../core/errors/app_exceptions.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../data/models/user_permissions.dart';
import 'auth_provider.dart';
import 'subscription_provider.dart';
import 'platform_settings_provider.dart';
import 'package:get_it/get_it.dart';
import 'base_provider.dart';
import '../core/enums/user_enums.dart';

enum EmployeeProviderStatus { initial, loading, loaded, error }

class EmployeeProvider extends BaseProvider {
  final EmployeeRepository _employeeRepository;
  AuthProvider? _authProvider;
  SubscriptionProvider? _subscriptionProvider;

  List<UserModel> _employees = [];
  EmployeeProviderStatus _status = EmployeeProviderStatus.initial;
  String? _errorMessage;
  String? _currentStoreId;
  String _searchQuery = '';
  bool _showActiveOnly = true;

  final Set<String> _suspendedEmployeeIds = {};

  List<UserModel> get employees => _employees;
  EmployeeProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentStoreId => _currentStoreId;
  bool get isLoading => _status == EmployeeProviderStatus.loading;
  bool get hasError => _status == EmployeeProviderStatus.error;
  String get searchQuery => _searchQuery;
  bool get showActiveOnly => _showActiveOnly;

  List<UserModel> get filteredEmployees => _employees;

  int get employeesCount =>
      _employees.where((e) => e.isActive && e.role != UserRole.owner).length;
  List<UserModel> get activeEmployees =>
      _employees.where((e) => e.isActive).toList();
  List<UserModel> get inactiveEmployees =>
      _employees.where((e) => !e.isActive).toList();

  EmployeeProvider({required EmployeeRepository employeeRepository})
      : _employeeRepository = employeeRepository;

  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  void updateSubscriptionProvider(SubscriptionProvider subscriptionProvider) {
    _subscriptionProvider = subscriptionProvider;
    if (_employees.isNotEmpty) {
      _recalculateSuspendedEmployees();
      _enforceEmployeeLimits();
      safeNotify();
    }
  }

  void setStoreId(String? storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      _employees = [];
      _status = EmployeeProviderStatus.initial;
      _errorMessage = null;
      _searchQuery = '';

      if (storeId != null && storeId.isNotEmpty) {
        _fetchEmployees(storeId);
      } else {
        safeNotify();
      }
    }
  }

  void refresh() {
    if (_currentStoreId != null) {
      _fetchEmployees(_currentStoreId!);
    }
  }

  Future<void> _fetchEmployees(String storeId) async {
    if (kDebugMode) {
      debugPrint(
          '🔍 [EmployeeProvider._fetchEmployees] Starting fetch for storeId: "$storeId"');
    }
    _updateStatus(EmployeeProviderStatus.loading);
    safeNotify();

    try {
      final employees = await _employeeRepository.getEmployeesByStoreId(
        storeId: storeId,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        activeOnly: _showActiveOnly,
      );
      _employees = employees;
      _recalculateSuspendedEmployees();
      _updateStatus(EmployeeProviderStatus.loaded);
      if (kDebugMode) {
        debugPrint(
            '🔍 [EmployeeProvider._fetchEmployees] Successfully loaded ${employees.length} employees for storeId: "$storeId"');
      }
    } catch (error, stack) {
      _employees = [];
      AppErrorHandler.handle(
        error,
        stackTrace: stack,
        operation: 'EmployeeProvider._fetchEmployees',
      );
      if (error is FirebaseException) {
        if (kDebugMode) {
          debugPrint(
              '💥 [EmployeeProvider._fetchEmployees] FirebaseException: code="${error.code}", message="${error.message}"');
          if (error.message != null &&
              error.message!.contains('https://console.firebase.google.com')) {
            debugPrint(
                '🔗 [FIRESTORE INDEX REQUIRED] Create index here:\n${error.message}');
          }
        }
        if (error.code == 'permission-denied') {
          setError('employee_error_permission_denied', error, stack);
        } else {
          setError('employee_error_fetch_failed', error, stack);
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              '💥 [EmployeeProvider._fetchEmployees] Caught fetch error for storeId: "$storeId": $error');
        }
        setError('employee_error_fetch_failed', error, stack);
      }
    } finally {
      if (_status == EmployeeProviderStatus.loading) {
        _updateStatus(EmployeeProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> addEmployee({
    required String fullName,
    required String phone,
    required String pin,
    required UserPermissions permissions,
  }) async {
    if (kDebugMode) {
      debugPrint(
          '🔍 [TRACE 2 - PROVIDER] Received User: $fullName, Permissions: ${permissions.toMap()}');
    }
    _status = EmployeeProviderStatus.loading;
    _errorMessage = null;
    safeNotify();

    // Security Guard: Only Owners can add employees (Axis 2/Phase 6)
    if (_authProvider == null || !_authProvider!.isOwner) {
      throw PermissionDeniedException();
    }

    if (_currentStoreId == null) {
      setError('employee_error_no_store');
      safeNotify();
      return false;
    }

    if (_subscriptionProvider != null &&
        !_subscriptionProvider!.canAddEmployee(employeesCount)) {
      setError('employee_error_limit_reached');
      safeNotify();
      return false;
    }

    _updateStatus(EmployeeProviderStatus.loading);
    safeNotify();
    try {
      final newEmployee = await _employeeRepository.addEmployee(
        storeId: _currentStoreId!,
        fullName: fullName,
        phone: phone,
        pin: pin,
        permissions: permissions,
      );

      _employees.insert(0, newEmployee);
      _recalculateSuspendedEmployees();

      _errorMessage = null;
      _updateStatus(EmployeeProviderStatus.loaded);
      return true;
    } on ValidationException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } on ServerException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      setError('employee_error_create_failed', e, stack);
      return false;
    } finally {
      if (_status == EmployeeProviderStatus.loading) {
        _updateStatus(EmployeeProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<UserModel?> getEmployeeByPIN({
    required String storeId,
    required String pin,
  }) async {
    if (pin.length != 6 || !_isNumeric(pin)) {
      setError('employee_error_invalid_pin');
      safeNotify();
      return null;
    }

    try {
      final employee = await _employeeRepository.getEmployeeByPIN(
        storeId: storeId,
        pin: pin,
      );

      if (employee == null) {
        setError('employee_error_wrong_pin');
        safeNotify();
        return null;
      }

      if (isEmployeeFrozen(employee)) {
        setError('employee_error_account_frozen');
        safeNotify();
        return null;
      }

      return employee;
    } catch (e, stack) {
      if (e is ServerException) {
        setError(e.message, e, stack);
      } else {
        setError('employee_error_pin_check_failed', e, stack);
      }
      safeNotify();
      return null;
    }
  }

  void _recalculateSuspendedEmployees() {
    _suspendedEmployeeIds.clear();
    if (_subscriptionProvider == null || _currentStoreId == null) return;
    final maxEmployees = _subscriptionProvider!.maxEmployees;

    final activeStaff = _employees
        .where((e) => e.isActive && e.role != UserRole.owner)
        .toList()
      ..sort((a, b) => (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now()));

    if (activeStaff.length <= maxEmployees) return;

    for (int i = maxEmployees; i < activeStaff.length; i++) {
      _suspendedEmployeeIds.add(activeStaff[i].userId);
    }
  }

  bool isEmployeeFrozen(UserModel employee) {
    if (employee.role == UserRole.owner) return false;
    if (!employee.isActive) return false;
    return _suspendedEmployeeIds.contains(employee.userId);
  }

  Future<bool> deactivateEmployee(String userId) async {
    _status = EmployeeProviderStatus.loading;
    _errorMessage = null;
    safeNotify();

    // Security Guard: Only Owners can deactivate employees (Axis 2/Phase 6)
    if (_authProvider == null || !_authProvider!.isOwner) {
      throw PermissionDeniedException();
    }

    try {
      final employee = getEmployeeById(userId);
      await _employeeRepository.deactivateEmployee(userId);

      if (employee != null) {
        _employeeRepository.cleanupIdentity(employee);
      }

      // No longer need to fire event, stream will update automatically
      _updateStatus(EmployeeProviderStatus.loaded);
      return true;
    } on ServerException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      setError('employee_error_deactivate_failed', e, stack);
      return false;
    } finally {
      if (_status == EmployeeProviderStatus.loading) {
        _updateStatus(EmployeeProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> resetEmployeePIN({
    required String userId,
    required String newPin,
  }) async {
    if (newPin.length != 6 || !_isNumeric(newPin)) {
      setError('employee_error_invalid_pin');
      safeNotify();
      return false;
    }

    // Security Guard: Only Owners can reset PINs (Axis 2/Phase 6)
    if (_authProvider == null || !_authProvider!.isOwner) {
      throw PermissionDeniedException();
    }

    _updateStatus(EmployeeProviderStatus.loading);
    safeNotify();
    try {
      final employee = getEmployeeById(userId);
      final success = await _employeeRepository.resetEmployeePIN(
          userId: userId, newPin: newPin);

      if (success && employee != null) {
        _employeeRepository.syncCredential(employee, newPin);
      }
      return success;
    } on ValidationException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } on ServerException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      setError('employee_error_reset_pin_failed', e, stack);
      return false;
    } finally {
      if (_status == EmployeeProviderStatus.loading) {
        _updateStatus(EmployeeProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> updateEmployeePermissions(
      String userId, UserPermissions permissions) async {
    _updateStatus(EmployeeProviderStatus.loading);
    safeNotify();

    // Security Guard: Only Owners can update permissions (Axis 2/Phase 6)
    if (_authProvider == null || !_authProvider!.isOwner) {
      throw PermissionDeniedException();
    }

    try {
      await _employeeRepository.updateEmployeePermissions(
        userId: userId,
        permissions: permissions,
      );
      // No need to refresh locally as stream will update
      _updateStatus(EmployeeProviderStatus.loaded);
      return true;
    } catch (e, stack) {
      setError('employee_error_update_perms_failed', e, stack);
      return false;
    } finally {
      if (_status == EmployeeProviderStatus.loading) {
        _updateStatus(EmployeeProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      if (_currentStoreId != null) {
        _fetchEmployees(_currentStoreId!);
      } else {
        safeNotify();
      }
    }
  }

  void toggleActiveFilter() {
    _showActiveOnly = !_showActiveOnly;
    if (_currentStoreId != null) {
      _fetchEmployees(_currentStoreId!);
    } else {
      safeNotify();
    }
  }

  void clearSearch() {
    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      if (_currentStoreId != null) {
        _fetchEmployees(_currentStoreId!);
      } else {
        safeNotify();
      }
    }
  }

  UserModel? getEmployeeById(String userId) {
    try {
      final index = _employees.indexWhere((e) => e.userId == userId);
      return index != -1 ? _employees[index] : null;
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'get_employee_by_id',
          stackTrace: stack);
      return null;
    }
  }

  void _updateStatus(EmployeeProviderStatus status) {
    if (isDisposed) return;
    _status = status;
  }

  @override
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'employee_operation']) {
    if (isDisposed) return;
    _errorMessage = errorCode;
    _status = EmployeeProviderStatus.error;
    super.setError(errorCode, error, stack, showToast, operation);
  }

  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  void clearError() {
    if (isDisposed) return;
    _errorMessage = null;
    _status = EmployeeProviderStatus.loaded;
    safeNotify();
  }

  Future<void> _enforceEmployeeLimits() async {
    // RBAC GUARD: Only owners can enforce limits and suspend employees.
    if (_authProvider == null || !_authProvider!.isOwner) {
      return;
    }

    final GetIt sl = GetIt.instance;
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      final settingsProvider = sl<PlatformSettingsProvider>();
      if (!settingsProvider.isInitialized ||
          settingsProvider.settings.plans.isEmpty) {
        return;
      }
    }

    final subProvider = _subscriptionProvider;
    if (subProvider == null) return;

    final maxEmployees = subProvider.maxEmployees;
    if (maxEmployees == -1) return;

    // Filter active employees (excluding owner)
    final activeStaff = _employees
        .where((e) => e.isActive && e.role != UserRole.owner)
        .toList();
    if (activeStaff.length <= maxEmployees) return;

    // Sort active staff by createdAt ascending (oldest first)
    activeStaff.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.now();
      final bDate = b.createdAt ?? DateTime.now();
      return aDate.compareTo(bDate);
    });

    // The excess active employees starting from the most recently added (indices >= maxEmployees)
    final excessEmployees = activeStaff.sublist(maxEmployees);

    // Save previous state for rollback
    final previousEmployees = _employees.toList();

    // Optimistically update RAM
    for (final employee in excessEmployees) {
      _suspendedEmployeeIds.add(employee.userId);
    }
    safeNotify();

    // Perform Firestore writes in background
    try {
      for (final employee in excessEmployees) {
        await _employeeRepository
            .updateEmployee(employee.userId, {'isSuspended': true});
      }
    } catch (e, stack) {
      // Rollback on failure
      _employees = previousEmployees;
      _recalculateSuspendedEmployees();
      for (final employee in excessEmployees) {
        _suspendedEmployeeIds.remove(employee.userId);
      }
      safeNotify();
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.medium,
          operation: 'employee_enforce_limits_rollback',
          stackTrace: stack);
    }
  }

  @visibleForTesting
  void setEmployeesForTesting(List<UserModel> employees) {
    _employees = employees;
    _recalculateSuspendedEmployees();
  }
}
