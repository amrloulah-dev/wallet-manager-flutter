import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/user_model.dart';
import '../data/repositories/employee_repository.dart';
import '../core/errors/app_exceptions.dart';
import '../data/models/user_permissions.dart'; // Added import
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

  Set<String> _suspendedEmployeeIds = {};

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

  @override
  void dispose() {
    _employeeStreamSubscription?.cancel();
    super.dispose();
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
        notifyListeners();
      }
    }
  }

  void refresh() {
    if (_currentStoreId != null) {
      _listenToEmployees(_currentStoreId!);
    }
  }

  void _listenToEmployees(String storeId) {
    _setStatus(EmployeeStatus.loading);
    _employeeStreamSubscription =
        _employeeRepository.watchEmployees(storeId).listen(
      (employees) {
        _employees = employees;
        _recalculateSuspendedEmployees();
        _setStatus(EmployeeStatus.loaded);
      },
      onError: (error) {
        _setError('Failed to load employees.');
      },
    );
  }

  Future<bool> addEmployee({
    required String fullName,
    required String phone,
    required String pin,
    required UserPermissions permissions, // Added parameter
  }) async {
    if (_currentStoreId == null) {
      _setError('Store ID not set');
      return false;
    }
    // Redundant validation removed. The UI layer's Form validation handles this.

    if (_subscriptionProvider != null && !_subscriptionProvider!.canAddEmployee(employeesCount)) {
      _setError('تم الوصول للحد الأقصى للموظفين (${_subscriptionProvider!.maxEmployees})');
      return false;
    }

    _setStatus(EmployeeStatus.loading);
    try {
      await _employeeRepository.addEmployee(
        storeId: _currentStoreId!,
        fullName: fullName,
        phone: phone,
        pin: pin,
        permissions: permissions, // Pass permissions
      );
      // No longer need to fire event, stream will update automatically
      _errorMessage = null;
      _setStatus(EmployeeStatus.loaded);
      return true;
    } on ValidationException catch (e) {
      _setError(e.message);
      return false;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<UserModel?> getEmployeeByPIN({
    required String storeId,
    required String pin,
  }) async {
    // Validate PIN
    if (pin.length != 4 || !_isNumeric(pin)) {
      _setError('الرقم السري يجب أن يكون 4 أرقام');
      return null;
    }

    try {
      final employee = await _employeeRepository.getEmployeeByPIN(
        storeId: storeId,
        pin: pin,
      );

      if (employee == null) {
        _setError('الرقم السري غير صحيح');
        return null;
      }

      if (isEmployeeFrozen(employee)) {
        _setError('هذا الحساب مجمد بسبب تجاوز الحد المسموح في باقتك');
        return null;
      }

      return employee;
    } catch (e) {
      if (e is ServerException) {
        _setError(e.message);
      } else {
        _setError('حدث خطأ أثناء التحقق من الرقم السري');
      }
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
      ..sort((a, b) => (a.createdAt ?? Timestamp.now())
          .compareTo(b.createdAt ?? Timestamp.now()));

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
    _setStatus(EmployeeStatus.loading);
    try {
      await _employeeRepository.deactivateEmployee(userId);
      // No longer need to fire event, stream will update automatically
      _setStatus(EmployeeStatus.loaded);
      return true;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> resetEmployeePIN({
    required String userId,
    required String newPin,
  }) async {
    if (newPin.length != 4 || !_isNumeric(newPin)) {
      _setError('PIN must be 4 digits');
      return false;
    }
    _setStatus(EmployeeStatus.loading);
    try {
      return await _employeeRepository.resetEmployeePIN(
          userId: userId, newPin: newPin);
    } on ValidationException catch (e) {
      _setError(e.message);
      return false;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> updateEmployeePermissions(
      String userId, UserPermissions permissions) async {
    _setStatus(EmployeeStatus.loading);
    try {
      await _employeeRepository.updateEmployeePermissions(
        userId: userId,
        permissions: permissions,
      );
      // No need to refresh locally as stream will update
      _setStatus(EmployeeStatus.loaded);
      return true;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to update permissions.');
      return false;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleActiveFilter() {
    _showActiveOnly = !_showActiveOnly;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  UserModel? getEmployeeById(String userId) {
    try {
      return _employees.firstWhere((e) => e.userId == userId);
    } catch (e) {
      return null;
    }
  }

  void _setStatus(EmployeeStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = EmployeeStatus.error;
    notifyListeners();
  }

  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  void clearError() {
    _errorMessage = null;
    _status = EmployeeStatus.loaded;
    notifyListeners();
  }
}
