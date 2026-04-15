import 'package:firebase_performance/firebase_performance.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/providers/app_events.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/models/wallet_model.dart';
import '../core/errors/app_exceptions.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'auth_provider.dart';
import 'subscription_provider.dart'; // Added import
import 'package:walletmanager/data/services/local_storage_service.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';

enum WalletStatusState {
  idle,
  loading,
  loadingMore,
  loaded,
  error,
  creating,
  updating,
  deleting,
}

class WalletProvider extends ChangeNotifier {
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;

  // State
  String? _currentStoreId;

  final AuthProvider _authProvider; // Made final and non-nullable
  SubscriptionProvider? _subscriptionProvider;
  List<WalletModel> _wallets = [];
  Map<String, WalletModel> _walletMap = {};
  final Set<String> _frozenWalletIds = {};
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _fetchShieldActive = false;
  Timer? _fetchShieldTimer;

  void _activateFetchShield() {
    _fetchShieldActive = true;
    _fetchShieldTimer?.cancel();
    _fetchShieldTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed) _fetchShieldActive = false;
    });
  }

  // Status
  WalletStatusState _status = WalletStatusState.idle;
  String? _errorMessage;

  // Filters
  String _searchQuery = '';
  String? _filterByType;
  String? _filterByStatus;

  // Cache
  List<WalletModel>? _cachedWallets;
  DateTime? _cacheTimestamp;

  StreamSubscription? _dataChangedSubscription;
  StreamSubscription? _overlayDataSubscription;
  bool _isDisposed = false;

  // Constructor
  WalletProvider({
    required AuthProvider authProvider, // Required authProvider
    SubscriptionProvider? subscriptionProvider,
    WalletRepository? walletRepository,
    TransactionRepository? transactionRepository,
    String? storeId,
  })  : _authProvider = authProvider,
        _subscriptionProvider = subscriptionProvider,
        _walletRepository = walletRepository ?? sl<WalletRepository>(),
        _transactionRepository =
            transactionRepository ?? sl<TransactionRepository>(),
        _currentStoreId = storeId {
    _dataChangedSubscription = appEvents.onWalletsChanged.listen((_) {
      // Intentionally NOT calling fetchInitialWallets() here.
      // The onWalletsChanged event fires after local mutations (create/delete/update).
      // A Firestore fetch at this point would race against the optimistic update
      // and could overwrite the correct local state with stale cached data.
      // The UI is already up-to-date via notifyListeners() in each mutating method.
      debugPrint('🔥 [wallet_provider] appEvents.onWalletsChanged — skipping fetch, UI already updated via notifyListeners.');
    });

    // Listen for overlay "refresh_wallets" pings (on-demand, no Firestore stream).
    // FlutterOverlayWindow.overlayListener is a SINGLE-subscription stream.
    // Cancel any prior subscription before re-listening to prevent
    // "Bad state: Stream has already been listened to" crashes.
    _overlayDataSubscription?.cancel();
    _overlayDataSubscription = null;
    try {
      _overlayDataSubscription =
          FlutterOverlayWindow.overlayListener.listen((event) {
        debugPrint('🔥 [TX_FLOW] [wallet_provider] -> overlayListener: '
            'event received=$event');

        if (event is Map && event['action'] == 'local_deduct') {
          // ── Zero-cost local state mutation ──
          // The overlay already wrote to Firestore; we just need to update RAM.
          final walletId = event['walletId']?.toString();
          final deduction = (event['amount'] as num?)?.toDouble() ?? 0.0;
          final isSend = event['isSend'] == true;

          if (walletId == null) return;

          final index = _wallets.indexWhere((w) => w.walletId == walletId);
          if (index != -1) {
            final oldWallet = _wallets[index];
            final newBalance = isSend
                ? oldWallet.balance - deduction
                : oldWallet.balance + deduction;

            // Build new list with updated wallet (forces deep reference change)
            _wallets = [
              for (int i = 0; i < _wallets.length; i++)
                if (i == index)
                  oldWallet.copyWith(balance: newBalance)
                else
                  _wallets[i],
            ];
            _rebuildWalletMap();
            _activateFetchShield();
            _safeNotify();
            debugPrint('🔥 [TX_FLOW] [wallet_provider] -> overlayListener: '
                'local_deduct applied! walletId=$walletId, '
                'oldBalance=${oldWallet.balance}, newBalance=$newBalance, '
                'isSend=$isSend. No Firebase read needed!');
          } else {
            // walletId not found in RAM — wallet list may not be loaded yet.
            // Do NOT fetch from Firestore here; a stale fetch would overwrite
            // any other pending optimistic mutations. The next natural screen
            // load / pull-to-refresh will reconcile the server state.
            debugPrint('🔥 [TX_FLOW] [wallet_provider] -> overlayListener: '
                'walletId=$walletId NOT found in _wallets — skipping fetch to '
                'prevent stale overwrite. Will reconcile on next screen load.');
          }
        } else if (event is Map && event['action'] == 'refresh_wallets') {
          // Legacy event: previously triggered a full Firestore re-fetch.
          // Nuclear fix: NEVER fetch here — just notify so the UI can react
          // to whatever is already in RAM.
          debugPrint('🔥 [TX_FLOW] [wallet_provider] -> overlayListener: '
              'refresh_wallets received — NO Firestore fetch (stale-overwrite prevention). '
              'Calling notifyListeners() only.');
          _safeNotify();
        }
      });
    } catch (_) {
      // Gracefully ignore if the stream was already listened to by another
      // instance (e.g. during hot reload). The appEvents path still works.
    }
  }

  // ── Public API for optimistic local balance mutation ──
  // Called by GlobalOverlayListener (IsolateNameServer path) and
  // overlayListener (FlutterOverlayWindow path) to avoid any Firestore reads.
  void applyLocalDeduction(String walletId, double deduction, bool isSend) {
    if (_isDisposed) return;

    // Lock Firestore fetches for 5 seconds to prevent stale SDK cache 
    // from overwriting this beautiful local mutation!
    _activateFetchShield();


    final index = _wallets.indexWhere((w) => w.walletId == walletId);
    if (index == -1) {
      debugPrint('🔥 [TX_FLOW] LOCAL MUTATION: walletId=$walletId not in RAM — skipping.');
      return;
    }

    final oldWallet = _wallets[index];
    final newBalance =
        isSend ? oldWallet.balance - deduction : oldWallet.balance + deduction;

    _wallets = [
      for (int i = 0; i < _wallets.length; i++)
        if (i == index) oldWallet.copyWith(balance: newBalance) else _wallets[i],
    ];
    _rebuildWalletMap();
    _safeNotify();
    debugPrint('🔥 [TX_FLOW] LOCAL MUTATION APPLIED! '
        'walletId=$walletId | oldBalance=${oldWallet.balance} → New Balance: $newBalance | '
        'isSend=$isSend | No Firestore read.');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fetchShieldTimer?.cancel();
    _dataChangedSubscription?.cancel();
    _overlayDataSubscription?.cancel();
    super.dispose();
  }

  // Getters
  List<WalletModel> get wallets => _wallets;
  Map<String, WalletModel> get walletMap => _walletMap;
  WalletStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentStoreId => _currentStoreId;
  String get searchQuery => _searchQuery;
  String? get filterByType => _filterByType;
  String? get filterByStatus => _filterByStatus;
  bool get hasMore => _hasMore;

  // Helper Getters
  bool get isLoading => _status == WalletStatusState.loading;
  bool get isLoadingMore => _status == WalletStatusState.loadingMore;
  bool get isCreating => _status == WalletStatusState.creating;
  bool get isUpdating => _status == WalletStatusState.updating;
  bool get isDeleting => _status == WalletStatusState.deleting;
  bool get hasError => _status == WalletStatusState.error;

  // Methods

  void updateAuthState(AuthProvider auth) {
    // _authProvider is final, we don't reassign it.
    if (_currentStoreId != auth.currentStoreId) {
      setStoreId(auth.currentStoreId ?? '');
    }
  }

  void updateSubscriptionProvider(SubscriptionProvider subscriptionProvider) {
    _subscriptionProvider = subscriptionProvider;
  }

  /// Robust permission check that ensures user is loaded
  Future<UserModel> _validateUserAndPermission(
      bool Function(UserPermissions) selector) async {
    // 1. Attempt to load user with retry
    final user = await _authProvider.ensureUserLoaded();

    // 2. Verify User
    if (user == null) {
      throw AuthException(
          'فشلت عملية المصادقة، يرجى التأكد من اتصال الإنترنت أو تسجيل الدخول مجدداً');
    }

    // 3. Permission Guard
    if (user.isOwner) return user;

    if (!user.hasPermission(selector)) {
      throw PermissionException();
    }

    return user;
  }

  // Helper Check - Deprecated in favor of _validateUserAndPermission but kept for non-async if needed
  // void _checkPermission(bool Function(UserPermissions) selector) { ... }

  void setStoreId(String storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      _cachedWallets = null;
      _cacheTimestamp = null;
      fetchInitialWallets();
    }
  }

  Future<void> refresh() async {
    await fetchInitialWallets(forceRefresh: true);
  }

  Future<void> fetchInitialWallets({bool forceRefresh = false}) async {
    if (_fetchShieldActive) {
      debugPrint('🔥 [TX_FLOW] Fetch blocked to preserve local mutation!');
      return;
    }
    if (_currentStoreId == null) return;

    debugPrint('🔥 [TX_FLOW] [wallet_provider] -> fetchInitialWallets: '
        'ENTRY | storeId=$_currentStoreId, forceRefresh=$forceRefresh, '
        'hasCachedWallets=${_cachedWallets != null}');

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedWallets != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      debugPrint('🔥 [TX_FLOW] [wallet_provider] -> fetchInitialWallets: '
          'CACHE HIT — returning ${_cachedWallets!.length} cached wallets');
      _wallets = _cachedWallets!;
      if (status != WalletStatusState.loaded) {
        _updateStatus(WalletStatusState.loaded);
      }
      return;
    }
    debugPrint('🔥 [TX_FLOW] [wallet_provider] -> fetchInitialWallets: '
        'CACHE MISS or forceRefresh=true — fetching from Firestore ...');

    final trace = FirebasePerformance.instance
        .newTrace('fetch_initial_wallets_optimized');
    await trace.start();

    _updateStatus(WalletStatusState.loading);
    _lastDocument = null;
    _hasMore = true;

    try {
      // 1. Fetch only the first page of wallets
      final result = await _walletRepository.getWalletsByStoreIdPaginated(
        _currentStoreId!,
        limit: 15,
        walletType: _filterByType,
        walletStatus: _filterByStatus,
      );

      List<WalletModel> fetchedWallets = result['wallets'];
      _lastDocument = result['lastDoc'];
      _hasMore = fetchedWallets.length == 15;

      // 2. Check which of the fetched wallets need a reset
      final walletsNeedingReset = fetchedWallets
          .where((w) => w.needsDailyReset || w.needsMonthlyReset)
          .toList();

      if (walletsNeedingReset.isNotEmpty) {
        // 3. Trigger the backend update asynchronously (fire-and-forget)
        _walletRepository.resetLimitsForWallets(walletsNeedingReset);

        // 4. Update the in-memory models immediately for a responsive UI
        final now = Timestamp.now();
        fetchedWallets = fetchedWallets.map((wallet) {
          if (walletsNeedingReset.any((w) => w.walletId == wallet.walletId)) {
            var tempWallet = wallet;
            if (wallet.needsDailyReset) {
              tempWallet = tempWallet.copyWith(
                  sendLimits: wallet.sendLimits.copyWith(dailyUsed: 0),
                  receiveLimits: wallet.receiveLimits.copyWith(dailyUsed: 0),
                  lastDailyReset: now);
            }
            if (wallet.needsMonthlyReset) {
              tempWallet = tempWallet.copyWith(
                  sendLimits: tempWallet.sendLimits.copyWith(monthlyUsed: 0),
                  receiveLimits:
                      tempWallet.receiveLimits.copyWith(monthlyUsed: 0),
                  lastMonthlyReset: now);
            }
            return tempWallet;
          }
          return wallet;
        }).toList();
      }

      // CRITICAL: Assign a NEW list instance to break reference equality.
      // Flutter may skip rebuilds if _wallets points to the same List object.
      _wallets = List<WalletModel>.from(fetchedWallets);
      _cachedWallets = List<WalletModel>.from(fetchedWallets);
      _cacheTimestamp = DateTime.now();

      _rebuildWalletMap();

      debugPrint(
          '🔥 [TX_FLOW] [wallet_provider] -> fetchInitialWallets: Finished. Wallet count=${_wallets.length}');

      _updateStatus(WalletStatusState.loaded);

      // Cache the wallets locally for SMS Automation (Overlay & Settings)
      try {
        await LocalStorageService.instance.cacheWalletLiteList(_wallets);
      } catch (e, stack) {
        AppErrorHandler.handle(e,
            severity: ErrorSeverity.low,
            operation: 'wallet_cache_write',
            stackTrace: stack);
      }
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e, stack) {
      _setError('حدث خطأ غير متوقع أثناء جلب المحافظ.', e, stack);
    } finally {
      await trace.stop();
      if (_status == WalletStatusState.loading) {
        _updateStatus(WalletStatusState.loaded);
      }
      _safeNotify();
    }
  }

  Future<void> fetchMoreWallets() async {
    if (_fetchShieldActive) {
      debugPrint('🔥 [TX_FLOW] FetchBlocked: Preserving local mutation on load more.');
      return;
    }
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null) {
      return;
    }

    _updateStatus(WalletStatusState.loadingMore);

    try {
      final result = await _walletRepository.getWalletsByStoreIdPaginated(
        _currentStoreId!,
        limit: 15,
        lastDoc: _lastDocument,
        walletType: _filterByType,
        walletStatus: _filterByStatus,
      );

      final newWallets = result['wallets'] as List<WalletModel>;
      _lastDocument = result['lastDoc'];
      _hasMore = newWallets.length == 15;

      final walletsNeedingReset = newWallets
          .where((w) => w.needsDailyReset || w.needsMonthlyReset)
          .toList();

      if (walletsNeedingReset.isNotEmpty) {
        // Fire and forget the backend update
        _walletRepository.resetLimitsForWallets(walletsNeedingReset);

        // Update models in memory for immediate UI consistency
        final now = Timestamp.now();
        final updatedNewWallets = newWallets.map((wallet) {
          if (walletsNeedingReset.any((w) => w.walletId == wallet.walletId)) {
            var tempWallet = wallet;
            if (wallet.needsDailyReset) {
              tempWallet = tempWallet.copyWith(
                  sendLimits: wallet.sendLimits.copyWith(dailyUsed: 0),
                  receiveLimits: wallet.receiveLimits.copyWith(dailyUsed: 0),
                  lastDailyReset: now);
            }
            if (wallet.needsMonthlyReset) {
              tempWallet = tempWallet.copyWith(
                  sendLimits: tempWallet.sendLimits.copyWith(monthlyUsed: 0),
                  receiveLimits:
                      tempWallet.receiveLimits.copyWith(monthlyUsed: 0),
                  lastMonthlyReset: now);
            }
            return tempWallet;
          }
          return wallet;
        }).toList();

        _wallets = [..._wallets, ...updatedNewWallets];
      } else {
        _wallets = [..._wallets, ...newWallets];
      }

      _rebuildWalletMap();
      _updateStatus(WalletStatusState.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e, stack) {
      _setError('حدث خطأ غير متوقع أثناء جلب المزيد من المحافظ.', e, stack);
    } finally {
      if (_status == WalletStatusState.loadingMore) {
        _updateStatus(WalletStatusState.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> createWallet({
    required String phoneNumber,
    required String walletType,
    required String walletStatus,
    required double balance,
    String? notes,
    required String createdBy,
  }) async {
    _updateStatus(WalletStatusState.creating);
    try {
      await _validateUserAndPermission((p) => p.createWallet);

      if (_currentStoreId == null) {
        throw ValidationException('Store ID not found.');
      }

      if (_subscriptionProvider != null) {
        final currentCount =
            await _walletRepository.getWalletsCount(_currentStoreId!);
        if (!_subscriptionProvider!.canAddWallet(currentCount)) {
          _setError(
              'تم الوصول للحد الأقصى للمحافظ (${_subscriptionProvider!.maxWallets})');
          return false;
        }
      }

      final newWallet = WalletModel.fromWalletStatus(
        walletId: _walletRepository.generateId(),
        storeId: _currentStoreId!,
        phoneNumber: phoneNumber,
        walletType: walletType,
        walletStatus: walletStatus,
        balance: balance,
        notes: notes,
        createdBy: createdBy,
      );

      _wallets = [..._wallets, newWallet];
      _rebuildWalletMap();

      try {
        await _walletRepository.createWallet(newWallet);
        await LocalStorageService.instance.cacheWalletLiteList(_wallets);
        appEvents.fireWalletsChanged();
        _updateStatus(WalletStatusState.loaded);
        return true;
      } catch (e) {
        _wallets =
            _wallets.where((w) => w.walletId != newWallet.walletId).toList();
        _rebuildWalletMap();
        rethrow;
      }
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في إنشاء المحفظة.', e, stack);
      return false;
    } finally {
      if (_status == WalletStatusState.creating) {
        _updateStatus(WalletStatusState.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> updateWallet(String walletId, Map<String, dynamic> data) async {
    _updateStatus(WalletStatusState.updating);
    try {
      await _validateUserAndPermission((p) => p.editWallet);

      if (_currentStoreId == null) return false;

      // Check FIFO freeze
      if (await _isWalletFrozen(walletId)) {
        _setError('هذه المحفظة مجمدة بسبب تجاوز الحد المسموح في باقتك الحالية');
        return false;
      }

      final oldWallet = _walletMap[walletId];
      if (oldWallet == null) return false;

      final updatedMap = oldWallet.toFirestore()..addAll(data);
      // Wait, fromMap might also require docId since we mapped it from document, let's see how WalletModel is defined.
      // Usually fromMap only takes the map, but wait, fromWalletStatus is another factory.
      // Let's use copyWith if possible, but map update is dynamic. Let's just use fromMap.
      final optimisticWallet = WalletModel.fromMap(updatedMap, walletId);

      _wallets = [
        for (final w in _wallets)
          if (w.walletId == walletId) optimisticWallet else w
      ];
      _rebuildWalletMap();

      try {
        await _walletRepository.updateWallet(walletId, data);
        await LocalStorageService.instance.cacheWalletLiteList(_wallets);
        appEvents.fireWalletsChanged();
        _updateStatus(WalletStatusState.loaded);
        return true;
      } catch (e) {
        _wallets = [
          for (final w in _wallets) if (w.walletId == walletId) oldWallet else w
        ];
        _rebuildWalletMap();
        rethrow;
      }
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في تحديث المحفظة.', e, stack);
      return false;
    } finally {
      if (_status == WalletStatusState.updating) {
        _updateStatus(WalletStatusState.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> addBalanceToWallet(
      String walletId, double amount, String createdBy) async {
    _updateStatus(WalletStatusState.updating);
    try {
      await _validateUserAndPermission((p) => p.addBalance);

      if (amount <= 0) throw ValidationException('Amount must be positive.');
      if (_currentStoreId == null) {
        throw ValidationException('Store ID not found.');
      }

      // Check FIFO freeze
      if (await _isWalletFrozen(walletId)) {
        throw ValidationException(
            'هذه المحفظة مجمدة بسبب تجاوز الحد المسموح في باقتك الحالية');
      }

      final newTransaction = TransactionModel(
        transactionId: _transactionRepository.generateId(),
        storeId: _currentStoreId!,
        walletId: walletId,
        transactionType: 'deposit',
        amount: amount,
        transactionDate: Timestamp.now(),
        createdAt: Timestamp.now(),
        createdBy: createdBy,
      );

      final wallet = _walletMap[walletId];
      if (wallet == null) throw ValidationException('Wallet not found');
      final oldBalance = wallet.balance;
      final newBalance = oldBalance + amount;

      _wallets = [
        for (final w in _wallets)
          if (w.walletId == walletId) w.copyWith(balance: newBalance) else w
      ];
      _rebuildWalletMap();

      try {
        await _transactionRepository.createTransaction(newTransaction);
        await LocalStorageService.instance.cacheWalletLiteList(_wallets);
        appEvents.fireWalletsChanged();
        appEvents.fireTransactionsChanged();
        _updateStatus(WalletStatusState.loaded);
        return true;
      } catch (e) {
        _wallets = [
          for (final w in _wallets)
            if (w.walletId == walletId) w.copyWith(balance: oldBalance) else w
        ];
        _rebuildWalletMap();
        rethrow;
      }
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في تحديث الرصيد.', e, stack);
      return false;
    } finally {
      if (_status == WalletStatusState.updating) {
        _updateStatus(WalletStatusState.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> deleteWallet(String walletId) async {
    _updateStatus(WalletStatusState.deleting);
    try {
      await _validateUserAndPermission((p) => p.editWallet);

      final index = _wallets.indexWhere((w) => w.walletId == walletId);
      if (index == -1) return false;
      final removedWallet = _wallets[index];

      _wallets = [
        for (int i = 0; i < _wallets.length; i++)
          if (i != index) _wallets[i]
      ];
      _rebuildWalletMap();

      try {
        await _walletRepository.deleteWallet(walletId);
        await LocalStorageService.instance.cacheWalletLiteList(_wallets);
        appEvents.fireWalletsChanged();
        _updateStatus(WalletStatusState.loaded);
        return true;
      } catch (e, stack) {
        final newWallets = List<WalletModel>.from(_wallets);
        newWallets.insert(index, removedWallet);
        _wallets = newWallets;
        _rebuildWalletMap();
        AppErrorHandler.handle(e,
            severity: ErrorSeverity.medium,
            operation: 'delete_wallet_cache',
            stackTrace: stack);
        rethrow;
      }
    } on FirebaseException catch (e) {
      _setError(e.message ?? 'فشل في حذف المحفظة.', e);
      return false;
    } catch (e, stack) {
      _setError('فشل في حذف المحفظة.', e, stack);
      return false;
    } finally {
      if (_status == WalletStatusState.deleting) {
        _updateStatus(WalletStatusState.loaded);
      }
      _safeNotify();
    }
  }

  // Note: Filters will now require re-fetching data.
  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchInitialWallets();
  }

  void setTypeFilter(String? type) {
    _filterByType = type;
    fetchInitialWallets();
  }

  void setStatusFilter(String? status) {
    _filterByStatus = status;
    fetchInitialWallets();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterByType = null;
    _filterByStatus = null;
    fetchInitialWallets();
  }

  // Helper Methods
  void _updateStatus(WalletStatusState status) {
    if (_isDisposed) return;
    _status = status;
  }

  void _setError(String message, [Object? error, StackTrace? stack]) {
    if (_isDisposed) return;
    _errorMessage = message;
    _status = WalletStatusState.error;
    AppErrorHandler.handle(error ?? message,
        severity: ErrorSeverity.medium,
        operation: 'wallet_operation',
        stackTrace: stack);
    // Note: notifyListeners() is now handled by the calling method's finally block
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    _status = WalletStatusState.idle;
    _safeNotify();
  }

  void updateWalletOptimistically(Map<String, dynamic> data) {
    // Expected data: {'walletId': String, 'amount': double, 'type': String ('credit' or 'debit')}
    if (data['walletId'] == null ||
        data['amount'] == null ||
        data['type'] == null) {
      return;
    }

    final walletId = data['walletId'] as String;
    final amount = (data['amount'] as num).toDouble();
    final type = data['type']
        as String; // SMS type: 'credit' (Receive) or 'debit' (Send)

    final index = _wallets.indexWhere((w) => w.walletId == walletId);
    if (index == -1) return;

    final wallet = _wallets[index];
    double newBalance = wallet.balance;

    // Map SMS Type to action
    // credit = money received -> increase balance
    // debit = money sent -> decrease balance
    if (type == 'credit') {
      newBalance += amount;
    } else if (type == 'debit') {
      newBalance -= amount;
    }

    _wallets = [
      for (int i = 0; i < _wallets.length; i++)
        if (i == index) wallet.copyWith(balance: newBalance) else _wallets[i],
    ];
    _rebuildWalletMap();
    _activateFetchShield();
    _safeNotify();
  }

  void _rebuildWalletMap() {
    _walletMap = {
      for (final wallet in _wallets) wallet.walletId: wallet,
    };
    _recalculateFrozenWallets();
  }

  void _recalculateFrozenWallets() {
    _frozenWalletIds.clear();
    if (_subscriptionProvider == null || _currentStoreId == null) return;
    final maxWallets = _subscriptionProvider!.maxWallets;
    if (_wallets.length <= maxWallets) return;

    final sortedWallets = List<WalletModel>.from(_wallets);
    sortedWallets.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (int i = maxWallets; i < sortedWallets.length; i++) {
      _frozenWalletIds.add(sortedWallets[i].walletId);
    }
  }

  Future<bool> _isWalletFrozen(String walletId) async {
    return _frozenWalletIds.contains(walletId);
  }

  // Synchronous check for UI bindings based on local RAM loaded items
  bool isWalletFrozenSync(String walletId) {
    return _frozenWalletIds.contains(walletId);
  }
}
