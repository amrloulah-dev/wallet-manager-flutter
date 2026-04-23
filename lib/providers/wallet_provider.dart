import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
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
import '../core/utils/number_parser.dart';

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

  // Status
  WalletStatusState _status = WalletStatusState.idle;
  String? _errorMessage;

  // Filters
  String _searchQuery = '';
  String? _filterByType;
  String? _filterByStatus;

  StreamSubscription? _overlayDataSubscription;
  bool _isDisposed = false;

  Timer? _fetchShieldTimer;
  bool _fetchShieldActive = false;

  void _activateFetchShield() {
    _fetchShieldActive = true;
    _fetchShieldTimer?.cancel();
    _fetchShieldTimer = Timer(const Duration(seconds: 5), () {
      _fetchShieldActive = false;
    });
  }


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
    // ── Streams-Driven Sync (Phase 1) ──
    // Manual AppEvents listener removed. Data sync is now handled by _walletsSubscription
    // established in fetchInitialWallets().

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
          final deduction = NumberParser.toDouble(event['amount']);
          final isSend = event['isSend'] == true;

          if (walletId == null) return;

          final index = _wallets.indexWhere((w) => w.walletId == walletId);
          if (index != -1) {
            final oldWallet = _wallets[index];
            final newBalance = isSend
                ? oldWallet.balance - deduction
                : oldWallet.balance + deduction;

            // In-place update for performance (Phase 3)
            _wallets[index] = oldWallet.copyWith(balance: newBalance);
            _rebuildWalletMap();
            _safeNotify();
            debugPrint('🔥 [TX_FLOW] [wallet_provider] -> overlayListener: '
                'local_deduct applied! walletId=$walletId, '
                'oldBalance=${oldWallet.balance}, newBalance=$newBalance, '
                'isSend=$isSend. No Firebase read needed!');
          }
        }
      });
    } catch (_) {
    }
  }

  // ── Public API for optimistic local balance mutation ──
  // Called by GlobalOverlayListener (IsolateNameServer path) and
  // overlayListener (FlutterOverlayWindow path) to avoid any Firestore reads.
  void applyLocalDeduction(String walletId, double deduction, bool isSend) {
    if (_isDisposed) return;

    final index = _wallets.indexWhere((w) => w.walletId == walletId);
    if (index == -1) {
      debugPrint('🔥 [TX_FLOW] LOCAL MUTATION: walletId=$walletId not in RAM — skipping.');
      return;
    }

    final oldWallet = _wallets[index];
    final newBalance =
        isSend ? oldWallet.balance - deduction : oldWallet.balance + deduction;

    // In-place update for performance (Phase 3)
    _wallets[index] = oldWallet.copyWith(balance: newBalance);
    _rebuildWalletMap();
    _safeNotify();
    debugPrint('🔥 [TX_FLOW] LOCAL MUTATION APPLIED! '
        'walletId=$walletId | oldBalance=${oldWallet.balance} → New Balance: $newBalance | '
        'isSend=$isSend | No Firestore read.');
  }

  @override
  void dispose() {
    _isDisposed = true;
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
          'auth_error_session_expired');
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
      fetchInitialWallets();
    }
  }

  Future<void> refresh() async {
    fetchInitialWallets(forceRefresh: true);
  }

  Future<void> fetchInitialWallets({bool forceRefresh = false}) async {
    debugPrint('🚀 [INIT START] WalletProvider: fetchInitialWallets(forceRefresh: $forceRefresh)');
    if (_currentStoreId == null) {
      debugPrint('⚠️ [INIT ABORT] WalletProvider: No currentStoreId');
      return;
    }
    if (!forceRefresh && _fetchShieldActive) {
      debugPrint('🛡️ [INIT SHIELD] WalletProvider: Fetch shield active, skipping.');
      return;
    }

    _updateStatus(WalletStatusState.loading);
    _errorMessage = null;
    _safeNotify();

    try {
      debugPrint('⏳ [INIT DATA] WalletProvider: Requesting wallets from repository...');
      final result = await _walletRepository.getAllWallets(
        _currentStoreId!,
      );
      debugPrint('✅ [INIT SUCCESS] WalletProvider: Fetched ${result.items.length} wallets.');

      _wallets = result.items;
      _lastDocument = result.lastDocument;
      _hasMore = result.items.length >= 20;

      // Check which of the fetched wallets need a reset
      final walletsNeedingReset = _wallets
          .where((w) => w.needsDailyReset || w.needsMonthlyReset)
          .toList();

      if (walletsNeedingReset.isNotEmpty) {
        debugPrint('🔄 [INIT DATA] WalletProvider: Resetting limits for ${walletsNeedingReset.length} wallets.');
        // Trigger the backend update asynchronously
        _walletRepository.resetLimitsForWallets(walletsNeedingReset);
      }

      _rebuildWalletMap();
      _updateStatus(WalletStatusState.loaded);

      // Cache the wallets locally for SMS Automation
      try {
        await LocalStorageService.instance.cacheWalletLiteList(_wallets);
      } catch (e, stack) {
        debugPrint('⚠️ [INIT ERROR] WalletProvider: Cache write failed: $e');
        AppErrorHandler.handle(e,
            severity: ErrorSeverity.low,
            operation: 'wallet_cache_write',
            stackTrace: stack);
      }
    } catch (e, stack) {
      debugPrint('❌ [INIT FATAL] WalletProvider Error: $e');
      debugPrint('🔍 [STACK TRACE]: $stack');
      _setError('wallet_error_fetch_failed', e, stack);
    } finally {
      _safeNotify();
    }
  }

  Future<void> fetchMoreWallets() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null || _lastDocument == null) {
      return;
    }

    _updateStatus(WalletStatusState.loadingMore);
    _safeNotify();

    try {
      final result = await _walletRepository.getAllWallets(
        _currentStoreId!,
        lastDocument: _lastDocument,
      );

      if (result.items.isEmpty) {
        _hasMore = false;
      } else {
        _wallets.addAll(result.items);
        _lastDocument = result.lastDocument;
        _hasMore = result.items.length >= 20;
      }

      _rebuildWalletMap();
      _updateStatus(WalletStatusState.loaded);
    } catch (e, stack) {
      _setError('wallet_error_fetch_more_failed', e, stack);
    } finally {
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

      // Bug B-002: Fail-closed if subscription provider is missing
      if (_subscriptionProvider == null) {
        _setError('wallet_error_subscription_unresolved');
        return false;
      }

      final currentCount =
          await _walletRepository.getWalletsCount(_currentStoreId!);
      if (!_subscriptionProvider!.canAddWallet(currentCount)) {
        _setError('wallet_error_limit_reached');
        return false;
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

      // Optimistic update removed because the stream will push the new wallet
      // as soon as it's written to Firestore. However, for a better UX,
      // we can keep it if we want immediate feedback before Firestore sync.
      // But the instructions say "rely on stream listeners". 
      // Let's keep it for now as it doesn't hurt and prevents "flicker".

      try {
        await _walletRepository.createWallet(newWallet);
        _updateStatus(WalletStatusState.loaded);
        return true;
      } catch (e) {
        rethrow;
      }
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('wallet_error_create_failed', e, stack);
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
        _setError('wallet_error_frozen');
        return false;
      }

      try {
        await _walletRepository.updateWallet(walletId, data);
        _updateStatus(WalletStatusState.loaded);
        return true;
      } catch (e) {
        rethrow;
      }
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('wallet_error_update_failed', e, stack);
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
        throw ValidationException('wallet_error_frozen');
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

      try {
        await _transactionRepository.createTransaction(newTransaction);
        _updateStatus(WalletStatusState.loaded);
        return true;
      } catch (e) {
        rethrow;
      }
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('wallet_error_balance_update_failed', e, stack);
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

      try {
        await _walletRepository.deleteWallet(walletId);
        _updateStatus(WalletStatusState.loaded);
        return true;
      } catch (e, stack) {
        AppErrorHandler.handle(e,
            severity: ErrorSeverity.medium,
            operation: 'delete_wallet',
            stackTrace: stack);
        rethrow;
      }
    } on FirebaseException catch (e) {
      _setError(e.message ?? 'wallet_error_delete_failed', e);
      return false;
    } catch (e, stack) {
      _setError('wallet_error_delete_failed', e, stack);
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
    if (!_isDisposed) {
      Future.microtask(() => notifyListeners());
    }
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
    final amount = NumberParser.toDouble(data['amount']);
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

    // In-place update for performance (Phase 3)
    _wallets[index] = wallet.copyWith(balance: newBalance);
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
