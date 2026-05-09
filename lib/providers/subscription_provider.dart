import '../data/models/store_model.dart';
import '../data/services/local_storage_service.dart';
import 'package:walletmanager/services/time_service.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../core/errors/app_exceptions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'auth_provider.dart';
import '../data/repositories/subscription_repository.dart';
import '../data/models/subscription_request_model.dart';
import 'base_provider.dart';
import '../core/enums/subscription_enums.dart';

class SubscriptionProvider extends BaseProvider {
  AuthProvider _authProvider;
  final SubscriptionRepository _repository;
  SubscriptionRequestModel? _latestRequest;

  StoreSubscription? _previousSubscription;

  SubscriptionProvider({
    required AuthProvider authProvider,
    SubscriptionRepository? repository,
  })  : _authProvider = authProvider,
        _repository = repository ?? sl<SubscriptionRepository>() {
    _previousSubscription = _authProvider.currentStore?.subscription;
    _authProvider.addListener(_onAuthChanged);
    Future.microtask(() {
      _checkIntegrityAndFreshness();
      _syncToStorage();
      _fetchLatestRequest();
    });
  }

  void updateAuthProvider(AuthProvider newAuth) {
    _authProvider.removeListener(_onAuthChanged);
    _authProvider = newAuth;
    _previousSubscription = _authProvider.currentStore?.subscription;
    _authProvider.addListener(_onAuthChanged);
    _checkIntegrityAndFreshness();
    _syncToStorage();
    _fetchLatestRequest();
    safeNotify();
  }

  /// Verifies the local cache integrity and triggers a Firestore refresh if stale or tampered.
  Future<void> _checkIntegrityAndFreshness() async {
    final storage = LocalStorageService.instance;
    
    // If tampered with or stale (>24h), trigger a hard refresh of user data
    if (!storage.isSubIntegrityValid || !storage.isSubscriptionSyncFresh) {
      if (kDebugMode) {
        debugPrint('🛡️ [SECURITY] Subscription cache invalid or stale. Triggering Firestore re-validation.');
      }
      await _authProvider.refreshUserData();
    }
  }

  StoreSubscription? get _subscription =>
      _authProvider.currentStore?.subscription;
  SubscriptionRequestModel? get latestRequest => _latestRequest;

  void _onAuthChanged() {
    final currentSub = _subscription;

    // T051: Upgrade detection
    if (_previousSubscription != null && currentSub != null) {
      final wasPending = _previousSubscription!.pendingRequestDate != null;
      final isNowPending = currentSub.pendingRequestDate != null;

      if (wasPending &&
          !isNowPending &&
          currentSub.status == SubscriptionStatus.active &&
          (currentSub.planId == SubscriptionPlan.proYearly ||
              currentSub.planId == SubscriptionPlan.lifetime)) {
        // Dependably trigger success modal state
        LocalStorageService.instance.setHasSeenSuccessModal(false);
      }
    }
    _previousSubscription = currentSub;

    _syncToStorage();
    _fetchLatestRequest();
    safeNotify();
  }

  bool get hasSeenSuccessModal =>
      LocalStorageService.instance.hasSeenSuccessModal;
  bool get hasDismissedRejection =>
      LocalStorageService.instance.hasDismissedRejection;

  void markSuccessModalSeen() {
    LocalStorageService.instance.setHasSeenSuccessModal(true);
    safeNotify();
  }

  void dismissRejectionBanner() {
    LocalStorageService.instance.setHasDismissedRejection(true);
    safeNotify();
  }

  Future<void> _fetchLatestRequest() async {
    try {
      final storeId = _authProvider.currentStore?.storeId;
      if (storeId != null) {
        final request = await _repository.getLatestSubscriptionRequest(storeId);
        if (_latestRequest?.id != request?.id ||
            _latestRequest?.status != request?.status) {
          // If a new request arrives, clear locally dismissed rejection
          if (request != null && _latestRequest?.id != request.id) {
            LocalStorageService.instance.setHasDismissedRejection(false);
            LocalStorageService.instance.setHasSeenSuccessModal(
                false); // Reset success too for any future transition
          }

          _latestRequest = request;
          safeNotify();
        }
      } else {
        _latestRequest = null;
        safeNotify();
      }
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'subscription_fetch_latest',
          stackTrace: stack);
    }
  }

  double _deduceAmount(SubscriptionPlan planId) {
    if (planId == SubscriptionPlan.lifetime) return 2500.0;
    if (planId == SubscriptionPlan.proYearly) return 1200.0;
    return 0.0;
  }

  Future<void> submitSubscriptionRequest({
    required SubscriptionPlan planId, // ENUM refactor
    required String paymentMethod,
    required String receiptNumber,
  }) async {
    final storeId = _authProvider.currentStoreId;
    if (storeId == null) throw AuthException('auth_error_store_not_found');

    // Store previous states for rollback
    final previousRequest = _latestRequest;

    // Reset modal flag whenever a new upgrade request is submitted
    LocalStorageService.instance.setHasSeenSuccessModal(false);

    // Optimistic UI update
    _latestRequest = SubscriptionRequestModel(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      storeId: storeId,
      planId: planId
          .name, // Mapping to string for the model if it still uses string
      amount: _deduceAmount(planId),
      paymentMethod: paymentMethod,
      receiptNumber: receiptNumber,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    safeNotify();

    try {
      await _repository.submitSubscriptionRequest(
        storeId: storeId,
        planId: planId.name,
        paymentMethod: paymentMethod,
        receiptNumber: receiptNumber,
      );
      // Data will refresh on next _fetchLatestRequest or auth sync
    } catch (e, stack) {
      _latestRequest = previousRequest;
      setError('subscription_submit_failed', e, stack);
      rethrow;
    } finally {
      // No specific boolean loading flag here, but we should notify just in case
      safeNotify();
    }
  }

  void _syncToStorage() {
    final sub = _subscription;
    if (sub != null) {
      LocalStorageService.instance.saveSubscriptionLimits(
        endDateMs: sub.endDate?.millisecondsSinceEpoch,
        isLifetime: sub.planId == SubscriptionPlan.lifetime,
        smsEnabled: sub.smsEnabled,
        isSuspended: sub.status == SubscriptionStatus.suspended,
      );
      LocalStorageService.instance.saveSubLastSyncMs();
    }
  }

  /// T058: Single point of time resolution for the entire domain layer.
  /// All expiration checks MUST go through this method.
  DateTime _serverNow() => TimeService.now();

  int get maxWallets => _subscription?.maxWallets ?? 3;
  int get maxEmployees => _subscription?.maxEmployees ?? 1;
  bool get isSmsEnabled => _subscription?.smsEnabled ?? false;

  bool get isSuspended => _subscription?.status == SubscriptionStatus.suspended;

  /// T058: Expiration evaluated in the domain layer using NTP-resolved time.
  bool get isExpired => _subscription?.isExpiredAt(_serverNow()) ?? false;

  /// T058: Pending payment state derived purely from pendingRequestDate nullability (I2).
  bool get hasPendingRequest => _subscription?.pendingRequestDate != null;

  /// T058: Days remaining computed with server-resolved time.
  int? get daysRemaining => _subscription?.daysRemainingAt(_serverNow());

  bool canAddWallet(int currentWalletCount) {
    // T053: Fallback to Free tier caps when explicitly expired with no pending request
    if (_subscription != null && isExpired && !hasPendingRequest) {
      return currentWalletCount < 3;
    }
    return currentWalletCount < maxWallets;
  }

  bool canAddEmployee(int currentEmployeeCount) {
    // T053: Fallback to Free tier caps when explicitly expired with no pending request
    if (_subscription != null && isExpired && !hasPendingRequest) {
      return currentEmployeeCount < 1;
    }
    return currentEmployeeCount < maxEmployees;
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
