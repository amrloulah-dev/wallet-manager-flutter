import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
import 'package:uuid/uuid.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';

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
  final Set<String> _pendingDebtIds = {};

  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  Timer? _fetchShieldTimer;
  bool _fetchShieldActive = false;

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

  void _activateFetchShield() {
    _fetchShieldActive = true;
    _fetchShieldTimer?.cancel();
    _fetchShieldTimer = Timer(const Duration(seconds: 5), () {
      _fetchShieldActive = false;
    });
  }

  @visibleForTesting
  void activateFetchShieldExternal() {
    _activateFetchShield();
  }

  // Getters
  List<DebtModel> get debts => _debts;
  Map<String, DebtModel> get debtMap => _debtMap;
  Map<String, dynamic> get summary {
    final openDebts =
        _debts.where((d) => d.debtStatus == DebtStatus.open).toList();
    final paidDebts =
        _debts.where((d) => d.debtStatus == DebtStatus.paid).toList();
    final double openTotal = openDebts.fold(0.0, (acc, d) => acc + d.amountDue);
    final double paidTotal =
        paidDebts.fold(0.0, (acc, d) => acc + d.totalAmount);

    return {
      'openDebtsCount': openDebts.length,
      'paidDebtsCount': paidDebts.length,
      'totalDebtsCount': _debts.length,
      'totalOpenAmount': openTotal,
      'totalPaidAmount': paidTotal,
    };
  }

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
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'debt_operation']) {
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

  @override
  void dispose() {
    _fetchShieldTimer?.cancel();
    super.dispose();
  }

  void setStoreId(String? storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      if (storeId != null && storeId.isNotEmpty) {
        fetchInitialDebts();
      } else {
        _debts = [];
        _debtMap = {};
        _status = DebtProviderStatus.idle;
        safeNotify();
      }
    }
  }

  void updateAuthState(AuthProvider auth) {
    _authProvider = auth;
    setStoreId(auth.currentStoreId);
  }

  void setDebtType(DebtType type) {
    if (_currentDebtType != type) {
      _currentDebtType = type;
      _debts = [];
      _lastDocument = null;
      _hasMore = true;
      fetchInitialDebts();
    }
  }

  void setFilter(String filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      _debts = [];
      _lastDocument = null;
      _hasMore = true;
      fetchInitialDebts();
    }
  }

  Future<void> fetchInitialDebts({bool forceRefresh = false}) async {
    if (_currentStoreId == null) return;
    if (!forceRefresh && _fetchShieldActive) return;

    _updateStatus(DebtProviderStatus.loading);
    _errorMessage = null;
    safeNotify();

    try {
      final result = await _debtRepository.getDebtsByDateRange(
        _currentStoreId!,
        DateTime(2020),
        DateTime(2100),
        lastDocument: null,
        debtType: _currentDebtType.name,
        debtStatus: _currentFilter == 'all' ? null : _currentFilter,
      );

      // Smart Merge: match incoming documents by UUID, preserving locally pending modifications/items
      final Map<String, DebtModel> merged = {};
      final incomingIds = result.items.map((d) => d.debtId).toSet();
      for (final d in result.items) {
        merged[d.debtId] = d;
      }
      for (final d in _debts) {
        if (_pendingDebtIds.contains(d.debtId)) {
          merged[d.debtId] = d;
        }
      }

      final List<DebtModel> mergedList = [];
      for (final d in result.items) {
        if (_pendingDebtIds.contains(d.debtId)) {
          mergedList.add(merged[d.debtId]!);
        } else {
          mergedList.add(d);
        }
      }
      for (final d in _debts) {
        if (_pendingDebtIds.contains(d.debtId) &&
            !incomingIds.contains(d.debtId)) {
          // Prepend newly created pending items
          mergedList.insert(0, d);
        }
      }

      _debts = mergedList;
      _lastDocument = result.lastDocument;
      _hasMore = result.items.length >= 20;

      _rebuildDebtMap();
      _updateStatus(DebtProviderStatus.loaded);
    } catch (e, stack) {
      if (e is ServerException && e.code == 'permission-denied') {
        if (kDebugMode)
          debugPrint(
              '🤫 [SILENT ERROR] DebtProvider: permission-denied (likely native sign-out)');
        return;
      }
      setError('debt_error_fetch_failed', e, stack);
    } finally {
      safeNotify();
    }
  }

  Future<void> fetchMoreDebts() async {
    if (isLoading ||
        isLoadingMore ||
        !_hasMore ||
        _currentStoreId == null ||
        _lastDocument == null) {
      return;
    }

    _updateStatus(DebtProviderStatus.loadingMore);
    safeNotify();

    try {
      final result = await _debtRepository.getDebtsByDateRange(
        _currentStoreId!,
        DateTime(2020),
        DateTime(2100),
        lastDocument: _lastDocument,
        debtType: _currentDebtType.name,
        debtStatus: _currentFilter == 'all' ? null : _currentFilter,
      );

      if (result.items.isEmpty) {
        _hasMore = false;
      } else {
        _debts.addAll(result.items);
        _lastDocument = result.lastDocument;
        _hasMore = result.items.length >= 20;
      }

      _rebuildDebtMap();
      _updateStatus(DebtProviderStatus.loaded);
    } catch (e, stack) {
      setError('debt_error_fetch_more_failed', e, stack);
    } finally {
      safeNotify();
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

    List<DebtModel>? oldDebts;
    Map<String, DebtModel>? oldDebtMap;
    StatsSummaryModel? oldStatsSummary;
    DailyStatsModel? oldStatsToday;
    StatisticsProvider? statsProvider;
    String? pendingDebtId;

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
        // Capture snapshot
        oldDebts = _debts.toList();
        oldDebtMap = Map<String, DebtModel>.from(_debtMap);

        try {
          statsProvider = sl<StatisticsProvider>();
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'STATS_PROVIDER_RESOLVE_ERROR: $e | typeHash=${(StatisticsProvider).hashCode}');
          }
          statsProvider = null;
        }
        if (statsProvider != null) {
          oldStatsSummary = statsProvider.dashboardSummary;
          oldStatsToday = statsProvider.todayStats;
        }

        final newDebtId = const Uuid().v4();
        pendingDebtId = newDebtId;
        _pendingDebtIds.add(pendingDebtId);

        final newDebt = DebtModel(
          debtId: newDebtId,
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

        // Optimistically insert locally first
        _debts.insert(0, newDebt);
        _rebuildDebtMap();
        notifyListeners();

        if (statsProvider != null) {
          statsProvider.addDebtOptimistically(amount: amountDue);
        }

        try {
          await _debtRepository.createDebt(newDebt);
        } catch (e, stack) {
          _rollbackLocalDebt(oldDebts, oldDebtMap, statsProvider,
              oldStatsSummary, oldStatsToday);
          AppErrorHandler.handle(e,
              severity: ErrorSeverity.medium,
              operation: 'debt_create',
              stackTrace: stack);
          return false;
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

      _activateFetchShield();
      _updateStatus(DebtProviderStatus.loaded); // Reset status
      return true;
    } on AppException catch (e, stack) {
      _rollbackLocalDebt(
          oldDebts, oldDebtMap, statsProvider, oldStatsSummary, oldStatsToday);
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      _rollbackLocalDebt(
          oldDebts, oldDebtMap, statsProvider, oldStatsSummary, oldStatsToday);
      setError('debt_error_create_failed', e, stack);
      return false;
    } finally {
      if (pendingDebtId != null) {
        _pendingDebtIds.remove(pendingDebtId);
      }
      if (_status == DebtProviderStatus.creating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> addPartialDebt(
      String debtId, double amountToAdd, String userId) async {
    List<DebtModel>? oldDebts;
    Map<String, DebtModel>? oldDebtMap;
    StatsSummaryModel? oldStatsSummary;
    DailyStatsModel? oldStatsToday;
    StatisticsProvider? statsProvider;

    try {
      await _validateUserAndPermission((p) => p.createDebt);

      _status = DebtProviderStatus.updating;
      _errorMessage = null;
      safeNotify();

      // Capture snapshot
      oldDebts = _debts.toList();
      oldDebtMap = Map<String, DebtModel>.from(_debtMap);
      _pendingDebtIds.add(debtId);

      try {
        statsProvider = sl<StatisticsProvider>();
      } catch (_) {
        statsProvider = null;
      }
      if (statsProvider != null) {
        oldStatsSummary = statsProvider.dashboardSummary;
        oldStatsToday = statsProvider.todayStats;
      }

      // Mutate locally
      final index = _debts.indexWhere((d) => d.debtId == debtId);
      if (index == -1) {
        throw ValidationException('debt_error_not_found');
      }
      final oldDebt = _debts[index];
      final newDebt = oldDebt.copyWith(
        amountDue: oldDebt.amountDue + amountToAdd,
        totalAmount: oldDebt.totalAmount + amountToAdd,
        updatedAt: DateTime.now(),
        lastUpdatedBy: userId,
      );

      _debts = [
        for (int i = 0; i < _debts.length; i++)
          if (i == index) newDebt else _debts[i],
      ];
      _rebuildDebtMap();

      if (statsProvider != null) {
        statsProvider.addDebtOptimistically(amount: amountToAdd);
      }

      safeNotify();

      try {
        await _debtRepository.addPartialDebt(debtId, amountToAdd, userId);
      } catch (e, stack) {
        _rollbackLocalDebt(oldDebts, oldDebtMap, statsProvider, oldStatsSummary,
            oldStatsToday);
        AppErrorHandler.handle(e,
            stackTrace: stack, operation: 'DebtProvider.addPartialDebt');
        return false;
      }

      _activateFetchShield();
      _updateStatus(DebtProviderStatus.loaded);
      return true;
    } on AppException catch (e, stack) {
      _rollbackLocalDebt(
          oldDebts, oldDebtMap, statsProvider, oldStatsSummary, oldStatsToday);
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      _rollbackLocalDebt(
          oldDebts, oldDebtMap, statsProvider, oldStatsSummary, oldStatsToday);
      setError('debt_error_add_amount_failed', e, stack);
      return false;
    } finally {
      _pendingDebtIds.remove(debtId);
      if (_status == DebtProviderStatus.updating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> updateDebt(String debtId, Map<String, dynamic> data) async {
    List<DebtModel>? oldDebts;
    Map<String, DebtModel>? oldDebtMap;

    try {
      await _validateUserAndPermission((p) => p.createDebt);

      _status = DebtProviderStatus.updating;
      _errorMessage = null;
      safeNotify();

      // Capture snapshot
      oldDebts = _debts.toList();
      oldDebtMap = Map<String, DebtModel>.from(_debtMap);
      _pendingDebtIds.add(debtId);

      // Mutate locally
      final index = _debts.indexWhere((d) => d.debtId == debtId);
      if (index == -1) {
        throw ValidationException('debt_error_not_found');
      }
      final oldDebt = _debts[index];
      final newDebt = oldDebt.copyWith(
        customerName: data['customerName'] as String?,
        customerPhone: data['customerPhone'] as String?,
        debtType: data['debtType'] != null
            ? DebtType.fromString(data['debtType'] as String)
            : null,
        amountDue: data['amountDue'] != null
            ? NumberParser.toDouble(data['amountDue'])
            : null,
        totalAmount: data['totalAmount'] != null
            ? NumberParser.toDouble(data['totalAmount'])
            : null,
        notes: data.containsKey('notes') ? data['notes'] as String? : null,
        debtStatus: data['debtStatus'] != null
            ? DebtStatus.fromString(data['debtStatus'] as String)
            : null,
        updatedAt: DateTime.now(),
      );

      _debts = [
        for (int i = 0; i < _debts.length; i++)
          if (i == index) newDebt else _debts[i],
      ];
      _rebuildDebtMap();
      safeNotify();

      try {
        await _debtRepository.updateDebt(debtId, data);
      } catch (e, stack) {
        _rollbackLocalDebt(oldDebts, oldDebtMap, null, null, null);
        AppErrorHandler.handle(e,
            stackTrace: stack, operation: 'DebtProvider.updateDebt');
        return false;
      }

      _activateFetchShield();
      _updateStatus(DebtProviderStatus.loaded);
      return true;
    } on ServerException catch (e, stack) {
      _rollbackLocalDebt(oldDebts, oldDebtMap, null, null, null);
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      _rollbackLocalDebt(oldDebts, oldDebtMap, null, null, null);
      setError('debt_error_update_failed', e, stack);
      return false;
    } finally {
      _pendingDebtIds.remove(debtId);
      if (_status == DebtProviderStatus.updating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> payPartialDebt(
      String debtId, double amountToPay, String userId) async {
    List<DebtModel>? oldDebts;
    Map<String, DebtModel>? oldDebtMap;
    StatsSummaryModel? oldStatsSummary;
    DailyStatsModel? oldStatsToday;
    StatisticsProvider? statsProvider;

    try {
      await _validateUserAndPermission((p) => p.collectDebt);

      _status = DebtProviderStatus.updating;
      _errorMessage = null;
      safeNotify();

      // Capture snapshot
      oldDebts = _debts.toList();
      oldDebtMap = Map<String, DebtModel>.from(_debtMap);
      _pendingDebtIds.add(debtId);

      try {
        statsProvider = sl<StatisticsProvider>();
      } catch (_) {
        statsProvider = null;
      }
      if (statsProvider != null) {
        oldStatsSummary = statsProvider.dashboardSummary;
        oldStatsToday = statsProvider.todayStats;
      }

      // Mutate locally
      final index = _debts.indexWhere((d) => d.debtId == debtId);
      if (index == -1) {
        throw ValidationException('debt_error_not_found');
      }
      final oldDebt = _debts[index];

      if (amountToPay > oldDebt.amountDue) {
        throw ValidationException('debt_error_amount_exceeded');
      }

      final isFullPayment = (oldDebt.amountDue - amountToPay).abs() < 0.01;
      final newDebt = oldDebt.copyWith(
        amountDue: isFullPayment ? 0.0 : oldDebt.amountDue - amountToPay,
        debtStatus: isFullPayment ? DebtStatus.paid : oldDebt.debtStatus,
        paidDate: isFullPayment ? DateTime.now() : oldDebt.paidDate,
        markedPaidBy: isFullPayment ? userId : oldDebt.markedPaidBy,
        updatedAt: DateTime.now(),
        lastUpdatedBy: userId,
      );

      // Instantly filter out if current filter is 'open' and it is full payment
      if (_currentFilter == 'open' && isFullPayment) {
        _debts = _debts.where((d) => d.debtId != debtId).toList();
      } else if (_currentFilter == 'paid' && !isFullPayment) {
        _debts = _debts.where((d) => d.debtId != debtId).toList();
      } else {
        _debts = [
          for (int i = 0; i < _debts.length; i++)
            if (i == index) newDebt else _debts[i],
        ];
      }

      _rebuildDebtMap();

      if (statsProvider != null) {
        if (isFullPayment) {
          statsProvider.settleDebtOptimistically(amount: oldDebt.amountDue);
        } else {
          statsProvider.payPartialDebtOptimistically(amount: amountToPay);
        }
      }

      safeNotify();

      try {
        await _debtRepository.processPayment(debtId, amountToPay, userId);
      } catch (e, stack) {
        _rollbackLocalDebt(oldDebts, oldDebtMap, statsProvider, oldStatsSummary,
            oldStatsToday);
        AppErrorHandler.handle(e,
            stackTrace: stack, operation: 'DebtProvider.payPartialDebt');
        return false;
      }

      _activateFetchShield();
      _updateStatus(DebtProviderStatus.loaded);
      return true;
    } on AppException catch (e, stack) {
      _rollbackLocalDebt(
          oldDebts, oldDebtMap, statsProvider, oldStatsSummary, oldStatsToday);
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      _rollbackLocalDebt(
          oldDebts, oldDebtMap, statsProvider, oldStatsSummary, oldStatsToday);
      setError('debt_error_settle_failed', e, stack);
      return false;
    } finally {
      _pendingDebtIds.remove(debtId);
      if (_status == DebtProviderStatus.updating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> deleteDebt(String debtId) async {
    List<DebtModel>? oldDebts;
    Map<String, DebtModel>? oldDebtMap;

    try {
      await _validateUserAndPermission((p) => p.deleteDebt);

      _status = DebtProviderStatus.updating;
      _errorMessage = null;
      safeNotify();

      // Capture snapshot
      oldDebts = _debts.toList();
      oldDebtMap = Map<String, DebtModel>.from(_debtMap);
      _pendingDebtIds.add(debtId);

      // Mutate locally
      _debts = _debts.where((d) => d.debtId != debtId).toList();
      _rebuildDebtMap();
      safeNotify();

      try {
        await _debtRepository.deleteDebt(debtId);
      } catch (e, stack) {
        _rollbackLocalDebt(oldDebts, oldDebtMap, null, null, null);
        AppErrorHandler.handle(e,
            stackTrace: stack, operation: 'DebtProvider.deleteDebt');
        return false;
      }

      _activateFetchShield();
      _updateStatus(DebtProviderStatus.loaded);
      return true;
    } on ServerException catch (e, stack) {
      _rollbackLocalDebt(oldDebts, oldDebtMap, null, null, null);
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      _rollbackLocalDebt(oldDebts, oldDebtMap, null, null, null);
      setError('debt_error_delete_failed', e, stack);
      return false;
    } finally {
      _pendingDebtIds.remove(debtId);
      if (_status == DebtProviderStatus.updating) {
        _updateStatus(DebtProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  void _rollbackLocalDebt(
    List<DebtModel>? oldDebts,
    Map<String, DebtModel>? oldDebtMap,
    StatisticsProvider? statsProvider,
    StatsSummaryModel? oldStatsSummary,
    DailyStatsModel? oldStatsToday,
  ) {
    if (oldDebts != null) _debts = oldDebts;
    if (oldDebtMap != null) _debtMap = oldDebtMap;
    if (statsProvider != null) {
      statsProvider.rollbackStats(oldStatsSummary, oldStatsToday);
    }
    _rebuildDebtMap();
    safeNotify();
  }

  void clearAndCancel() {
    _currentStoreId = null;
    _debts = [];
    _debtMap = {};
    _hasMore = true;
    _lastDocument = null;
    _status = DebtProviderStatus.idle;
    _errorMessage = null;
    safeNotify();
  }

  Future<UserModel> _validateUserAndPermission(
      bool Function(UserPermissions) permissionCheck) async {
    final user = _authProvider.currentUser;
    if (user == null) throw AuthException('debt_error_auth_required');

    // Owners have all permissions
    if (user.isOwner) return user;

    if (user.permissions == null || !permissionCheck(user.permissions!)) {
      throw PermissionException();
    }
    return user;
  }
}
