import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/user_model.dart';
import '../data/repositories/employee_repository.dart';
import '../core/errors/app_exceptions.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../data/models/user_permissions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'subscription_provider.dart';

enum EmployeeStatus { initial, loading, loaded, error }

class EmployeeProvider extends ChangeNotifier {
  final EmployeeRepository _employeeRepository;
  SubscriptionProvider? _subscriptionProvider;

  List<UserModel> _employees = [];
  EmployeeStatus _status = EmployeeStatus.initial;
  String? _errorMessage;
  String? _currentStoreId;
  String _searchQuery = '';
  bool _showActiveOnly = true;

  final Set<String> _suspendedEmployeeIds = {};

  StreamSubscription? _employeeStreamSubscription;

  List<UserModel> get employees => _employees;
  EmployeeStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentStoreId => _currentStoreId;
  bool get isLoading => _status == EmployeeStatus.loading;
  bool get hasError => _status == EmployeeStatus.error;
  String get searchQuery => _searchQuery;
  bool get showActiveOnly => _showActiveOnly;

  List<UserModel> get filteredEmployees {
    return _employees.where((employee) {
      final query = _searchQuery.toLowerCase();
      final nameMatch = employee.fullName.toLowerCase().contains(query);
      final phoneMatch = employee.phone?.contains(query) ?? false;
      final activeMatch = !_showActiveOnly || employee.isActive;
      return (nameMatch || phoneMatch) && activeMatch;
    }).toList();
  }

  int get employeesCount =>
      _employees.where((e) => e.isActive && e.role != 'owner').length;
  List<UserModel> get activeEmployees =>
      _employees.where((e) => e.isActive).toList();
  List<UserModel> get inactiveEmployees =>
      _employees.where((e) => !e.isActive).toList();

  EmployeeProvider({required EmployeeRepository employeeRepository})
      : _employeeRepository = employeeRepository;

  void updateSubscriptionProvider(SubscriptionProvider subscriptionProvider) {
    _subscriptionProvider = subscriptionProvider;
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _employeeStreamSubscription?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void setStoreId(String? storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      _employeeStreamSubscription?.cancel();
      _employees = [];
      _status = EmployeeStatus.initial;
      _errorMessage = null;
      _searchQuery = '';

      if (storeId != null) {
        _listenToEmployees(storeId);
      } else {
        _safeNotify();
      }
    }
  }

  void refresh() {
    if (_currentStoreId != null) {
      _listenToEmployees(_currentStoreId!);
    }
  }

  void _listenToEmployees(String storeId) {
    _updateStatus(EmployeeStatus.loading);
    _safeNotify();
    _employeeStreamSubscription =
        _employeeRepository.watchEmployees(storeId).listen(
      (employees) {
        _employees = employees;
        _recalculateSuspendedEmployees();
        _updateStatus(EmployeeStatus.loaded);
        _safeNotify();
      },
      onError: (error) {
        _setError('فشل جلب الموظفين.', error);
        _safeNotify();
      },
    );
  }

  Future<bool> addEmployee({
    required String fullName,
    required String phone,
    required String pin,
    required UserPermissions permissions,
  }) async {
    if (_currentStoreId == null) {
      _setError('لم يتم تعيين المتجر');
      _safeNotify();
      return false;
    }

    if (_subscriptionProvider != null &&
        !_subscriptionProvider!.canAddEmployee(employeesCount)) {
      _setError(
          'تم الوصول للحد الأقصى للموظفين (${_subscriptionProvider!.maxEmployees})');
      _safeNotify();
      return false;
    }

    _updateStatus(EmployeeStatus.loading);
    _safeNotify();
    try {
      final newEmployee = await _employeeRepository.addEmployee(
        storeId: _currentStoreId!,
        fullName: fullName,
        phone: phone,
        pin: pin,
        permissions: permissions,
      );

      _employeeRepository.provisionIdentity(newEmployee);

      _errorMessage = null;
      _updateStatus(EmployeeStatus.loaded);
      return true;
    } on ValidationException catch (e) {
      _setError(e.message);
      return false;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('حدث خطأ أثناء إضافة الموظف', e, stack);
      return false;
    } finally {
      if (_status == EmployeeStatus.loading) {
        _updateStatus(EmployeeStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<UserModel?> getEmployeeByPIN({
    required String storeId,
    required String pin,
  }) async {
    if (pin.length != 4 || !_isNumeric(pin)) {
      _setError('الرقم السري يجب أن يكون 4 أرقام');
      _safeNotify();
      return null;
    }

    try {
      final employee = await _employeeRepository.getEmployeeByPIN(
        storeId: storeId,
        pin: pin,
      );

      if (employee == null) {
        _setError('الرقم السري غير صحيح');
        _safeNotify();
        return null;
      }

      if (isEmployeeFrozen(employee)) {
        _setError('هذا الحساب مجمد بسبب تجاوز الحد المسموح في باقتك');
        _safeNotify();
        return null;
      }

      return employee;
    } catch (e, stack) {
      if (e is ServerException) {
        _setError(e.message);
      } else {
        _setError('حدث خطأ أثناء التحقق من الرقم السري', e, stack);
      }
      _safeNotify();
      return null;
    }
  }

  void _recalculateSuspendedEmployees() {
    _suspendedEmployeeIds.clear();
    if (_subscriptionProvider == null || _currentStoreId == null) return;
    final maxEmployees = _subscriptionProvider!.maxEmployees;

    final activeStaff = _employees
        .where((e) => e.isActive && e.role != 'owner')
        .toList()
      ..sort((a, b) => (a.createdAt).compareTo(b.createdAt));

    if (activeStaff.length <= maxEmployees) return;

    for (int i = maxEmployees; i < activeStaff.length; i++) {
      _suspendedEmployeeIds.add(activeStaff[i].userId);
    }
  }

  bool isEmployeeFrozen(UserModel employee) {
    if (employee.role == 'owner') return false;
    if (!employee.isActive) return false;
    return _suspendedEmployeeIds.contains(employee.userId);
  }

  Future<bool> deactivateEmployee(String userId) async {
    _updateStatus(EmployeeStatus.loading);
    _safeNotify();
    try {
      final employee = getEmployeeById(userId);
      await _employeeRepository.deactivateEmployee(userId);

      if (employee != null) {
        _employeeRepository.cleanupIdentity(employee);
      }

      // No longer need to fire event, stream will update automatically
      _updateStatus(EmployeeStatus.loaded);
      return true;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      if (_status == EmployeeStatus.loading) {
        _updateStatus(EmployeeStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> resetEmployeePIN({
    required String userId,
    required String newPin,
  }) async {
    if (newPin.length != 4 || !_isNumeric(newPin)) {
      _setError('الرقم السري يجب أن يكون 4 أرقام');
      _safeNotify();
      return false;
    }
    _updateStatus(EmployeeStatus.loading);
    _safeNotify();
    try {
      final employee = getEmployeeById(userId);
      final success = await _employeeRepository.resetEmployeePIN(
          userId: userId, newPin: newPin);

      if (success && employee != null) {
        _employeeRepository.syncCredential(employee, newPin);
      }
      return success;
    } on ValidationException catch (e) {
      _setError(e.message);
      return false;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      if (_status == EmployeeStatus.loading) {
        _updateStatus(EmployeeStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> updateEmployeePermissions(
      String userId, UserPermissions permissions) async {
    _updateStatus(EmployeeStatus.loading);
    _safeNotify();
    try {
      await _employeeRepository.updateEmployeePermissions(
        userId: userId,
        permissions: permissions,
      );
      // No need to refresh locally as stream will update
      _updateStatus(EmployeeStatus.loaded);
      return true;
    } catch (e, stack) {
      _setError('فشل تحديث الصلاحيات.', e, stack);
      return false;
    } finally {
      if (_status == EmployeeStatus.loading) {
        _updateStatus(EmployeeStatus.loaded);
      }
      _safeNotify();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _safeNotify();
  }

  void toggleActiveFilter() {
    _showActiveOnly = !_showActiveOnly;
    _safeNotify();
  }

  void clearSearch() {
    _searchQuery = '';
    _safeNotify();
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

  void _updateStatus(EmployeeStatus status) {
    if (_isDisposed) return;
    _status = status;
  }

  void _setError(String message, [Object? error, StackTrace? stack]) {
    if (_isDisposed) return;
    _errorMessage = message;
    _status = EmployeeStatus.error;
    AppErrorHandler.handle(error ?? message,
        severity: ErrorSeverity.medium,
        operation: 'employee_operation',
        stackTrace: stack);
    // Note: notifyListeners() is now handled by the calling method's finally block
  }

  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  void clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    _status = EmployeeStatus.loaded;
    _safeNotify();
  }
}
