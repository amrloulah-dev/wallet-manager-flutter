import '../data/models/store_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/services/local_storage_service.dart';
import 'package:walletmanager/services/time_service.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../core/errors/app_exceptions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'auth_provider.dart';
import 'platform_settings_provider.dart';
import '../data/repositories/subscription_repository.dart';
import '../data/models/subscription_request_model.dart';
import 'base_provider.dart';
import '../data/models/subscription_plan_model.dart';
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
    sl<PlatformSettingsProvider>().addListener(_onSettingsChanged);
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
        debugPrint(
            '🛡️ [SECURITY] Subscription cache invalid or stale. Triggering Firestore re-validation.');
      }
      try {
        await _authProvider.refreshUserData();
      } catch (e, stack) {
        // Graceful fallback: use last known local cache to avoid blocking app init
        if (kDebugMode) {
          debugPrint(
              '⚠️ [SECURITY] Firestore re-validation failed. Using last known local state. Error: $e');
        }
        AppErrorHandler.handle(e,
            severity: ErrorSeverity.medium,
            operation: 'SubscriptionProvider._checkIntegrityAndFreshness',
            stackTrace: stack);
      }
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
        LocalStorageService.instance.setLastSeenPaymentKey('');
      }
    }
    _previousSubscription = currentSub;

    _syncToStorage();
    _fetchLatestRequest();
    safeNotify();
  }

  bool get hasSeenSuccessModal {
    final sub = _authProvider.currentStore?.subscription;
    if (sub == null) return true;
    final key =
        "${sub.planId.name}_${sub.endDate?.millisecondsSinceEpoch ?? 'lifetime'}";
    return LocalStorageService.instance.lastSeenPaymentKey == key;
  }

  bool get hasDismissedRejection =>
      LocalStorageService.instance.hasDismissedRejection;

  void markSuccessModalSeen() {
    final sub = _authProvider.currentStore?.subscription;
    if (sub != null) {
      final key =
          "${sub.planId.name}_${sub.endDate?.millisecondsSinceEpoch ?? 'lifetime'}";
      LocalStorageService.instance.setLastSeenPaymentKey(key);
      safeNotify();
    }
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
          if (request != null &&
              _latestRequest != null &&
              _latestRequest!.id != request.id) {
            LocalStorageService.instance.setHasDismissedRejection(false);
            LocalStorageService.instance.setLastSeenPaymentKey(
                ''); // Reset success too for any future transition
          }

          _latestRequest = request;
          safeNotify();
        }
      } else {
        _latestRequest = null;
        safeNotify();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        if (kDebugMode) {
          debugPrint(
              '🤫 [SILENT RBAC] SubscriptionProvider: Employee permission-denied in _fetchLatestRequest');
        }
        return;
      }
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'subscription_fetch_latest');
    } catch (e, stack) {
      if (e is ServerException && e.code == 'permission-denied') {
        if (kDebugMode) {
          debugPrint(
              '🤫 [SILENT RBAC] SubscriptionProvider: Employee permission-denied in _fetchLatestRequest');
        }
        return;
      }
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'subscription_fetch_latest',
          stackTrace: stack);
    }
  }

  Future<void> submitSubscriptionRequest({
    required SubscriptionPlan planId, // ENUM refactor
    required String paymentMethod,
    required String receiptNumber,
    required double amount,
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
      amount: amount,
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
        amount: amount,
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
        smsEnabled: isSmsEnabled,
        isSuspended: sub.status == SubscriptionStatus.suspended,
      );
      LocalStorageService.instance.saveSubLastSyncMs();
    }
  }

  /// T058: Single point of time resolution for the entire domain layer.
  /// All expiration checks MUST go through this method.
  DateTime _serverNow() => TimeService.now();

  SubscriptionPlanModel? _lookupPlanCaseInsensitive(
      Map<String, SubscriptionPlanModel> plans, String targetKey) {
    final targetLower = targetKey.toLowerCase();
    for (final entry in plans.entries) {
      if (entry.key.toLowerCase() == targetLower) {
        return entry.value;
      }
    }
    final targetNormalized =
        targetLower.replaceAll('_', '').replaceAll(' ', '');
    for (final entry in plans.entries) {
      final entryNormalized =
          entry.key.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
      if (entryNormalized == targetNormalized) {
        return entry.value;
      }
    }
    return null;
  }

  SubscriptionPlanModel get currentPlanLimits {
    final sub = _subscription;
    final settingsProvider = sl<PlatformSettingsProvider>();
    final plans = settingsProvider.settings.plans;

    if (sub != null && (!isExpired || hasPendingRequest)) {
      final planKey = sub.planId.name;
      final planModel = _lookupPlanCaseInsensitive(plans, planKey);
      if (planModel != null) {
        return planModel;
      }
    }

    // Expired or null subscription or plan not found in catalog: fallback to Free plan
    final freePlan = _lookupPlanCaseInsensitive(plans, 'free');
    if (freePlan != null) {
      return freePlan;
    }

    // Last resort fallback
    return const SubscriptionPlanModel.fallback();
  }

  int get maxWallets => currentPlanLimits.maxWallets;

  int get maxEmployees => currentPlanLimits.maxEmployees;

  bool get isSmsEnabled => currentPlanLimits.smsEnabled;

  bool get isSuspended => _subscription?.status == SubscriptionStatus.suspended;

  /// T058: Expiration evaluated in the domain layer using NTP-resolved time.
  bool get isExpired => _subscription?.isExpiredAt(_serverNow()) ?? false;

  /// T058: Pending payment state derived purely from pendingRequestDate nullability (I2).
  bool get hasPendingRequest => _subscription?.pendingRequestDate != null;

  /// T058: Days remaining computed with server-resolved time.
  int? get daysRemaining => _subscription?.daysRemainingAt(_serverNow());

  bool canAddWallet(int currentWalletCount) {
    final limit = maxWallets;
    if (limit == -1) return true;
    return currentWalletCount < limit;
  }

  bool canAddEmployee(int currentEmployeeCount) {
    final limit = maxEmployees;
    if (limit == -1) return true;
    return currentEmployeeCount < limit;
  }

  void _onSettingsChanged() {
    safeNotify();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    sl<PlatformSettingsProvider>().removeListener(_onSettingsChanged);
    super.dispose();
  }
}
