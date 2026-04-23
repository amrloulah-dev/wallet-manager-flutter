import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/number_parser.dart';
import '../data/repositories/debt_repository.dart';
import '../data/models/debt_model.dart';
import '../core/errors/app_exceptions.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../data/models/user_model.dart';
import '../data/models/user_permissions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import '../providers/auth_provider.dart';
import '../core/services/analytics_service.dart';

enum DebtStatus {
  idle,
  loading,
  loadingMore,
  loaded,
  creating,
  updating,
  error
}

class DebtProvider extends ChangeNotifier {
  final DebtRepository _debtRepository;
  AuthProvider _authProvider;

  // State
  String? _currentStoreId;
  List<DebtModel> _debts = [];
  Map<String, DebtModel> _debtMap = {};
  Map<String, dynamic> _summary = {};

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  // Status
  DebtStatus _status = DebtStatus.idle;
  String? _errorMessage;

  // Filter
  String _currentFilter = 'all'; // 'all' | 'open' | 'paid'
  String _currentDebtType = 'transaction'; // 'transaction' | 'store_sale'

  bool _isDisposed = false;

  // Constructor
  DebtProvider({
    required AuthProvider authProvider,
    DebtRepository? debtRepository,
    String? storeId,
  })  : _authProvider = authProvider,
        _debtRepository = debtRepository ?? sl<DebtRepository>(),
        _currentStoreId = storeId;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Getters
  List<DebtModel> get debts => _debts;
  Map<String, DebtModel> get debtMap => _debtMap;
  Map<String, dynamic> get summary => _summary;
  DebtStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;
  String get currentDebtType => _currentDebtType;
  bool get hasMore => _hasMore;
  bool get isLoading => _status == DebtStatus.loading;
  bool get isLoadingMore => _status == DebtStatus.loadingMore;
  bool get isCreating => _status == DebtStatus.creating;
  bool get isUpdating => _status == DebtStatus.updating;

  void _rebuildDebtMap() {
    _debtMap = {for (var debt in _debts) debt.debtId: debt};
  }

  void _updateStatus(DebtStatus status) {
    if (_isDisposed) return;
    _status = status;
  }

  void _safeNotify() {
    if (!_isDisposed && hasListeners) {
      Future.microtask(() => notifyListeners());
    }
  }

  void _setError(String message, [dynamic e, StackTrace? stack]) {
    if (_isDisposed) return;
    _errorMessage = message;
    _status = DebtStatus.error;
    if (e != null) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.medium,
          operation: 'debt_operation',
          stackTrace: stack);
    }
    _safeNotify();
  }

  void setStoreId(String? storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      fetchInitialDebts();
    }
  }

  void updateAuthState(AuthProvider auth) {
    _authProvider = auth;
    setStoreId(auth.currentStoreId);
  }

  void setDebtType(String type) {
    if (_currentDebtType != type) {
      _currentDebtType = type;
      fetchInitialDebts();
    }
  }

  void setFilter(String filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      fetchInitialDebts();
    }
  }

  Future<void> fetchInitialDebts({bool forceRefresh = false}) async {
    if (_currentStoreId == null) return;

    _updateStatus(DebtStatus.loading);
    _errorMessage = null;
    _safeNotify();

    try {
      // Use getDebtsByDateRange for pagination, passing far-past/future dates for "all"
      final result = await _debtRepository.getDebtsByDateRange(
        _currentStoreId!,
        DateTime(2020),
        DateTime(2100),
      );

      _debts = result.items;
      _lastDocument = result.lastDocument;
      _hasMore = result.items.length >= 20;
      
      _rebuildDebtMap();
      await _fetchSummary();
      _updateStatus(DebtStatus.loaded);
    } catch (e, stack) {
      _setError('فشل في جلب الديون.', e, stack);
    } finally {
      _safeNotify();
    }
  }

  Future<void> fetchMoreDebts() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null || _lastDocument == null) {
      return;
    }

    _updateStatus(DebtStatus.loadingMore);
    _safeNotify();

    try {
      final result = await _debtRepository.getDebtsByDateRange(
        _currentStoreId!,
        DateTime(2020),
        DateTime(2100),
        lastDocument: _lastDocument,
      );

      if (result.items.isEmpty) {
        _hasMore = false;
      } else {
        _debts.addAll(result.items);
        _lastDocument = result.lastDocument;
        _hasMore = result.items.length >= 20;
      }

      _rebuildDebtMap();
      _updateStatus(DebtStatus.loaded);
    } catch (e, stack) {
      _setError('فشل في جلب المزيد من الديون.', e, stack);
    } finally {
      _safeNotify();
    }
  }

  Future<void> _fetchSummary() async {
    if (_currentStoreId == null) return;
    try {
      final stats = await _debtRepository.fetchDebtStatistics(
        storeId: _currentStoreId!,
        type: _currentDebtType,
      );

      _summary = {
        'openDebtsCount': stats['openCount'],
        'paidDebtsCount': stats['paidCount'],
        'totalDebtsCount':
            NumberParser.toInt(stats['openCount']) + NumberParser.toInt(stats['paidCount']),
        'totalOpenAmount': stats['openTotal'],
        'totalPaidAmount': stats['paidTotal'],
      };
      _safeNotify();
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'debt_search',
          stackTrace: stack);
    }
  }

  Future<bool> createDebt({
    required String customerName,
    required String customerPhone,
    required String debtType,
    required double amountDue,
    String? notes,
    required String createdBy,
  }) async {
    _updateStatus(DebtStatus.creating);
    _safeNotify();
    try {
      final user = await _validateUserAndPermission((p) => p.createDebt);

      if (_currentStoreId == null) {
        throw ValidationException('Store ID not found.');
      }
      if (amountDue <= 0) throw ValidationException('Amount must be positive.');

      final existingDebtByPhone = await _debtRepository.getDebtByCustomerPhone(
          _currentStoreId!, customerPhone);
      if (existingDebtByPhone != null) {
        return await addPartialDebt(
            existingDebtByPhone.debtId, amountDue, user.userId);
      } else {
        final newDebt = DebtModel(
          debtId: _debtRepository.generateId(),
          storeId: _currentStoreId!,
          customerName: customerName,
          customerPhone: customerPhone,
          debtType: debtType,
          amountDue: amountDue,
          totalAmount: amountDue,
          notes: notes,
          debtDate: Timestamp.now(),
          createdAt: Timestamp.now(),
          createdBy: user.userId,
        );

        try {
          await _debtRepository.createDebt(newDebt);
        } catch (e, stack) {
          AppErrorHandler.handle(e,
              severity: ErrorSeverity.medium,
              operation: 'debt_create',
              stackTrace: stack);
          rethrow;
        }
        AnalyticsService.logDebtAdded();
      }

      // Update Stats if it's an employee
      if (user.isEmployee) {
        await _authProvider.updateEmployeeStats(
          userId: user.userId,
          incrementDebts: 1,
        );
      }

      _updateStatus(DebtStatus.loaded); // Reset status
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في إنشاء الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.creating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> addPartialDebt(
      String debtId, double amountToAdd, String userId) async {
    _updateStatus(DebtStatus.updating);
    _safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createDebt);

      try {
        await _debtRepository.addPartialDebt(debtId, amountToAdd, userId);
      } catch (e) {
        rethrow;
      }

      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في إضافة المبلغ إلى الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.updating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> updateDebt(String debtId, Map<String, dynamic> data) async {
    _updateStatus(DebtStatus.updating);
    _safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createDebt);

      try {
        await _debtRepository.updateDebt(debtId, data);
      } catch (e) {
        rethrow;
      }

      return true;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في تحديث الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.updating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> payPartialDebt(
      String debtId, double amountToPay, String userId) async {
    _updateStatus(DebtStatus.updating);
    _safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createDebt);

      try {
        await _debtRepository.processPayment(debtId, amountToPay, userId);
      } catch (e) {
        rethrow;
      }

      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في تسديد الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.updating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> deleteDebt(String debtId) async {
    _updateStatus(DebtStatus.updating);
    _safeNotify();
    try {
      await _validateUserAndPermission((p) => p.deleteDebt);

      try {
        await _debtRepository.deleteDebt(debtId);
      } catch (e) {
        rethrow;
      }

      return true;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في حذف الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.updating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<UserModel> _validateUserAndPermission(
      bool Function(UserPermissions) permissionCheck) async {
    final user = _authProvider.currentUser;
    if (user == null) throw AuthException('يجب تسجيل الدخول أولاً.');

    // Owners have all permissions
    if (user.isOwner) return user;

    if (user.permissions == null || !permissionCheck(user.permissions!)) {
      throw PermissionException();
    }
    return user;
  }
}
