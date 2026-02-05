import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/password_hasher.dart';
import '../models/user_model.dart';
import '../models/user_permissions.dart';
import '../services/firebase_service.dart';

/// Repository for all Firestore operations related to the 'users' collection.
class UserRepository {
  final FirebaseService _firebaseService;

  /// Constructor with optional dependency injection for testing.
  UserRepository({FirebaseService? firebaseService})
      : _firebaseService = firebaseService ?? FirebaseService();

  /// Private getter for the Firestore instance.
  FirebaseFirestore get _firestore => _firebaseService.firestore;

  /// Private getter for the 'users' collection reference.
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(FirebaseConstants.usersCollection);

  // ===========================
  // Create Methods
  // ===========================

  /// Creates a new user document in Firestore.
  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.userId).set(user.toFirestore());
    } on FirebaseException catch (e) {
      throw ServerException('فشل إنشاء المستخدم: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع أثناء إنشاء المستخدم.');
    }
  }

  // ===========================
  // Read Methods
  // ===========================

  /// Fetches a single user by their document ID.
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } on FirebaseException catch (e) {
      throw ServerException('فشل في جلب بيانات المستخدم: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع.');
    }
  }

  /// Finds a user associated with a specific Firebase UID.
  Future<UserModel?> getUserByFirebaseUid(String firebaseUid) async {
    try {
      final querySnapshot = await _usersCollection
          .where(FirebaseConstants.firebaseUidField, isEqualTo: firebaseUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e) {
      throw ServerException('فشل في البحث عن المستخدم: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع.');
    }
  }

  /// Finds a user by email for a specific store.
  Future<UserModel?> getUserByEmailAndStoreId(
      String email, String storeId) async {
    try {
      final querySnapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to find user by email: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while finding user by email.');
    }
  }

  /// Fetches all active users for a given store ID.
  Future<List<UserModel>> getUsersByStoreId(String storeId) async {
    try {
      final querySnapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .get();
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException('فشل في جلب المستخدمين: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع.');
    }
  }

  /// Fetches all active employees for a given store ID, ordered by name.
  Future<List<UserModel>> getEmployeesByStoreId(String storeId) async {
    try {
      final querySnapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role,
              isEqualTo: FirebaseConstants.employeeRole)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .orderBy(FirebaseConstants.fullName)
          .get();
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException('فشل في جلب الموظفين: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع.');
    }
  }

  /// Fetches the owner of a specific store.
  Future<UserModel?> getOwnerByStoreId(String storeId) async {
    try {
      final querySnapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role, isEqualTo: FirebaseConstants.ownerRole)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e) {
      throw ServerException('فشل في جلب بيانات المالك: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع.');
    }
  }

  /// Checks if a user document exists for the given ID.
  Future<bool> userExists(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Checks if a user exists with the given Firebase UID.
  Future<bool> userExistsByFirebaseUid(String firebaseUid) async {
    try {
      final user = await getUserByFirebaseUid(firebaseUid);
      return user != null;
    } catch (e) {
      return false;
    }
  }

  // ===========================
  // Update Methods
  // ===========================

  /// Updates a user document with the given data.
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final updateData = {
        ...data,
        FirebaseConstants.updatedAt: Timestamp.now()
      };
      await _usersCollection.doc(userId).update(updateData);
    } on FirebaseException catch (e) {
      throw ServerException('فشل تحديث بيانات المستخدم: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع أثناء التحديث.');
    }
  }

  /// Updates the last login timestamp for a user.
  Future<void> updateLastLogin(String userId) async {
    try {
      await _usersCollection
          .doc(userId)
          .update({FirebaseConstants.lastLogin: Timestamp.now()});
    } on FirebaseException catch (e) {
      throw ServerException('فشل تحديث وقت تسجيل الدخول: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع.');
    }
  }

  /// Updates a user's profile information.
  Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? photoURL,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data[FirebaseConstants.fullName] = fullName;
    if (phone != null) data[FirebaseConstants.phoneNumber] = phone;
    if (photoURL != null) data[FirebaseConstants.ownerPhoto] = photoURL;

    if (data.isNotEmpty) {
      await updateUser(userId, data);
    }
  }

  /// Sets the active status of a user.
  Future<void> setUserActiveStatus(String userId, bool isActive) async {
    await updateUser(userId, {FirebaseConstants.isActive: isActive});
  }

  // ===========================
  // Employee PIN Methods
  // ===========================

  /// Verifies an employee's PIN.
  Future<bool> verifyEmployeePin(String userId, String pin) async {
    try {
      final user = await getUserById(userId);
      if (user == null) {
        throw NotFoundException('المستخدم');
      }
      if (!user.isEmployee) {
        throw PermissionDeniedException();
      }
      if (user.pin == null) {
        return false; // No PIN set
      }
      return PasswordHasher.verifyPassword(pin, user.pin!);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates an employee's PIN.
  Future<void> updateEmployeePin(String userId, String newPin) async {
    final hashedPassword = PasswordHasher.hashPassword(newPin);
    await updateUser(userId, {FirebaseConstants.pin: hashedPassword});
  }

  // ===========================
  // Permissions Methods
  // ===========================

  /// Updates the permissions for an employee.
  Future<void> updateEmployeePermissions(
      String userId, UserPermissions permissions) async {
    final user = await getUserById(userId);
    if (user == null || !user.isEmployee) {
      throw NotFoundException('الموظف');
    }
    await updateUser(
        userId, {FirebaseConstants.permissions: permissions.toMap()});
  }

  /// Checks if a user has a specific permission.
  Future<bool> hasPermission(String userId, String permission) async {
    final user = await getUserById(userId);
    if (user == null) return false;
    if (user.isOwner) return true; // Owners have all permissions

    if (user.isEmployee && user.permissions != null) {
      final permissionsMap = user.permissions!.toMap();
      if (permissionsMap.containsKey(permission)) {
        return permissionsMap[permission] as bool;
      }
    }
    return false;
  }

  // ===========================
  // Employee Stats Methods
  // ===========================

  /// Updates an employee's statistics using FieldValue increments.
  Future<void> updateEmployeeStats({
    required String userId,
    int? incrementTransactions,
    double? incrementCommission,
    int? incrementDebts,
  }) async {
    try {
      final user = await getUserById(userId);
      if (user == null || !user.isEmployee) {
        throw NotFoundException('الموظف');
      }

      final statsData = <String, dynamic>{
        '${FirebaseConstants.stats}.${FirebaseConstants.lastTransactionDate}':
            Timestamp.now(),
      };
      if (incrementTransactions != null) {
        statsData[
                '${FirebaseConstants.stats}.${FirebaseConstants.totalTransactions}'] =
            FieldValue.increment(incrementTransactions);
      }
      if (incrementCommission != null) {
        statsData[
                '${FirebaseConstants.stats}.${FirebaseConstants.totalCommission}'] =
            FieldValue.increment(incrementCommission);
      }
      if (incrementDebts != null) {
        statsData[
                '${FirebaseConstants.stats}.${FirebaseConstants.totalDebtsCreated}'] =
            FieldValue.increment(incrementDebts);
      }

      await _usersCollection.doc(userId).update(statsData);
    } on FirebaseException catch (e) {
      throw ServerException('فشل تحديث إحصائيات الموظف: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع.');
    }
  }

  // ===========================
  // Delete Methods
  // ===========================

  /// Soft deletes a user by setting `isActive` to false.
  Future<void> deleteUser(String userId) async {
    await setUserActiveStatus(userId, false);
  }

  /// Permanently deletes a user document from Firestore.
  Future<void> hardDeleteUser(String userId) async {
    try {
      await _usersCollection.doc(userId).delete();
    } on FirebaseException catch (e) {
      throw ServerException('فشل حذف المستخدم: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع أثناء الحذف.');
    }
  }

  // ===========================
  // Stream Methods
  // ===========================

  /// Provides a real-time stream of a user's data.
  Stream<UserModel?> watchUser(String userId) {
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserModel.fromFirestore(snapshot);
      }
      return null;
    }).handleError((error) {});
  }

  /// Provides a real-time stream of active employees for a store.
  Stream<List<UserModel>> watchEmployees(String storeId) {
    return _usersCollection
        .where(FirebaseConstants.storeId, isEqualTo: storeId)
        .where(FirebaseConstants.role,
            isEqualTo: FirebaseConstants.employeeRole)
        .where(FirebaseConstants.isActive, isEqualTo: true)
        .orderBy(FirebaseConstants.fullName)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList())
        .handleError((error) {
      return <UserModel>[];
    });
  }

  // ===========================
  // Batch Operations
  // ===========================

  /// Creates multiple users in a single batch operation (for testing/seeding).
  Future<void> createMultipleUsers(List<UserModel> users) async {
    try {
      final batch = _firestore.batch();
      for (final user in users) {
        final docRef = _usersCollection.doc(user.userId);
        batch.set(docRef, user.toFirestore());
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('فشل إنشاء المستخدمين دفعة واحدة: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException('حدث خطأ غير متوقع.');
    }
  }
}
