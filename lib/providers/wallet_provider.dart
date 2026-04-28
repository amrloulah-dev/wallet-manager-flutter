import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/models/wallet_model.dart';
import '../core/errors/app_exceptions.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import 'subscription_provider.dart';
import 'package:walletmanager/data/services/wallet_cache_manager.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/domain/usecases/wallet_usecase.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../core/utils/number_parser.dart';
import '../core/enums/wallet_enums.dart';

enum WalletProviderStatus {
  idle,
  loading,
  loadingMore,
  loaded,
  error,
  creating,
  updating,
  deleting,
}

class WalletProvider extends BaseProvider {
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;
  final WalletCacheManager _cacheManager;
  final WalletUseCase _walletUseCase;

  // State
  String? _currentStoreId;

  // ignore: unused_field
  final AuthProvider _authProvider; // Made final and non-nullable
  SubscriptionProvider? _subscriptionProvider;
  List<WalletModel> _wallets = [];
  Map<String, WalletModel> _walletMap = {};
  final Set<String> _frozenWalletIds = {};
  dynamic _lastDocument; // opaque cursor — typed at the repository boundary
  bool _hasMore = true;

  // Status
  WalletProviderStatus _status = WalletProviderStatus.idle;
  String? _errorMessage;

  // Filters
  String _searchQuery = '';
  WalletType? _filterByType; // ENUM refactor
  WalletStatus? _filterByStatus; // ENUM refactor

  StreamSubscription? _overlayDataSubscription;

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
    WalletCacheManager? cacheManager,
    WalletUseCase? walletUseCase,
    String? storeId,
  })  : _authProvider = authProvider,
        _subscriptionProvider = subscriptionProvider,
        _walletRepository = walletRepository ?? sl<WalletRepository>(),
        _transactionRepository =
            transactionRepository ?? sl<TransactionRepository>(),
        _cacheManager = cacheManager ?? sl<WalletCacheManager>(),
        _walletUseCase = walletUseCase ?? sl<WalletUseCase>(),
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
            safeNotify();
            debugPrint('🔥 [TX_FLOW] [wallet_provider] -> overlayListener: '
                'local_deduct applied! walletId=$walletId, '
                'oldBalance=${oldWallet.balance}, newBalance=$newBalance, '
                'isSend=$isSend. No Firebase read needed!');
          }
        }
      }, onError: (error) {
        AppErrorHandler.handle(error, operation: 'WalletProvider.overlayListener');
      });
    } catch (e, stack) {
      AppErrorHandler.handle(e, operation: 'wallet_overlay_listener', stackTrace: stack);
    }
  }

  // ── Public API for optimistic local balance mutation ──
  // Called by GlobalOverlayListener (IsolateNameServer path) and
  // overlayListener (FlutterOverlayWindow path) to avoid any Firestore reads.
  void applyLocalDeduction(String walletId, double deduction, bool isSend) {
    if (isDisposed) return;

    final index = _wallets.indexWhere((w) => w.walletId == walletId);
    if (index == -1) {
      debugPrint('🔥 [TX_FLOW] LOCAL MUTATION: walletId=$walletId not in RAM — skipping.');
      return;
    }

    final oldWallet = _wallets[index];
    final newBalance =
        isSend ? oldWallet.balance - deduction : oldWallet.balance + deduction;

    // VALIDATION: Ensure balance won't go negative for send transactions
    if (newBalance < 0 && isSend) {
      throw DomainException('Insufficient balance for local deduction');
    }

    // Create new list to avoid in-place mutation (immutable approach using List.of)
    _wallets = [
      for (int i = 0; i < _wallets.length; i++)
        if (i == index) oldWallet.copyWith(balance: newBalance) else _wallets[i],
    ];
    
    _rebuildWalletMap();
    safeNotify();
    debugPrint('🔥 [TX_FLOW] LOCAL MUTATION APPLIED! '
        'walletId=$walletId | oldBalance=${oldWallet.balance} → New Balance: $newBalance | '
        'isSend=$isSend | No Firestore read.');
  }

  @override
  void dispose() {
    _overlayDataSubscription?.cancel();
    _fetchShieldTimer?.cancel();
    super.dispose();
  }

  // Getters
  List<WalletModel> get wallets => _wallets;
  Map<String, WalletModel> get walletMap => _walletMap;
  WalletProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentStoreId => _currentStoreId;
  String get searchQuery => _searchQuery;
  WalletType? get filterByType => _filterByType; // ENUM refactor
  WalletStatus? get filterByStatus => _filterByStatus; // ENUM refactor
  bool get hasMore => _hasMore;

  // Helper Getters
  bool get isLoading => _status == WalletProviderStatus.loading;
  bool get isLoadingMore => _status == WalletProviderStatus.loadingMore;
  bool get isCreating => _status == WalletProviderStatus.creating;
  bool get isUpdating => _status == WalletProviderStatus.updating;
  bool get isDeleting => _status == WalletProviderStatus.deleting;
  bool get hasError => _status == WalletProviderStatus.error;

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
    return _walletUseCase.validatePermission(selector);
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

    _updateStatus(WalletProviderStatus.loading);
    _errorMessage = null;
    safeNotify();

    try {
      debugPrint('⏳ [INIT DATA] WalletProvider: Requesting wallets from repository...');
      
      final storeId = _currentStoreId ?? (throw ValidationException('Store ID missing'));
      
      final result = await _walletRepository.getAllWallets(
        storeId,
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
      _updateStatus(WalletProviderStatus.loaded);

      // Cache the wallets locally for SMS Automation
      _cacheManager.cacheWallets(_wallets);
    } catch (e, stack) {
      debugPrint('❌ [INIT FATAL] WalletProvider Error: $e');
      debugPrint('🔍 [STACK TRACE]: $stack');
      setError('wallet_error_fetch_failed', e, stack);
      ToastUtils.showError('wallet_error_fetch_failed');
    } finally {
      safeNotify();
    }
  }

  Future<void> fetchMoreWallets() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null || _lastDocument == null) {
      return;
    }

    _updateStatus(WalletProviderStatus.loadingMore);
    safeNotify();

    try {
      final storeId = _currentStoreId ?? (throw ValidationException('Store ID missing'));
      
      final result = await _walletRepository.getAllWallets(
        storeId,
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
      _updateStatus(WalletProviderStatus.loaded);
    } catch (e, stack) {
      setError('wallet_error_fetch_more_failed', e, stack);
    } finally {
      safeNotify();
    }
  }

  Future<bool> createWallet({
    required String phoneNumber,
    required WalletType walletType, // ENUM refactor
    required WalletStatus walletStatus, // ENUM refactor
    required double balance,
    String? notes,
    required String createdBy,
  }) async {
    _status = WalletProviderStatus.creating;
    _errorMessage = null;
    safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createWallet);

      final storeId = _currentStoreId ?? (throw ValidationException('Store ID missing'));

      // Bug B-002: Fail-closed if subscription provider is missing
      if (_subscriptionProvider == null) {
        throw ValidationException('wallet_error_subscription_unresolved');
      }

      final currentCount =
          await _walletRepository.getWalletsCount(storeId);
      if (!_subscriptionProvider!.canAddWallet(currentCount)) {
        throw ValidationException('wallet_error_limit_reached');
      }

      final newWallet = WalletModel.fromWalletStatus(
        walletId: _walletRepository.generateId(),
        storeId: storeId,
        phoneNumber: phoneNumber,
        walletType: walletType.name,
        walletStatus: walletStatus.name,
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
        _updateStatus(WalletProviderStatus.loaded);
        return true;
      } catch (e) {
        rethrow;
      }
    } on AppException catch (e) {
      setError(e.message, e); // Pass 'e' to ensure AppErrorHandler.handle is called
      ToastUtils.showError(e.message); // Visible surfacing for Phase 1.1-1.4 Reqs
      rethrow;
    } catch (e, stack) {
      setError('wallet_error_create_failed', e, stack);
      rethrow;
    } finally {
      if (_status == WalletProviderStatus.creating) {
        _updateStatus(WalletProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> updateWallet(String walletId, Map<String, dynamic> data) async {
    _status = WalletProviderStatus.updating;
    _errorMessage = null;
    safeNotify();
    try {
      await _validateUserAndPermission((p) => p.editWallet);

      // Check FIFO freeze
      if (await _isWalletFrozen(walletId)) {
        throw ValidationException('wallet_error_frozen');
      }

      await _walletRepository.updateWallet(walletId, data);
      _updateStatus(WalletProviderStatus.loaded);
      return true;
    } on ServerException catch (e) {
      setError(e.message);
      rethrow;
    } catch (e, stack) {
      setError('wallet_error_update_failed', e, stack);
      rethrow;
    } finally {
      if (_status == WalletProviderStatus.updating) {
        _updateStatus(WalletProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> addBalanceToWallet(
      String walletId, double amount, String createdBy) async {
    _updateStatus(WalletProviderStatus.updating);
    try {
      await _validateUserAndPermission((p) => p.addBalance);

      if (amount <= 0) throw ValidationException('Amount must be positive.');
      final storeId = _currentStoreId ?? (throw ValidationException('Store ID not found.'));

      // Check FIFO freeze
      if (await _isWalletFrozen(walletId)) {
        throw ValidationException('wallet_error_frozen');
      }

      await _transactionRepository.createDeposit(
        transactionId: _transactionRepository.generateId(),
        storeId: storeId,
        walletId: walletId,
        amount: amount,
        createdBy: createdBy,
      );
      _updateStatus(WalletProviderStatus.loaded);
      return true;
    } on AppException catch (e) {
      setError(e.message, e); // Pass 'e' to ensure AppErrorHandler.handle is called
      ToastUtils.showError(e.message); // Visible surfacing for Phase 1.1-1.4 Reqs
      rethrow;
    } catch (e, stack) {
      setError('wallet_error_balance_update_failed', e, stack);
      rethrow;
    } finally {
      if (_status == WalletProviderStatus.updating) {
        _updateStatus(WalletProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  Future<bool> deleteWallet(String walletId) async {
    _updateStatus(WalletProviderStatus.deleting);
    try {
      await _validateUserAndPermission((p) => p.editWallet);

      try {
        await _walletRepository.deleteWallet(walletId);
        _updateStatus(WalletProviderStatus.loaded);
        return true;
      } catch (e, stack) {
        AppErrorHandler.handle(e,
            severity: ErrorSeverity.medium,
            operation: 'delete_wallet',
            stackTrace: stack);
        rethrow;
      }
    } on Exception catch (e) {
      setError(e.toString(), e);
      rethrow;
    } catch (e, stack) {
      setError('wallet_error_delete_failed', e, stack);
      rethrow;
    } finally {
      if (_status == WalletProviderStatus.deleting) {
        _updateStatus(WalletProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  // Note: Filters will now require re-fetching data.
  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchInitialWallets();
  }

  void setTypeFilter(WalletType? type) { // ENUM refactor
    _filterByType = type;
    fetchInitialWallets();
  }

  void setStatusFilter(WalletStatus? status) { // ENUM refactor
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
  void _updateStatus(WalletProviderStatus status) {
    if (isDisposed) return;
    _status = status;
    // Reset error when starting a new operation
    if (status == WalletProviderStatus.loading ||
        status == WalletProviderStatus.creating ||
        status == WalletProviderStatus.updating ||
        status == WalletProviderStatus.deleting) {
      _errorMessage = null;
    }
    safeNotify();
  }

  @override
  void setError(String errorCode, [Object? error, StackTrace? stack]) {
    if (isDisposed) return;
    _errorMessage = errorCode;
    _status = WalletProviderStatus.error;
    super.setError(errorCode, error, stack);
  }

  void clearError() {
    if (isDisposed) return;
    _errorMessage = null;
    _status = WalletProviderStatus.idle;
    safeNotify();
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
    safeNotify();
  }

  void _rebuildWalletMap() {
    _walletMap = {
      for (final wallet in _wallets) wallet.walletId: wallet,
    };
    _recalculateFrozenWallets();
  }

  void _recalculateFrozenWallets() {
    _frozenWalletIds.clear();
    final frozen = _walletUseCase.calculateFrozenWallets(
      wallets: _wallets,
      subscriptionProvider: _subscriptionProvider,
      storeId: _currentStoreId,
    );
    _frozenWalletIds.addAll(frozen);
  }

  Future<bool> _isWalletFrozen(String walletId) async {
    return _frozenWalletIds.contains(walletId);
  }

  // Synchronous check for UI bindings based on local RAM loaded items
  bool isWalletFrozenSync(String walletId) {
    return _frozenWalletIds.contains(walletId);
  }
}
