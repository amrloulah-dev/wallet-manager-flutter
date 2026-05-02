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

  WalletRepository({
    FirebaseService? firebaseService,
    CacheManager? cacheManager,
    StatsRepository? statsRepository,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _cacheManager = cacheManager ?? CacheManager(),
        _statsRepository = statsRepository ?? StatsRepository();

  FirebaseFirestore get _firestore => _firebaseService.firestore;
  CollectionReference get _walletsCollection =>
      _firestore.collection(FirebaseConstants.walletsCollection);

  String generateId() => _walletsCollection.doc().id;

  // 1️⃣ CREATE Methods
  Future<void> createWallet(WalletModel wallet) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final walletRef = _walletsCollection.doc(wallet.walletId);
        
        transaction.set(walletRef, wallet.toFirestore());
        
        await _statsRepository.updateStatsOnWalletChange(
          wallet.storeId,
          countChange: 1,
          activeCountChange: wallet.isActive ? 1 : 0,
          balanceChange: wallet.balance,
          firestoreTransaction: transaction,
        );
      });
      
      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
    } catch (e) {
      throw ServerException('فشل إنشاء المحفظة: $e');
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
        query = query.where(FirebaseConstants.walletType, isEqualTo: walletType.name);
      }
      
      if (walletStatus != null) {
        query = query.where(FirebaseConstants.walletStatus, isEqualTo: walletStatus.name);
      }

      // Always order by createdAt to ensure consistent stream results
      query = query.orderBy(FirebaseConstants.createdAt, descending: true);

      return query.limit(limit).snapshots().map((snapshot) {
        final List<WalletModel> wallets = [];
        for (final doc in snapshot.docs) {
          try {
            wallets.add(WalletModel.fromFirestore(doc));
          } catch (e) {
            AppErrorHandler.logSilentError(
              'Malformed wallet doc: ${doc.id} | error: $e',
              'wallet_stream_corruption'
            );
          }
        }
        return wallets;
      });
    } catch (e) {
      return Stream.error(ServerException('فشل الحصول على تيار المحافظ: $e'));
    }
  }

  Future<WalletModel?> getWalletById(String walletId) async {
    final cacheKey = 'wallet_details_$walletId';
    final cachedWallet = _cacheManager.get<WalletModel>(cacheKey);
    if (cachedWallet != null) {
      return cachedWallet;
    }

    try {
      final doc = await _walletsCollection.doc(walletId).get();
      if (!doc.exists) return null;
      final wallet = WalletModel.fromFirestore(doc);
      _cacheManager.set(cacheKey, wallet,
          duration: const Duration(minutes: 10));
      return wallet;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('فشل العثور على المحفظة: $e');
    }
  }

  Future<PaginatedResult<WalletModel>> getAllWallets(String storeId, {DocumentSnapshot? lastDocument}) async {
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
        } catch (e) {
          AppErrorHandler.logSilentError(
            'Malformed wallet doc in list: ${doc.id} | error: $e',
            'wallet_list_corruption'
          );
        }
      }
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PaginatedResult(items: items, lastDocument: lastDoc);
    } catch (e) {
      throw ServerException('فشل استرجاع كل المحافظ: $e');
    }
  }

  Future<double> getTotalBalance(String storeId) async {
    try {
      final summary = await _statsRepository.getStatsSummary(storeId);
      return summary.totalBalance;
    } catch (e) {
      throw ServerException('Failed to get total balance: $e');
    }
  }

  Future<int> getWalletsCount(String storeId) async {
    try {
      final summary = await _statsRepository.getStatsSummary(storeId);
      return summary.activeWallets;
    } catch (e) {
      throw ServerException('Failed to get wallets count: $e');
    }
  }

  // 3️⃣ UPDATE Methods
  Future<void> updateWallet(String walletId, Map<String, dynamic> data) async {
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
      throw ServerException('فشل تحديث المحفظة: $e');
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
      throw ServerException('فشل شحن رصيد المحفظة: $e');
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
          throw DomainException('رصيد المحفظة غير كافٍ.');
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
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('فشل خصم رصيد من المحفظة: $e');
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
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to update wallet active status: $e');
    }
  }

  // 5️⃣ STREAM Methods
  Stream<WalletModel?> watchWallet(String walletId) {
    return _walletsCollection
        .doc(walletId)
        .snapshots()
        .map((doc) => doc.exists ? WalletModel.fromFirestore(doc) : null)
        .handleError((e) {
      return Stream.error(ServerException('Failed to watch wallet: $e'));
    });
  }

  // 6️⃣ RESET Methods
  Future<void> resetLimitsForWallets(List<WalletModel> wallets) async {
    const int chunkSize = 450;
    
    for (var i = 0; i < wallets.length; i += chunkSize) {
      final chunk = wallets.sublist(i, i + chunkSize > wallets.length ? wallets.length : i + chunkSize);
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

      if (walletsToResetInBatch > 0) {
        await batch.commit();
      }
    }

    _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
    for (final wallet in wallets) {
      _cacheManager.clear('wallet_details_${wallet.walletId}');
    }
  }
}
