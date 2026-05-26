import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/utils/amount_validator.dart';
import 'package:walletmanager/core/utils/number_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/wallet_model.dart';
import '../services/firebase_service.dart';
import '../models/paginated_result.dart';

class WalletRepository {
  final FirebaseService _firebaseService;
  final CacheManager _cacheManager;
  final StatsRepository _statsRepository;

  final FirebaseFirestore? _customFirestore;

  WalletRepository({
    FirebaseService? firebaseService,
    CacheManager? cacheManager,
    StatsRepository? statsRepository,
    FirebaseFirestore? firestore,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _cacheManager = cacheManager ?? CacheManager(),
        _statsRepository = statsRepository ?? StatsRepository(),
        _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? _firebaseService.firestore;
  CollectionReference get _walletsCollection =>
      _firestore.collection(FirebaseConstants.walletsCollection);

  String generateId() => _walletsCollection.doc().id;

  // 1️⃣ CREATE Methods
  Future<void> createWallet(WalletModel wallet) async {
    try {
      final batch = _firestore.batch();
      final walletRef = _walletsCollection.doc(wallet.walletId);

      batch.set(walletRef, wallet.toFirestore());

      await _statsRepository.updateStatsOnWalletChange(
        wallet.storeId,
        countChange: 1,
        activeCountChange: wallet.isActive ? 1 : 0,
        balanceChange: wallet.balance,
        batch: batch,
      );

      await batch.commit();

      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
    } catch (e, stack) {
      AppErrorHandler.logSilentError(e.toString(), 'WalletRepository.createWallet',
          stackTrace: stack);
      throw ServerException('wallet_error_create_failed');
    }
  }

  // 2️⃣ READ Methods
  Stream<List<WalletModel>> getWalletsStream(
    String storeId, {
    bool activeOnly = true,
    int limit = 20,
    WalletType? walletType,
    WalletStatus? walletStatus,
  }) {
    try {
      Query query = _walletsCollection.where(FirebaseConstants.storeId,
          isEqualTo: storeId);

      if (activeOnly) {
        query = query.where(FirebaseConstants.isActive, isEqualTo: true);
      }

      if (walletType != null) {
        query = query.where(FirebaseConstants.walletType,
            isEqualTo: walletType.name);
      }

      if (walletStatus != null) {
        query = query.where(FirebaseConstants.walletStatus,
            isEqualTo: walletStatus.name);
      }

      // Always order by createdAt to ensure consistent stream results
      query = query.orderBy(FirebaseConstants.createdAt, descending: true);

      return query.limit(limit).snapshots().map((snapshot) {
        final List<WalletModel> wallets = [];
        for (final doc in snapshot.docs) {
          try {
            wallets.add(WalletModel.fromFirestore(doc));
          } catch (e, stack) {
            AppErrorHandler.logSilentError(
                'Malformed wallet doc: ${doc.id} | error: $e',
                'wallet_stream_corruption',
                stackTrace: stack);
          }
        }
        return wallets;
      });
    } catch (e, stack) {
      AppErrorHandler.logSilentError(e.toString(), 'WalletRepository.getWalletsStream', stackTrace: stack);
      return Stream.error(ServerException('wallet_error_fetch_failed'));
    }
  }

  Future<WalletModel?> getWalletById(String walletId,
      {String? expectedStoreId}) async {
    final cacheKey = 'wallet_details_$walletId';
    final cachedWallet = _cacheManager.get<WalletModel>(cacheKey);

    if (cachedWallet != null) {
      if (expectedStoreId != null && cachedWallet.storeId != expectedStoreId) {
        throw PermissionDeniedException();
      }
      return cachedWallet;
    }

    try {
      final doc = await _walletsCollection.doc(walletId).get();
      if (!doc.exists) return null;
      final wallet = WalletModel.fromFirestore(doc);

      // Post-fetch Tenant Isolation Guard (Report 2: M-5)
      if (expectedStoreId != null && wallet.storeId != expectedStoreId) {
        throw PermissionDeniedException();
      }

      _cacheManager.set(cacheKey, wallet, duration: const Duration(minutes: 10));
      return wallet;
    } catch (e, stack) {
      AppErrorHandler.logSilentError(
          e.toString(), 'WalletRepository.getWalletById',
          stackTrace: stack);
      if (e is AppException) rethrow;
      throw ServerException('wallet_error_fetch_failed');
    }
  }

  Future<PaginatedResult<WalletModel>> getAllWallets(String storeId,
      {DocumentSnapshot? lastDocument}) async {
    try {
      Query query = _walletsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.isActive, isEqualTo: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.limit(20).get();
      final items = <WalletModel>[];
      for (final doc in snapshot.docs) {
        try {
          items.add(WalletModel.fromFirestore(doc));
        } catch (e, stack) {
          AppErrorHandler.logSilentError(
              'Malformed wallet doc in list: ${doc.id} | error: $e',
              'wallet_list_corruption',
              stackTrace: stack);
        }
      }
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PaginatedResult(items: items, lastDocument: lastDoc);
    } catch (e, stack) {
      AppErrorHandler.logSilentError(e.toString(), 'WalletRepository.getAllWallets', stackTrace: stack);
      throw ServerException('wallet_error_fetch_failed');
    }
  }

  Future<double> getTotalBalance(String storeId) async {
    try {
      final summary = await _statsRepository.getStatsSummary(storeId);
      return summary.totalBalance;
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'WalletRepository.getTotalBalance');
      throw ServerException('wallet_error_fetch_failed');
    }
  }

  Future<int> getWalletsCount(String storeId) async {
    try {
      final summary = await _statsRepository.getStatsSummary(storeId);
      return summary.activeWallets;
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'WalletRepository.getWalletsCount');
      throw ServerException('wallet_error_fetch_failed');
    }
  }

  // 3️⃣ UPDATE Methods
  Future<void> updateWallet(String walletId, Map<String, dynamic> data) async {
    // Domain Integrity Guard (Report 2: M-6)
    assert(!data.containsKey(FirebaseConstants.storeId),
        'storeId mutation is strictly forbidden for security reasons.');

    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _walletsCollection.doc(walletId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw NotFoundException('Wallet');

        final updateData = {
          ...data,
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp()
        };
        transaction.update(docRef, updateData);
      });
      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
      _cacheManager.clear('wallet_details_$walletId');
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'WalletRepository.updateWallet',
      );
      if (e is AppException) rethrow;
      throw ServerException('wallet_error_update_failed');
    }
  }

  Future<void> creditWallet(String walletId, double amount) async {
    AmountValidator.ensurePositive(amount);
    try {
      await _firestore.runTransaction((transaction) async {
        final walletRef = _walletsCollection.doc(walletId);
        final walletSnap = await transaction.get(walletRef);
        if (!walletSnap.exists) throw NotFoundException('Wallet');

        final wallet = WalletModel.fromFirestore(walletSnap);

        await _statsRepository.updateStatsOnWalletChange(
          wallet.storeId,
          balanceChange: amount,
          firestoreTransaction: transaction,
        );

        transaction.update(walletRef, {
          'balance': FieldValue.increment(amount),
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });
      });

      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
      _cacheManager.clear('wallet_details_$walletId');
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'WalletRepository.creditWallet',
      );
      if (e is AppException) rethrow;
      throw ServerException('wallet_error_balance_topup_failed');
    }
  }

  Future<void> debitWallet(String walletId, double amount) async {
    AmountValidator.ensurePositive(amount);
    try {
      await _firestore.runTransaction((transaction) async {
        final walletRef = _walletsCollection.doc(walletId);
        final walletSnap = await transaction.get(walletRef);
        if (!walletSnap.exists) throw NotFoundException('Wallet');

        final wallet = WalletModel.fromFirestore(walletSnap);
        final data = walletSnap.data() as Map<String, dynamic>?;
        final currentBalance = NumberParser.toDouble(data?['balance']);
        if ((currentBalance + 0.01) < amount) {
          throw DomainException('wallet_error_insufficient_balance');
        }

        await _statsRepository.updateStatsOnWalletChange(
          wallet.storeId,
          balanceChange: -amount,
          firestoreTransaction: transaction,
        );

        transaction.update(walletRef, {
          'balance': FieldValue.increment(-amount),
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });
      });

      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
      _cacheManager.clear('wallet_details_$walletId');
    } catch (e, stack) {
      AppErrorHandler.logSilentError(e.toString(), 'WalletRepository.debitWallet', stackTrace: stack);
      if (e is AppException) rethrow;
      throw ServerException('wallet_error_debit_failed');
    }
  }

  // 4️⃣ DELETE Methods
  Future<void> deleteWallet(String walletId) async {
    await setWalletActiveStatus(walletId, false);
  }

  Future<void> setWalletActiveStatus(String walletId, bool isActive) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final walletRef = _walletsCollection.doc(walletId);
        final walletSnap = await transaction.get(walletRef);
        if (!walletSnap.exists) throw NotFoundException('Wallet');

        final wallet = WalletModel.fromFirestore(walletSnap);

        // Perform Stats update FIRST (because it has a internal READ)
        // We must call it before any writes in this transaction
        await _statsRepository.updateStatsOnWalletChange(
          wallet.storeId,
          countChange: isActive ? 1 : -1,
          activeCountChange: isActive ? 1 : -1,
          balanceChange: isActive ? wallet.balance : -wallet.balance,
          firestoreTransaction: transaction,
        );

        // Now perform the wallet update (WRITE)
        transaction.update(walletRef, {
          FirebaseConstants.isActive: isActive,
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });
      });

      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
      _cacheManager.clear('wallet_details_$walletId');
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'WalletRepository.setWalletActiveStatus');
      if (e is AppException) rethrow;
      throw ServerException('wallet_error_status_update_failed');
    }
  }

  // 5️⃣ STREAM Methods
  Stream<WalletModel?> watchWallet(String walletId, {String? expectedStoreId}) {
    return _walletsCollection.doc(walletId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final wallet = WalletModel.fromFirestore(doc);

      // Post-fetch Tenant Isolation Guard (Report 2: M-5)
      if (expectedStoreId != null && wallet.storeId != expectedStoreId) {
        throw PermissionDeniedException();
      }

      return wallet;
    }).handleError((e, stack) {
      AppErrorHandler.logSilentError(e.toString(), 'WalletRepository.watchWallet',
          stackTrace: stack);
      if (e is AppException) throw e;
      throw ServerException('wallet_error_watch_failed');
    });
  }

  // 6️⃣ RESET Methods
  Future<void> resetLimitsForWallets(List<WalletModel> wallets) async {
    const int chunkSize = 450;

    for (var i = 0; i < wallets.length; i += chunkSize) {
      final chunk = wallets.sublist(
          i, i + chunkSize > wallets.length ? wallets.length : i + chunkSize);
      final batch = _firestore.batch();
      var walletsToResetInBatch = 0;

      for (final wallet in chunk) {
        final updates = <String, dynamic>{};
        final serverTs = FieldValue.serverTimestamp();

        if (wallet.needsDailyReset) {
          updates['${FirebaseConstants.sendLimits}.dailyUsed'] = 0.0;
          updates['${FirebaseConstants.receiveLimits}.dailyUsed'] = 0.0;
          updates[FirebaseConstants.lastDailyReset] = serverTs;
        }
        if (wallet.needsMonthlyReset) {
          updates['${FirebaseConstants.sendLimits}.monthlyUsed'] = 0.0;
          updates['${FirebaseConstants.receiveLimits}.monthlyUsed'] = 0.0;
          updates[FirebaseConstants.lastMonthlyReset] = serverTs;
        }

        if (updates.isNotEmpty) {
          final walletRef = _walletsCollection.doc(wallet.walletId);
          batch.update(walletRef, updates);
          walletsToResetInBatch++;
        }
      }

      try {
        if (walletsToResetInBatch > 0) {
          await batch.commit();
        }
      } catch (e, stack) {
        AppErrorHandler.handle(e,
            stackTrace: stack,
            operation: 'WalletRepository.resetLimitsForWallets');
        throw ServerException('wallet_error_update_failed');
      }
    }

    _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
    for (final wallet in wallets) {
      _cacheManager.clear('wallet_details_${wallet.walletId}');
    }
  }
}
