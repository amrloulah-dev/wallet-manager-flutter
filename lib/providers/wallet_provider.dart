import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/routes/navigation_service.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
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
    _overlayDataSubscription?.cancel();
    _overlayDataSubscription = null;
    try {
      _overlayDataSubscription =
          FlutterOverlayWindow.overlayListener.listen((event) {
        if (kDebugMode) {
          debugPrint('🔥 [TX_FLOW] [wallet_provider] -> overlayListener: '
              'event received=$event');
        }

        if (event is Map && event['action'] == 'local_deduct') {
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

            _wallets[index] = oldWallet.copyWith(balance: newBalance);
            _rebuildWalletMap();
            _activateFetchShield(); // Block stale Firestore read for 5 s
            safeNotify();
          }
        }
      }, onError: (error) {
        AppErrorHandler.handle(error,
            operation: 'WalletProvider.overlayListener');
      });
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          operation: 'wallet_overlay_listener', stackTrace: stack);
    }
  }

  void applyLocalDeduction(String walletId, double deduction, bool isSend) {
    if (isDisposed) return;

    final index = _wallets.indexWhere((w) => w.walletId == walletId);
    if (index == -1) return;

    final oldWallet = _wallets[index];
    final newBalance =
        isSend ? oldWallet.balance - deduction : oldWallet.balance + deduction;

    if (newBalance < 0 && isSend) {
      throw DomainException('Insufficient balance for local deduction');
    }

    _wallets = [
      for (int i = 0; i < _wallets.length; i++)
        if (i == index)
          oldWallet.copyWith(balance: newBalance)
        else
          _wallets[i],
    ];

    _rebuildWalletMap();
    safeNotify();
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
  WalletType? get filterByType => _filterByType;
  WalletStatus? get filterByStatus => _filterByStatus;
  bool get hasMore => _hasMore;

  bool get isLoading => _status == WalletProviderStatus.loading;
  bool get isLoadingMore => _status == WalletProviderStatus.loadingMore;
  bool get isCreating => _status == WalletProviderStatus.creating;
  bool get isUpdating => _status == WalletProviderStatus.updating;
  bool get isDeleting => _status == WalletProviderStatus.deleting;
  bool get hasError => _status == WalletProviderStatus.error;

  void updateAuthState(AuthProvider auth) {
    if (_currentStoreId != auth.currentStoreId) {
      setStoreId(auth.currentStoreId);
    }
  }

  void updateSubscriptionProvider(SubscriptionProvider subscriptionProvider) {
    _subscriptionProvider = subscriptionProvider;
    if (_wallets.isNotEmpty) {
      _rebuildWalletMap();
      safeNotify();
    }
  }

  Future<UserModel> _validateUserAndPermission(
      bool Function(UserPermissions) selector) async {
    return _walletUseCase.validatePermission(selector);
  }

  void setStoreId(String? storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      if (storeId != null && storeId.isNotEmpty) {
        fetchInitialWallets();
      } else {
        _wallets = [];
        _walletMap = {};
        _status = WalletProviderStatus.idle;
        safeNotify();
      }
    }
  }

  Future<void> refresh() async {
    fetchInitialWallets(forceRefresh: true);
  }

  Future<void> fetchInitialWallets({bool forceRefresh = false}) async {
    if (_currentStoreId == null) return;
    if (!forceRefresh && _fetchShieldActive) return;

    _updateStatus(WalletProviderStatus.loading);
    _errorMessage = null;
    safeNotify();

    try {
      final storeId =
          _currentStoreId ?? (throw ValidationException('Store ID missing'));

      final result = await _walletRepository.getAllWallets(storeId);

      _wallets = result.items;
      _lastDocument = result.lastDocument;
      _hasMore = result.items.length >= 20;

      final walletsNeedingReset = _wallets
          .where((w) => w.needsDailyReset || w.needsMonthlyReset)
          .toList();

      if (walletsNeedingReset.isNotEmpty) {
        _walletRepository.resetLimitsForWallets(walletsNeedingReset);
      }

      _rebuildWalletMap();
      _updateStatus(WalletProviderStatus.loaded);
      _cacheManager.cacheWallets(_wallets);
    } catch (e, stack) {
      if (e is ServerException && e.code == 'permission-denied') {
        if (kDebugMode) debugPrint('🤫 [SILENT ERROR] WalletProvider: permission-denied (likely native sign-out)');
        return;
      }
      setError('wallet_error_fetch_failed', e, stack);
    } finally {
      safeNotify();
    }
  }

  Future<void> fetchMoreWallets() async {
    if (isLoading ||
        isLoadingMore ||
        !_hasMore ||
        _currentStoreId == null ||
        _lastDocument == null) {
      return;
    }

    _updateStatus(WalletProviderStatus.loadingMore);
    safeNotify();

    try {
      final storeId =
          _currentStoreId ?? (throw ValidationException('Store ID missing'));

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
    required WalletType walletType,
    required WalletStatus walletStatus,
    required double balance,
    String? notes,
    required String createdBy,
  }) async {
    _status = WalletProviderStatus.creating;
    _errorMessage = null;
    safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createWallet);

      final storeId =
          _currentStoreId ?? (throw ValidationException('Store ID missing'));

      if (_subscriptionProvider == null) {
        throw ValidationException('wallet_error_subscription_unresolved');
      }

      final currentCount = await _walletRepository.getWalletsCount(storeId);
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

      await _walletRepository.createWallet(newWallet);
      _updateStatus(WalletProviderStatus.loaded);
      return true;
    } on AppException catch (e, stack) {
      setError(e.message, e, stack);
      _handleUIFeedback();
      return false;
    } catch (e, stack) {
      setError('wallet_error_create_failed', e, stack);
      _handleUIFeedback();
      return false;
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

      if (await _isWalletFrozen(walletId)) {
        throw ValidationException('wallet_error_frozen');
      }

      await _walletRepository.updateWallet(walletId, data);
      _updateStatus(WalletProviderStatus.loaded);
      return true;
    } on AppException catch (e, stack) {
      setError(e.message, e, stack);
      _handleUIFeedback();
      return false;
    } catch (e, stack) {
      setError('wallet_error_update_failed', e, stack);
      _handleUIFeedback();
      return false;
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
      final storeId =
          _currentStoreId ?? (throw ValidationException('Store ID not found.'));

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
    } on AppException catch (e, stack) {
      setError(e.message, e, stack);
      _handleUIFeedback();
      return false;
    } catch (e, stack) {
      setError('wallet_error_balance_topup_failed', e, stack);
      _handleUIFeedback();
      return false;
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
      // Security Guard: Only Owners can delete wallets (Axis 2/Phase 6)
      if (!_authProvider.isOwner) {
        throw PermissionDeniedException();
      }

      await _walletRepository.deleteWallet(walletId);
      _updateStatus(WalletProviderStatus.loaded);
      return true;
    } on AppException catch (e, stack) {
      setError(e.message, e, stack);
      _handleUIFeedback();
      return false;
    } catch (e, stack) {
      setError('wallet_error_delete_failed', e, stack);
      _handleUIFeedback();
      return false;
    } finally {
      if (_status == WalletProviderStatus.deleting) {
        _updateStatus(WalletProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  void _handleUIFeedback() {
    if (AppErrorHandler.isTestMode) return;
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null) {
      ToastUtils.showError(AppLocalizations.of(context)!.unexpectedError);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchInitialWallets();
  }

  void setTypeFilter(WalletType? type) {
    _filterByType = type;
    fetchInitialWallets();
  }

  void setStatusFilter(WalletStatus? status) {
    _filterByStatus = status;
    fetchInitialWallets();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterByType = null;
    _filterByStatus = null;
    fetchInitialWallets();
  }

  void _updateStatus(WalletProviderStatus status) {
    if (isDisposed) return;
    _status = status;
    if (status == WalletProviderStatus.loading ||
        status == WalletProviderStatus.creating ||
        status == WalletProviderStatus.updating ||
        status == WalletProviderStatus.deleting) {
      _errorMessage = null;
    }
    safeNotify();
  }

  @override
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'wallet_operation']) {
    if (isDisposed) return;
    _errorMessage = errorCode;
    _status = WalletProviderStatus.error;

    super.setError(errorCode, error, stack, showToast, operation);
    safeNotify();
  }

  void clearAndCancel() {
    _currentStoreId = null;
    _overlayDataSubscription?.cancel();
    _overlayDataSubscription = null;
    _fetchShieldTimer?.cancel();
    _fetchShieldActive = false;
    _wallets = [];
    _walletMap = {};
    _frozenWalletIds.clear();
    _lastDocument = null;
    _hasMore = true;
    _status = WalletProviderStatus.idle;
    _errorMessage = null;
    safeNotify();
  }

  void clearError() {
    if (isDisposed) return;
    _errorMessage = null;
    _status = WalletProviderStatus.idle;
    safeNotify();
  }

  void _rebuildWalletMap() {
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

    // Update the in-memory wallet models to reflect the correct frozen state
    _wallets = _wallets.map((w) {
      return w.copyWith(isFrozen: _frozenWalletIds.contains(w.walletId));
    }).toList();

    _walletMap = {
      for (final wallet in _wallets) wallet.walletId: wallet,
    };
  }

  Future<bool> _isWalletFrozen(String walletId) async {
    return _frozenWalletIds.contains(walletId);
  }

  bool isWalletFrozenSync(String walletId) {
    return _frozenWalletIds.contains(walletId);
  }
}
