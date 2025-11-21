import 'package:firebase_performance/firebase_performance.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/providers/app_events.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/models/wallet_model.dart';
import '../core/errors/app_exceptions.dart';

enum WalletStatusState { // Renamed to avoid conflict with model field
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
  List<WalletModel> _wallets = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

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
  bool _isDisposed = false;

  // Constructor
  WalletProvider({
    WalletRepository? walletRepository,
    TransactionRepository? transactionRepository,
    String? storeId,
  })  : _walletRepository = walletRepository ?? WalletRepository(),
        _transactionRepository =
            transactionRepository ?? TransactionRepository(),
        _currentStoreId = storeId {
    _dataChangedSubscription = appEvents.onWalletsChanged.listen((_) {
      if (_currentStoreId != null && !isLoading && !isLoadingMore) {
        fetchInitialWallets(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dataChangedSubscription?.cancel();
    super.dispose();
  }

  // Getters
  List<WalletModel> get wallets => _wallets;
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
  void setStoreId(String storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      _cachedWallets = null;
      _cacheTimestamp = null;
      fetchInitialWallets();
    }
  }

  Future<void> fetchInitialWallets({bool forceRefresh = false}) async {
    if (_currentStoreId == null) return;

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedWallets != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      _wallets = _cachedWallets!;
      if(status != WalletStatusState.loaded){
        _setStatus(WalletStatusState.loaded);
      }
      return;
    }

    final trace = FirebasePerformance.instance.newTrace('fetch_initial_wallets_optimized');
    await trace.start();

    _setStatus(WalletStatusState.loading);
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
      final walletsNeedingReset = fetchedWallets.where((w) => w.needsDailyReset || w.needsMonthlyReset).toList();
      
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
                  lastDailyReset: now
              );
            }
            if (wallet.needsMonthlyReset) {
              tempWallet = tempWallet.copyWith(
                  sendLimits: tempWallet.sendLimits.copyWith(monthlyUsed: 0),
                  receiveLimits: tempWallet.receiveLimits.copyWith(monthlyUsed: 0),
                  lastMonthlyReset: now
              );
            }
            return tempWallet;
          }
          return wallet;
        }).toList();
      }

      _wallets = fetchedWallets;
      _cachedWallets = fetchedWallets;
      _cacheTimestamp = DateTime.now();
      _setStatus(WalletStatusState.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred while fetching wallets.');
    } finally {
      await trace.stop();
    }
  }

  Future<void> fetchMoreWallets() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null) return;

    _setStatus(WalletStatusState.loadingMore);

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

      final walletsNeedingReset = newWallets.where((w) => w.needsDailyReset || w.needsMonthlyReset).toList();
      
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
                  lastDailyReset: now
              );
            }
            if (wallet.needsMonthlyReset) {
              tempWallet = tempWallet.copyWith(
                  sendLimits: tempWallet.sendLimits.copyWith(monthlyUsed: 0),
                  receiveLimits: tempWallet.receiveLimits.copyWith(monthlyUsed: 0),
                  lastMonthlyReset: now
              );
            }
            return tempWallet;
          }
          return wallet;
        }).toList();

        _wallets.addAll(updatedNewWallets);
      } else {
        _wallets.addAll(newWallets);
      }

      _setStatus(WalletStatusState.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred while fetching more wallets.');
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
    _setStatus(WalletStatusState.creating);
    try {
      if (_currentStoreId == null) throw ValidationException('Store ID not found.');

      final newWallet = WalletModel.fromWalletStatus(
        walletId: FirebaseFirestore.instance.collection('wallets').doc().id,
        storeId: _currentStoreId!,
        phoneNumber: phoneNumber,
        walletType: walletType,
        walletStatus: walletStatus,
        balance: balance,
        notes: notes,
        createdBy: createdBy,
      );

      await _walletRepository.createWallet(newWallet);
      appEvents.fireWalletsChanged();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to create wallet.');
      return false;
    }
  }

  Future<bool> updateWallet(String walletId, Map<String, dynamic> data) async {
    _setStatus(WalletStatusState.updating);
    try {
      await _walletRepository.updateWallet(walletId, data);
      appEvents.fireWalletsChanged();
      return true;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to update wallet.');
      return false;
    }
  }

  Future<bool> addBalanceToWallet(String walletId, double amount, String createdBy) async {
    _setStatus(WalletStatusState.updating);
    try {
      if (amount <= 0) throw ValidationException('Amount must be positive.');
      if (_currentStoreId == null) throw ValidationException('Store ID not found.');

      final newTransaction = TransactionModel(
        transactionId: _transactionRepository.transactionsCollection.doc().id,
        storeId: _currentStoreId!,
        walletId: walletId,
        transactionType: 'deposit',
        amount: amount,
        transactionDate: Timestamp.now(),
        createdAt: Timestamp.now(),
        createdBy: createdBy,
      );

      await _transactionRepository.createTransaction(newTransaction);
      // This operation changes both wallets and transactions
      appEvents.fireWalletsChanged();
      appEvents.fireTransactionsChanged();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to update balance.');
      return false;
    }
  }

  Future<bool> deleteWallet(String walletId) async {
    _setStatus(WalletStatusState.deleting);
    try {
      await _walletRepository.deleteWallet(walletId);
      appEvents.fireWalletsChanged();
      _setStatus(WalletStatusState.loaded);
      return true;
    } on FirebaseException catch (e) {
      _setError(e.message ?? 'Failed to delete wallet.');
      return false;
    } catch (e) {
      _setError('Failed to delete wallet.');
      return false;
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
  void _setStatus(WalletStatusState status) {
    if (_isDisposed) return;
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    if (_isDisposed) return;
    _errorMessage = message;
    _status = WalletStatusState.error;
    notifyListeners();
  }

  void clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    _status = WalletStatusState.idle;
    notifyListeners();
  }
}
