import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/models/store_model.dart';
import '../data/services/local_storage_service.dart';
import 'package:walletmanager/services/time_service.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'auth_provider.dart';
import '../data/repositories/subscription_repository.dart';
import '../data/models/subscription_request_model.dart';

class SubscriptionProvider extends ChangeNotifier {
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
      _syncToStorage();
      _fetchLatestRequest();
    });
  }

  void _safeNotify() {
    if (!_isDisposed && hasListeners) {
      Future.microtask(() => notifyListeners());
    }
  }

  void updateAuthProvider(AuthProvider newAuth) {
    _authProvider.removeListener(_onAuthChanged);
    _authProvider = newAuth;
    _previousSubscription = _authProvider.currentStore?.subscription;
    _authProvider.addListener(_onAuthChanged);
    _syncToStorage();
    _fetchLatestRequest();
    _safeNotify();
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
          (currentSub.planId == 'pro_yearly' ||
              currentSub.planId == 'lifetime')) {
        // Dependably trigger success modal state
        LocalStorageService.instance.setHasSeenSuccessModal(false);
      }
    }
    _previousSubscription = currentSub;

    _syncToStorage();
    _fetchLatestRequest();
    _safeNotify();
  }

  bool get hasSeenSuccessModal =>
      LocalStorageService.instance.hasSeenSuccessModal;
  bool get hasDismissedRejection =>
      LocalStorageService.instance.hasDismissedRejection;

  void markSuccessModalSeen() {
    LocalStorageService.instance.setHasSeenSuccessModal(true);
    _safeNotify();
  }

  void dismissRejectionBanner() {
    LocalStorageService.instance.setHasDismissedRejection(true);
    _safeNotify();
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
          _safeNotify();
        }
      } else {
        _latestRequest = null;
        _safeNotify();
      }
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'subscription_fetch_latest',
          stackTrace: stack);
    }
  }

  double _deduceAmount(String planId) {
    if (planId == 'lifetime') return 2500.0;
    if (planId == 'pro_yearly') return 1200.0;
    return 0.0;
  }

  Future<void> submitSubscriptionRequest({
    required String planId,
    required String paymentMethod,
    required String receiptNumber,
  }) async {
    final storeId = _authProvider.currentStoreId;
    if (storeId == null) throw Exception('Store ID not found');

    // Store previous states for rollback
    final previousRequest = _latestRequest;

    // Reset modal flag whenever a new upgrade request is submitted
    LocalStorageService.instance.setHasSeenSuccessModal(false);

    // Optimistic UI update
    _latestRequest = SubscriptionRequestModel(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      storeId: storeId,
      planId: planId,
      amount: _deduceAmount(planId),
      paymentMethod: paymentMethod,
      receiptNumber: receiptNumber,
      status: 'pending',
      createdAt: Timestamp.now(),
    );
    _safeNotify();

    try {
      await _repository.submitSubscriptionRequest(
        storeId: storeId,
        planId: planId,
        paymentMethod: paymentMethod,
        receiptNumber: receiptNumber,
      );
      // Data will refresh on next _fetchLatestRequest or auth sync
    } catch (e, stack) {
      _latestRequest = previousRequest;
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.medium,
          operation: 'subscription_submit',
          stackTrace: stack);
      rethrow;
    } finally {
      // No specific boolean loading flag here, but we should notify just in case
      _safeNotify();
    }
  }

  void _syncToStorage() {
    final sub = _subscription;
    if (sub != null) {
      LocalStorageService.instance.saveSubscriptionLimits(
        endDateMs: sub.endDate?.millisecondsSinceEpoch,
        isLifetime: sub.planId == 'lifetime',
        smsEnabled: sub.smsEnabled,
        isSuspended: sub.status == SubscriptionStatus.suspended,
      );
    }
  }

  /// T058: Single point of time resolution for the entire domain layer.
  /// All expiration checks MUST go through this method.
  DateTime _serverNow() => TimeService.now();

  int get maxWallets => _subscription?.maxWallets ?? 3;
  int get maxEmployees => _subscription?.maxEmployees ?? 1;
  bool get isSmsEnabled => _subscription?.smsEnabled ?? false;

  bool get isSuspended =>
      _subscription?.status == SubscriptionStatus.suspended;

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

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
