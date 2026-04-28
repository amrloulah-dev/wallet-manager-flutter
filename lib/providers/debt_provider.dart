import 'dart:async';

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
import 'base_provider.dart';
import '../core/enums/debt_enums.dart';

enum DebtProviderStatus {
  idle,
  loading,
  loadingMore,
  loaded,
  creating,
  updating,
  error
}

class DebtProvider extends BaseProvider {
  final DebtRepository _debtRepository;
  AuthProvider _authProvider;

  // State
  String? _currentStoreId;
  List<DebtModel> _debts = [];
  Map<String, DebtModel> _debtMap = {};
  Map<String, dynamic> _summary = {};

  bool _hasMore = true;

  // Status
  DebtProviderStatus _status = DebtProviderStatus.idle;
  String? _errorMessage;

  // Filter
  String _currentFilter = 'all'; // 'all' | 'open' | 'paid'
  DebtType _currentDebtType = DebtType.transaction; // ENUM refactor

  // Constructor
  DebtProvider({
    required AuthProvider authProvider,
    DebtRepository? debtRepository,
    String? storeId,
  })  : _authProvider = authProvider,
        _debtRepository = debtRepository ?? sl<DebtRepository>(),
        _currentStoreId = storeId;

  // Getters
  List<DebtModel> get debts => _debts;
  Map<String, DebtModel> get debtMap => _debtMap;
  Map<String, dynamic> get summary => _summary;
  DebtProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;
  DebtType get currentDebtType => _currentDebtType;
  bool get hasMore => _hasMore;
  bool get isLoading => _status == DebtProviderStatus.loading;
  bool get isLoadingMore => _status == DebtProviderStatus.loadingMore;
  bool get isCreating => _status == DebtProviderStatus.creating;
  bool get isUpdating => _status == DebtProviderStatus.updating;

  void _rebuildDebtMap() {
    _debtMap = {for (var debt in _debts) debt.debtId: debt};
  }

  void _updateStatus(DebtProviderStatus status) {
    if (isDisposed) return;
    _status = status;
    // Reset error when starting a new operation
    if (status == DebtProviderStatus.loading ||
        status == DebtProviderStatus.creating ||
        status == DebtProviderStatus.updating) {
      _errorMessage = null;
    }
    safeNotify();
  }

  @override
  void setError(String errorCode, [Object? error, StackTrace? stack, bool showToast = false, String operation = 'debt_operation']) {
    if (isDisposed) return;
    _errorMessage = errorCode;
    _status = DebtProviderStatus.error;
    
    super.setError(
      errorCode,
      error,
      stack,
      showToast,
      operation,
    );
    
    safeNotify();
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

  void setDebtType(DebtType type) {
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

    _updateStatus(DebtProviderStatus.loading);
    _errorMessage = null;
    safeNotify();

    try {
      // Use getDebtsByDateRange for pagination, passing far-past/future dates for "all"
      final items = await _debtRepository.getDebtsByDateRange(
        _currentStoreId!,
        DateTime(2020),
        DateTime(2100),
        loadMore: false,
      );

      _debts = items;
      _hasMore = items.length >= 20;
      
      _rebuildDebtMap();
      await _fetchSummary();
      _updateStatus(DebtProviderStatus.loaded);
    } catch (e, stack) {
      setError('فشل في جلب الديون.', e, stack);
    } finally {
      safeNotify();
    }
  }

  Future<void> fetchMoreDebts() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null) {
      return;
    }

    _updateStatus(DebtProviderStatus.loadingMore);
    safeNotify();

    try {
      final items = await _debtRepository.getDebtsByDateRange(
        _currentStoreId!,
        DateTime(2020),
        DateTime(2100),
        loadMore: true,
      );

      if (items.isEmpty) {
        _hasMore = false;
      } else {
        _debts.addAll(items);
        _hasMore = items.length >= 20;
      }

      _rebuildDebtMap();
      _updateStatus(DebtProviderStatus.loaded);
    } catch (e, stack) {
      setError('فشل في جلب المزيد من الديون.', e, stack);
    } finally {
      safeNotify();
    }
  }

  Future<void> _fetchSummary() async {
    if (_currentStoreId == null) return;
    try {
      final stats = await _debtRepository.fetchDebtStatistics(
        storeId: _currentStoreId!,
        type: _currentDebtType.name,
      );

      _summary = {
        'openDebtsCount': stats['openCount'],
        'paidDebtsCount': stats['paidCount'],
        'totalDebtsCount':
            NumberParser.toInt(stats['openCount']) + NumberParser.toInt(stats['paidCount']),
        'totalOpenAmount': stats['openTotal'],
        'totalPaidAmount': stats['paidTotal'],
      };
      safeNotify();
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
    required DebtType debtType, // ENUM refactor
    required double amountDue,
    String? notes,
    required String createdBy,
  }) async {
    _status = DebtProviderStatus.creating;
    _errorMessage = null;
    safeNotify();
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
          debtDate: DateTime.now(),
          createdAt: DateTime.now(),
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

      _updateStatus(DebtProviderStatus.loaded); // Reset status
      return true;
    } on AppException catch (e) {
      setError(e.message);
      rethrow;
    } catch (e, stack) {
      setError('فشل في إنشاء الدين.', e, stack);
      rethrow;
    } finally {
      if (_status == DebtProviderStatus.creating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> addPartialDebt(
      String debtId, double amountToAdd, String userId) async {
    _updateStatus(DebtProviderStatus.updating);
    safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createDebt);

      try {
        await _debtRepository.addPartialDebt(debtId, amountToAdd, userId);
      } catch (e) {
        rethrow;
      }

      return true;
    } on AppException catch (e) {
      setError(e.message);
      rethrow;
    } catch (e, stack) {
      setError('فشل في إضافة المبلغ إلى الدين.', e, stack);
      rethrow;
    } finally {
      if (_status == DebtProviderStatus.updating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> updateDebt(String debtId, Map<String, dynamic> data) async {
    _updateStatus(DebtProviderStatus.updating);
    safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createDebt);

      try {
        await _debtRepository.updateDebt(debtId, data);
      } catch (e) {
        rethrow;
      }

      return true;
    } on ServerException catch (e) {
      setError(e.message);
      rethrow;
    } catch (e, stack) {
      setError('فشل في تحديث الدين.', e, stack);
      rethrow;
    } finally {
      if (_status == DebtProviderStatus.updating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> payPartialDebt(
      String debtId, double amountToPay, String userId) async {
    _updateStatus(DebtProviderStatus.updating);
    safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createDebt);

      try {
        await _debtRepository.processPayment(debtId, amountToPay, userId);
      } catch (e) {
        rethrow;
      }

      return true;
    } on AppException catch (e) {
      setError(e.message);
      rethrow;
    } catch (e, stack) {
      setError('فشل في تسديد الدين.', e, stack);
      rethrow;
    } finally {
      if (_status == DebtProviderStatus.updating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> deleteDebt(String debtId) async {
    _updateStatus(DebtProviderStatus.updating);
    safeNotify();
    try {
      await _validateUserAndPermission((p) => p.deleteDebt);

      try {
        await _debtRepository.deleteDebt(debtId);
      } catch (e) {
        rethrow;
      }

      return true;
    } on ServerException catch (e) {
      setError(e.message);
      rethrow;
    } catch (e, stack) {
      setError('فشل في حذف الدين.', e, stack);
      rethrow;
    } finally {
      if (_status == DebtProviderStatus.updating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
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
