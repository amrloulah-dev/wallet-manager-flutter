import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_severity.dart';
import '../../core/services/identity_service.dart';
import '../../core/utils/password_hasher.dart';
import '../models/user_permissions.dart';
import '../../core/enums/user_enums.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/data/services/firebase_service.dart';

class EmployeeRepository {
  final FirebaseFirestore _firestore;
  final CollectionReference _usersCollection;

  EmployeeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? sl<FirebaseService>().firestore,
        _usersCollection = (firestore ?? sl<FirebaseService>().firestore)
            .collection(FirebaseConstants.usersCollection);

  Future<List<UserModel>> getEmployeesByStoreId({
    required String storeId,
    String? searchQuery,
    bool activeOnly = true,
    int limit = 20,
  }) async {
    try {
      Query query = _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role,
              isEqualTo: UserRole.employee.name); // ENUM refactor

      if (activeOnly) {
        query = query.where(FirebaseConstants.isActive, isEqualTo: true);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where(FirebaseConstants.fullName,
                isGreaterThanOrEqualTo: searchQuery)
            .where(FirebaseConstants.fullName,
                isLessThanOrEqualTo: '$searchQuery\uf8ff');
      }

      final snapshot =
          await query.orderBy(FirebaseConstants.fullName).limit(limit).get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'EmployeeRepository.getEmployeesByStoreId');
      throw ServerException('employee_error_fetch_failed');
    }
  }

  Future<UserModel?> getEmployeeByPIN({
    required String storeId,
    required String pin,
  }) async {
    try {
      // 1. Fetch all active employees for this store
      final snapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role, isEqualTo: UserRole.employee.name)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .get();

      // 2. Verify PIN manually for each
      for (final doc in snapshot.docs) {
        final user = UserModel.fromFirestore(doc);
        if (user.pin != null) {
          if (await PasswordHasher.verifyPassword(pin, user.pin!)) {
            return user;
          }
          // Legacy check if needed
          if (user.pin == pin) return user;
        }
      }
      return null;
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'EmployeeRepository.getEmployeeByPIN');
      throw ServerException('employee_error_fetch_failed');
    }
  }

  Future<UserModel> addEmployee({
    required String storeId,
    required String fullName,
    required String phone,
    required String pin,
    required UserPermissions permissions,
  }) async {
    final newUserId = _usersCollection.doc().id;
    final hashedPin = await PasswordHasher.hashPassword(pin);

    final newUser = UserModel(
      userId: newUserId,
      storeId: storeId,
      role: UserRole.employee, // ENUM refactor
      fullName: fullName,
      email: null,
      phone: phone,
      firebaseUid: null,
      pin: hashedPin,
      isActive: true,
      createdAt: null, // Set by FieldValue.serverTimestamp
      lastLogin: null, // Set by FieldValue.serverTimestamp
      permissions: permissions,
      stats: UserStats(),
    );

    // PIN uniqueness is enforced atomically via a deterministic pin-lock document
    // inside the transaction — eliminating the check-then-act race window.
    final pinLockRef = _firestore.doc(
      FirebaseConstants.pinLockPath(storeId, hashedPin),
    );

    await _firestore.runTransaction((transaction) async {
      // 1. Atomic PIN uniqueness check
      final pinLockSnap = await transaction.get(pinLockRef);
      if (pinLockSnap.exists) {
        throw ServerException('employee_error_pin_already_used');
      }

      // 2. Employee capacity check
      final storeRef = _firestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId);
      final storeSnap = await transaction.get(storeRef);

      if (!storeSnap.exists) {
        throw ServerException('store_error_not_found');
      }

      final storeData = storeSnap.data()!;

      // ✅ التعديل هنا: القراءة من settings بدلاً من subscription
      final maxEmployees = storeData['settings'] != null
          ? storeData['settings']['maxEmployees'] ?? 0
          : 0;

      final currentEmployees = storeData['stats'] != null
          ? storeData['stats']['totalEmployees'] ?? 0
          : 0;

      if (currentEmployees >= maxEmployees && maxEmployees != -1) {
        throw ServerException('employee_error_max_limit_reached');
      }

      // 3. Write employee doc
      final userData = newUser.toFirestore();
      userData[FirebaseConstants.createdAt] = FieldValue.serverTimestamp();
      userData[FirebaseConstants.lastLogin] = FieldValue.serverTimestamp();
      userData[FirebaseConstants.updatedAt] = FieldValue.serverTimestamp();

      transaction.set(_usersCollection.doc(newUserId), userData);

      // 4. Claim the PIN lock atomically
      transaction.set(pinLockRef, {
        'userId': newUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Update Store Stats Summary Document
      final statsSummaryRef = _firestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection(FirebaseConstants.statsCollection)
          .doc(FirebaseConstants.summaryDoc);

      transaction.set(
          statsSummaryRef,
          {
            'totalEmployees': FieldValue.increment(1),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    return newUser;
  }

  Future<int> getEmployeesCount(String storeId) async {
    try {
      final snapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role,
              isEqualTo: UserRole.employee.name) // ENUM refactor
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e, stack) {
      AppErrorHandler.logSilentError(
          e.toString(), 'EmployeeRepository.getEmployeesCount',
          stackTrace: stack);
      throw ServerException('employee_error_fetch_failed');
    }
  }

  Future<void> deactivateEmployee(String userId) async {
    final userRef = _usersCollection.doc(userId);

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw NotFoundException('Employee');
      }

      final userData = userSnap.data() as Map<String, dynamic>;
      final wasActive = userData[FirebaseConstants.isActive] == true;
      final storeId = userData[FirebaseConstants.storeId];
      final hashedPin = userData[FirebaseConstants.pin] as String?;

      if (wasActive && storeId != null) {
        final storeRef = _firestore
            .collection(FirebaseConstants.storesCollection)
            .doc(storeId);
        final statsSummaryRef = _firestore
            .collection(FirebaseConstants.storesCollection)
            .doc(storeId)
            .collection(FirebaseConstants.statsCollection)
            .doc(FirebaseConstants.summaryDoc);

        transaction.update(userRef, {
          FirebaseConstants.isActive: false,
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });

        transaction.update(storeRef, {
          'stats.totalEmployees': FieldValue.increment(-1),
          'stats.lastUpdated': FieldValue.serverTimestamp(),
        });

        transaction.update(statsSummaryRef, {
          'totalEmployees': FieldValue.increment(-1),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Release the PIN lock so the PIN can be reused by another employee.
        if (hashedPin != null && hashedPin.isNotEmpty) {
          final pinLockRef = _firestore.doc(
            FirebaseConstants.pinLockPath(storeId, hashedPin),
          );
          transaction.delete(pinLockRef);
        }
      } else {
        transaction.update(userRef, {
          FirebaseConstants.isActive: false,
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<bool> resetEmployeePIN({
    required String userId,
    required String newPin,
  }) async {
    if (newPin.length != 4) {
      throw ValidationException('PIN must be 4 digits');
    }

    try {
      final newHashedPin = await PasswordHasher.hashPassword(newPin);

      await _firestore.runTransaction((transaction) async {
        // 1. Read employee doc inside the transaction
        final userSnap = await transaction.get(_usersCollection.doc(userId));
        if (!userSnap.exists) {
          throw NotFoundException('Employee');
        }
        final userData = userSnap.data() as Map<String, dynamic>;
        final storeId = userData[FirebaseConstants.storeId] as String?;
        final oldHashedPin = userData[FirebaseConstants.pin] as String?;

        if (storeId == null || storeId.isEmpty) {
          throw ServerException('employee_error_store_unresolved');
        }

        // 2. Atomic uniqueness check via pin-lock document
        final newPinLockRef = _firestore.doc(
          FirebaseConstants.pinLockPath(storeId, newHashedPin),
        );
        final newPinLockSnap = await transaction.get(newPinLockRef);

        // Allow if the lock belongs to this employee (same userId) — idempotent reset
        if (newPinLockSnap.exists &&
            newPinLockSnap.data()?['userId'] != userId) {
          throw ValidationException('employee_error_pin_already_used');
        }

        // 3. Release old pin lock (only if PIN is actually changing)
        if (oldHashedPin != null &&
            oldHashedPin.isNotEmpty &&
            oldHashedPin != newHashedPin) {
          final oldPinLockRef = _firestore.doc(
            FirebaseConstants.pinLockPath(storeId, oldHashedPin),
          );
          transaction.delete(oldPinLockRef);
        }

        // 4. Claim new pin lock
        transaction.set(newPinLockRef, {
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 5. Update employee PIN
        transaction.update(_usersCollection.doc(userId), {
          FirebaseConstants.pin: newHashedPin,
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'EmployeeRepository.resetEmployeePIN',
      );
      if (e is AppException) rethrow;
      throw ServerException('employee_error_reset_pin_failed');
    }
  }

  Future<void> updateEmployeePermissions({
    required String userId,
    required UserPermissions permissions,
  }) async {
    try {
      await _usersCollection.doc(userId).update({
        'permissions': permissions.toMap(),
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'EmployeeRepository.updateEmployeePermissions',
      );
      throw ServerException('employee_error_update_permissions_failed');
    }
  }

  Stream<List<UserModel>> watchEmployees(String storeId,
      {String? searchQuery, bool activeOnly = true}) {
    Query query = _usersCollection
        .where(FirebaseConstants.storeId, isEqualTo: storeId)
        .where(FirebaseConstants.role,
            isEqualTo: UserRole.employee.name); // ENUM refactor

    if (activeOnly) {
      query = query.where(FirebaseConstants.isActive, isEqualTo: true);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Basic prefix search: query >= search && query <= search + \uf8ff
      // Note: This is case-sensitive in Firestore.
      // For better search, a separate lowercase field or Algolia is needed,
      // but this is a standard Firestore optimization step.
      query = query
          .where(FirebaseConstants.fullName,
              isGreaterThanOrEqualTo: searchQuery)
          .where(FirebaseConstants.fullName,
              isLessThanOrEqualTo: '$searchQuery\uf8ff');
    }

    return query
        .orderBy(FirebaseConstants.fullName)
        .limit(20) // Limit results to prevent billing explosions
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList())
        .handleError((error) {
      AppErrorHandler.handle(error,
          operation: 'EmployeeRepository.watchEmployees');
      throw error;
    });
  }

  Future<void> provisionIdentity(UserModel employee) async {
    try {
      if (employee.phone == null || employee.pin == null) return;

      final uid = await IdentityService.provisionIdentity(
        phone: employee.phone!,
        // ignore: unnecessary_cast
        storeId: employee.storeId as String,
        pin: employee.pin!,
      );

      if (uid != null) {
        await _usersCollection.doc(employee.userId).update({
          'firebaseUid': uid,
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'EmployeeRepository.provisionIdentity',
      );
      rethrow;
    }
  }

  Future<void> syncCredential(UserModel employee, String newPin) async {
    try {
      if (employee.phone == null) return;

      final hashedPin = newPin.length == 4
          ? await PasswordHasher.hashPassword(newPin)
          : newPin;

      await IdentityService.updateCredential(
        phone: employee.phone!,
        storeId: employee.storeId,
        newPin: hashedPin,
      );

      await _usersCollection.doc(employee.userId).update({
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'EmployeeRepository.syncCredential',
      );
      rethrow;
    }
  }

  Future<void> cleanupIdentity(UserModel employee) async {
    try {
      if (employee.phone == null) return;
      await IdentityService.deleteIdentity(
        phone: employee.phone!,
        storeId: employee.storeId,
      );
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'EmployeeRepository.cleanupIdentity',
      );
      rethrow;
    }
  }
}
