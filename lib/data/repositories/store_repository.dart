import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/password_hasher.dart';
import '../models/store_model.dart';
import '../models/stats_summary_model.dart';
import '../services/firebase_service.dart';
import '../../services/time_service.dart';

/// Repository for all Firestore operations related to the 'stores' collection.
class StoreRepository {
  final FirebaseService _firebaseService;

  /// Constructor with optional dependency injection for testing.
  StoreRepository({FirebaseService? firebaseService})
      : _firebaseService = firebaseService ?? FirebaseService();

  /// Private getter for the Firestore instance.
  FirebaseFirestore get _firestore => _firebaseService.firestore;

  /// Private getter for the 'stores' collection reference.
  CollectionReference<Map<String, dynamic>> get _storesCollection =>
      _firestore.collection(FirebaseConstants.storesCollection);

  // ===========================
  // Create Methods
  // ===========================

  /// Creates a new store document in Firestore.
  /// Also initializes the accompanying statistics document atomically.
  ///
  /// **NOTE:** This method now enforces a "Trial Mode" for all new stores.
  /// It overwrites any license information passed in the [store] object with
  /// a generated trial license.
  Future<void> createStore(StoreModel store, {bool isEligibleForTrial = true, WriteBatch? batch}) async {
    try {
      final activeBatch = batch ?? _firestore.batch();

      // --- Generate Subscription based on trial eligibility ---
      final StoreSubscription subscription;
      if (isEligibleForTrial) {
        // H001: Trial tier gets generous limits
        subscription = StoreSubscription(
          planId: SubscriptionPlan.trial, // ENUM refactor
          status: SubscriptionStatus.active,
          endDate: DateTime.now().add(const Duration(days: 14)),
          trialConsumed: false,
          maxWallets: 999,
          maxEmployees: 999,
          smsEnabled: true,
        );
      } else {
        // H002: Device-ineligible users land on Free tier directly
        subscription = StoreSubscription(
          planId: SubscriptionPlan.free, // ENUM refactor
          status: SubscriptionStatus.active,
          endDate: null,
          trialConsumed: true,
          maxWallets: 3,
          maxEmployees: 1,
          smsEnabled: false,
        );
      }

      final storeWithTrial = store.copyWith(
        subscription: subscription,
      );
      // -----------------------------

      final storeData = storeWithTrial.toFirestore();
      storeData[FirebaseConstants.createdAt] = FieldValue.serverTimestamp();
      storeData[FirebaseConstants.updatedAt] = FieldValue.serverTimestamp();

      // 1. Set Store Document
      activeBatch.set(_storesCollection.doc(storeWithTrial.storeId), storeData);

      // 2. Initialize Stats Document
      // Note: We use the same sub-collection path structure as found in StatsRepository:
      // stores/{storeId}/stats/summary
      final statsRef = _storesCollection
          .doc(storeWithTrial.storeId)
          .collection(FirebaseConstants.statsCollection)
          .doc(FirebaseConstants.summaryDoc);

      final initialStats = StatsSummaryModel.empty();
      final statsData = initialStats.toMap();
      statsData['lastUpdated'] = FieldValue.serverTimestamp();
      
      activeBatch.set(statsRef, statsData);

      // Commit all changes atomically only if we created the batch
      if (batch == null) {
        await activeBatch.commit();
      }
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.createStore');
      throw ServerException('فشل إنشاء المحل: ${e.message}', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.createStore');
      throw ServerException('حدث خطأ غير متوقع أثناء إنشاء المحل: $e');
    }
  }

  // ===========================
  // Read Methods
  // ===========================

  /// Fetches a single store by its document ID.
  Future<StoreModel?> getStoreById(String storeId) async {
    try {
      final doc = await _storesCollection.doc(storeId).get();
      if (doc.exists) {
        return StoreModel.fromFirestore(doc);
      }
      return null;
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.getStoreById');
      throw ServerException('فشل في جلب بيانات المحل: ${e.message}',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.getStoreById');
      throw ServerException('حدث خطأ غير متوقع: $e');
    }
  }

  /// Finds a store associated with a specific owner ID.
  Future<StoreModel?> getStoreByOwnerId(String ownerId) async {
    try {
      final querySnapshot = await _storesCollection
          .where(FirebaseConstants.ownerIdField, isEqualTo: ownerId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return StoreModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.getStoreByOwnerId');
      throw ServerException('فشل في البحث عن المحل: ${e.message}',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.getStoreByOwnerId');
      throw ServerException('حدث خطأ غير متوقع: $e');
    }
  }

  /// Finds a store associated with a specific owner email.
  Future<StoreModel?> getStoreByEmail(String email) async {
    try {
      final querySnapshot = await _storesCollection
          .where(FirebaseConstants.ownerEmail, isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return StoreModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.getStoreByEmail');
      throw ServerException('فشل في البحث عن المحل: ${e.message}',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.getStoreByEmail');
      throw ServerException('حدث خطأ غير متوقع: $e');
    }
  }

  /// Checks if a store document exists for the given ID.
  Future<bool> storeExists(String storeId) async {
    try {
      final doc = await _storesCollection.doc(storeId).get();
      return doc.exists;
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.storeExists');
      return false;
    }
  }

  // ===========================
  // Update Methods
  // ===========================

  /// Updates a store document with the given data.
  Future<void> updateStore(String storeId, Map<String, dynamic> data) async {
    try {
      final updateData = {
        ...data,
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp()
      };
      await _storesCollection.doc(storeId).update(updateData);
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.updateStore');
      throw ServerException('فشل تحديث بيانات المحل: ${e.message}',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.updateStore');
      throw ServerException('حدث خطأ غير متوقع أثناء التحديث: $e');
    }
  }

  /// Updates the owner information for a specific store.
  Future<void> updateOwnerInfo({
    required String storeId,
    required String ownerId,
    required String ownerName,
    required String ownerEmail,
    String? ownerPhoto,
  }) async {
    final data = {
      FirebaseConstants.ownerIdField: ownerId,
      FirebaseConstants.ownerName: ownerName,
      FirebaseConstants.ownerEmail: ownerEmail,
    };
    if (ownerPhoto != null) {
      data[FirebaseConstants.ownerPhoto] = ownerPhoto;
    }
    await updateStore(storeId, data);
  }

  /// Updates the statistics for a specific store.
  Future<void> updateStoreStats({
    required String storeId,
    int? incrementTotalWallets,
    int? incrementActiveWallets,
    int? incrementTotalTransactionsToday,
    double? incrementTotalCommissionToday,
  }) async {
    try {
      final Map<String, dynamic> statsData = {
        '${FirebaseConstants.stats}.lastUpdated': FieldValue.serverTimestamp(),
      };
      if (incrementTotalWallets != null) {
        statsData['${FirebaseConstants.stats}.${FirebaseConstants.totalWallets}'] =
            FieldValue.increment(incrementTotalWallets);
      }
      if (incrementActiveWallets != null) {
        statsData['${FirebaseConstants.stats}.${FirebaseConstants.activeWallets}'] =
            FieldValue.increment(incrementActiveWallets);
      }
      if (incrementTotalTransactionsToday != null) {
        statsData['${FirebaseConstants.stats}.${FirebaseConstants.totalTransactionsToday}'] =
            FieldValue.increment(incrementTotalTransactionsToday);
      }
      if (incrementTotalCommissionToday != null) {
        statsData['${FirebaseConstants.stats}.${FirebaseConstants.totalCommissionToday}'] =
            FieldValue.increment(incrementTotalCommissionToday);
      }
      await _storesCollection.doc(storeId).update(statsData);
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.updateStoreStats');
      throw ServerException('فشل تحديث إحصائيات المحل: ${e.message}',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.updateStoreStats');
      throw ServerException('حدث خطأ غير متوقع: $e');
    }
  }

  // ===========================
  // Password Methods
  // ===========================

  /// Verifies if the provided password matches the store's hashed password.
  Future<bool> verifyStorePassword(String storeId, String password) async {
    try {
      final store = await getStoreById(storeId);
      if (store == null) {
        throw NotFoundException('المحل');
      }
      return PasswordHasher.verifyPassword(password, store.storePassword);
    } catch (e) {
      rethrow; // Rethrow the original exception (e.g., NotFoundException)
    }
  }

  /// Updates the store's password.
  Future<void> updateStorePassword(String storeId, String newPassword) async {
    final hashedPassword = PasswordHasher.hashPassword(newPassword);
    await updateStore(
        storeId, {FirebaseConstants.storePassword: hashedPassword});
  }

  // ===========================
  // Subscription Methods
  // ===========================

  /// Checks if the store's current subscription is active and not expired.
  Future<bool> isSubscriptionValid(String storeId) async {
    try {
      final store = await getStoreById(storeId);
      if (store == null) return false;
      // T058: Pure POJO — time resolved here rather than inside StoreSubscription
      return store.subscription.status == SubscriptionStatus.active &&
          !store.subscription.isExpiredAt(TimeService.now());
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.isSubscriptionValid');
      return false;
    }
  }

  /// Updates the status of a store's subscription.
  Future<void> updateSubscriptionStatus(String storeId, SubscriptionStatus status) async {
    try {
      await _storesCollection.doc(storeId).update({
        'subscription.status': status.name,
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.updateSubscriptionStatus');
      throw ServerException('فشل تحديث حالة الاشتراك: ${e.message}',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.updateSubscriptionStatus');
      throw ServerException('حدث خطأ غير متوقع: $e');
    }
  }

  // ===========================
  // Stream Methods
  // ===========================

  Stream<StoreModel?> watchStore(String storeId) {
    return _storesCollection.doc(storeId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return StoreModel.fromFirestore(snapshot);
      }
      return null;
    }).handleError((error) {
      AppErrorHandler.handle(error, operation: 'StoreRepository.watchStore');
      throw error;
    });
  }

  Future<List<StoreModel>> getStoresByPassword(String password) async {
    try {
      final hashedPassword = PasswordHasher.hashPassword(password);
      final querySnapshot = await _storesCollection
          .where(FirebaseConstants.storePassword, isEqualTo: hashedPassword)
          .limit(1)
          .get();
      return querySnapshot.docs
          .map((doc) => StoreModel.fromFirestore(doc))
          .toList();
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'StoreRepository.getStoresByPassword');
      throw ServerException('فشل البحث عن المحل: $e');
    }
  }
}
