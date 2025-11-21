import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/wallet_model.dart';
import '../services/firebase_service.dart';

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

  // 1️⃣ CREATE Methods
  Future<void> createWallet(WalletModel wallet) async {
    try {
      await _walletsCollection.doc(wallet.walletId).set(wallet.toFirestore());
      await _statsRepository.updateStatsOnWalletChange(
        wallet.storeId,
        countChange: 1,
        balanceChange: wallet.balance,
      );
      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_0_'));
    } catch (e) {
      throw ServerException('فشل إنشاء المحفظة: $e');
    }
  }

  // 2️⃣ READ Methods
  Future<Map<String, dynamic>> getWalletsByStoreIdPaginated(
    String storeId, {
    bool activeOnly = true,
    int limit = 15,
    DocumentSnapshot? lastDoc,
    String? walletType,
    String? walletStatus,
  }) async {
    final cacheKey = 'wallets_page_0_${storeId}_${walletType}_$walletStatus';
    // Only use cache for the first page
    if (lastDoc == null) {
      final cachedResult = _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cachedResult != null) {
        return cachedResult;
      }
    }

    try {
      Query query =
          _walletsCollection.where(FirebaseConstants.storeId, isEqualTo: storeId);
      if (activeOnly) {
        query = query.where(FirebaseConstants.isActive, isEqualTo: true);
      }
      if (walletType != null) {
        query = query.where(FirebaseConstants.walletType, isEqualTo: walletType);
      }
      if (walletStatus != null) {
        query = query.where(FirebaseConstants.walletStatus, isEqualTo: walletStatus);
      }

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.limit(limit).get();
      final wallets = snapshot.docs.map((doc) => WalletModel.fromFirestore(doc)).toList();
      final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      final result = {
        'wallets': wallets,
        'lastDoc': newLastDoc,
      };

      if (lastDoc == null) {
        _cacheManager.set(cacheKey, result);
      }

      return result;
    } catch (e) {
      throw ServerException('فشل استرجاع المحافظ: $e');
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
      _cacheManager.set(cacheKey, wallet, duration: const Duration(minutes: 10));
      return wallet;
    } catch (e) {
      throw ServerException('فشل العثور على المحفظة: $e');
    }
  }

  Future<List<WalletModel>> getAllWallets(String storeId) async {
    try {
      final snapshot = await _walletsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => WalletModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw ServerException('فشل استرجاع كل المحافظ: $e');
    }
  }

  Future<double> getTotalBalance(String storeId) async {
    try {
      final snapshot = await _walletsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .get();
      
      double totalBalance = 0.0;
      for (var doc in snapshot.docs) {
        totalBalance += (doc.data() as Map<String, dynamic>)['balance'] ?? 0.0;
      }
      return totalBalance;

    } catch (e) {
      return 0.0;
    }
  }

  Future<int> getWalletsCount(String storeId) async {
    try {
      final snapshot = await _walletsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // 3️⃣ UPDATE Methods
  Future<void> updateWallet(
      String walletId, Map<String, dynamic> data) async {
    try {
      final updateData = {...data, FirebaseConstants.updatedAt: FieldValue.serverTimestamp()};
      await _walletsCollection.doc(walletId).update(updateData);
      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_0_'));
      _cacheManager.clear('wallet_details_$walletId');
    } catch (e) {
      throw ServerException('فشل تحديث المحفظة: e');
    }
  }

  Future<void> updateWalletBalance(String walletId, double amount) async {
    try {
      final wallet = await getWalletById(walletId);
      if (wallet == null) throw NotFoundException('Wallet');

      await _walletsCollection.doc(walletId).update({
        'balance': FieldValue.increment(amount),
      });
      await _statsRepository.updateStatsOnWalletChange(wallet.storeId, balanceChange: amount);
      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_0_'));
      _cacheManager.clear('wallet_details_$walletId');
    } catch (e) {
      throw ServerException('فشل تحديث رصيد المحفظة: e');
    }
  }

  // ... other update methods like reset limits, etc. should also clear cache ...

  // 4️⃣ DELETE Methods
  Future<void> deleteWallet(String walletId) async {
    await setWalletActiveStatus(walletId, false);
  }

  Future<void> setWalletActiveStatus(String walletId, bool isActive) async {
    try {
      final wallet = await getWalletById(walletId);
      if (wallet == null) throw NotFoundException('Wallet');

      await updateWallet(walletId, {FirebaseConstants.isActive: isActive});
      
      await _statsRepository.updateStatsOnWalletChange(
        wallet.storeId,
        countChange: isActive ? 1 : -1,
        balanceChange: isActive ? wallet.balance : -wallet.balance,
      );

    } catch (e) {
      throw ServerException('فشل تحديث حالة المحفظة: $e');
    }
  }

  // 5️⃣ STREAM Methods
  Stream<WalletModel?> watchWallet(String walletId) {
    return _walletsCollection
        .doc(walletId)
        .snapshots()
        .map((doc) => doc.exists ? WalletModel.fromFirestore(doc) : null)
        .handleError((e) {
      return Stream.error(ServerException('فشل مراقبة المحفظة: $e'));
    });
  }

  // 6️⃣ RESET Methods
  Future<void> resetLimitsForWallets(List<WalletModel> wallets) async {
    final batch = _firestore.batch();
    var walletsToResetCount = 0;

    for (final wallet in wallets) {
      final updates = <String, dynamic>{};
      final now = Timestamp.now();

      if (wallet.needsDailyReset) {
        updates['${FirebaseConstants.sendLimits}.dailyUsed'] = 0.0;
        updates['${FirebaseConstants.receiveLimits}.dailyUsed'] = 0.0;
        updates['${FirebaseConstants.lastDailyReset}'] = now;
      }
      if (wallet.needsMonthlyReset) {
        updates['${FirebaseConstants.sendLimits}.monthlyUsed'] = 0.0;
        updates['${FirebaseConstants.receiveLimits}.monthlyUsed'] = 0.0;
        updates['${FirebaseConstants.lastMonthlyReset}'] = now;
      }

      if (updates.isNotEmpty) {
        final walletRef = _walletsCollection.doc(wallet.walletId);
        batch.update(walletRef, updates);
        walletsToResetCount++;
      }
    }

    if (walletsToResetCount > 0) {
      await batch.commit();
      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_0_'));
      for (final wallet in wallets) {
        _cacheManager.clear('wallet_details_${wallet.walletId}');
      }
    }
  }
}
