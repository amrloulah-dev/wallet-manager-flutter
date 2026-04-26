import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_severity.dart';
import '../../core/services/identity_service.dart';
import '../../core/utils/password_hasher.dart';
import '../models/user_permissions.dart';

class EmployeeRepository {
  final FirebaseFirestore _firestore;
  final CollectionReference _usersCollection;

  EmployeeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _usersCollection = (firestore ?? FirebaseFirestore.instance)
            .collection(FirebaseConstants.usersCollection);

  Future<List<UserModel>> getEmployeesByStoreId({
    required String storeId,
    bool activeOnly = true,
  }) async {
    try {
      Query query = _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role,
              isEqualTo: FirebaseConstants.employeeRole);

      if (activeOnly) {
        query = query.where(FirebaseConstants.isActive, isEqualTo: true);
      }

      final snapshot = await query
          .orderBy(FirebaseConstants.createdAt, descending: true)
          .get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw ServerException('Failed to get employees: \$e');
    }
  }

  Future<UserModel?> getEmployeeByPIN({
    required String storeId,
    required String pin,
  }) async {
    try {
      final hashedPin = PasswordHasher.hashPassword(pin);
      final snapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role,
              isEqualTo: FirebaseConstants.employeeRole)
          .where(FirebaseConstants.pin, isEqualTo: hashedPin)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw ServerException('حدث خطأ أثناء التحقق من الرقم السري');
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
    final hashedPin = PasswordHasher.hashPassword(pin);

    final newUser = UserModel(
      userId: newUserId,
      storeId: storeId,
      role: FirebaseConstants.employeeRole,
      fullName: fullName,
      email: null,
      phone: phone,
      firebaseUid: null,
      pin: hashedPin,
      isActive: true,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      permissions: permissions,
      stats: UserStats(),
    );

    await _firestore.runTransaction((transaction) async {
      final storeRef = _firestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId);
      final storeSnap = await transaction.get(storeRef);

      if (!storeSnap.exists) {
        throw ServerException('المتجر غير موجود.');
      }

      final storeData = storeSnap.data()!;
      final maxEmployees = storeData['subscription'] != null
          ? storeData['subscription']['maxEmployees'] ?? 0
          : 0;
      final currentEmployees = storeData['stats'] != null
          ? storeData['stats']['totalEmployees'] ?? 0
          : 0;

      if (currentEmployees >= maxEmployees && maxEmployees != -1) {
        throw ServerException(
            'تم الوصول للحد الأقصى للموظفين ($maxEmployees)');
      }

      // Ensure PIN uniqueness within the transaction
      final pinQuery = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.pin, isEqualTo: hashedPin)
          .limit(1)
          .get();

      if (pinQuery.docs.isNotEmpty) {
        throw ServerException('الرقم السري مستخدم بالفعل');
      }

      transaction.set(_usersCollection.doc(newUserId), newUser.toFirestore());
      transaction
          .update(storeRef, {'stats.totalEmployees': FieldValue.increment(1)});

      // Update Store Stats Summary Document
      final statsSummaryRef = _firestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection('stats')
          .doc('summary');
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
              isEqualTo: FirebaseConstants.employeeRole)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
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

      if (wasActive && storeId != null) {
        final storeRef = _firestore
            .collection(FirebaseConstants.storesCollection)
            .doc(storeId);
        final statsSummaryRef = _firestore
            .collection(FirebaseConstants.storesCollection)
            .doc(storeId)
            .collection('stats')
            .doc('summary');

        final storeSnap = await transaction.get(storeRef);
        final statsSnap = await transaction.get(statsSummaryRef);

        int currentStoreEmployees = 0;
        if (storeSnap.exists) {
          currentStoreEmployees = (storeSnap.data()?['stats']
                  ?['totalEmployees'] as int?) ??
              0;
        }

        int currentSummaryEmployees = 0;
        if (statsSnap.exists) {
          currentSummaryEmployees = (statsSnap.data()?['totalEmployees'] as int?) ?? 0;
        }

        transaction.update(userRef, {
          FirebaseConstants.isActive: false,
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });

        transaction.update(storeRef, {
          'stats.totalEmployees': currentStoreEmployees > 0
              ? currentStoreEmployees - 1
              : 0
        });

        transaction.set(
            statsSummaryRef,
            {
              'totalEmployees': currentSummaryEmployees > 0
                  ? currentSummaryEmployees - 1
                  : 0,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
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
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        throw NotFoundException('Employee');
      }
      final userData = userDoc.data() as Map<String, dynamic>;
      final storeId = userData[FirebaseConstants.storeId];

      final existingEmployee =
          await getEmployeeByPIN(storeId: storeId, pin: newPin);
      if (existingEmployee != null && existingEmployee.userId != userId) {
        throw ValidationException('New PIN is already in use');
      }

      final hashedPin = PasswordHasher.hashPassword(newPin);
      await _usersCollection.doc(userId).update({
        FirebaseConstants.pin: hashedPin,
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      throw ServerException('Failed to reset PIN: \$e');
    }
  }

  Future<void> updateEmployeePermissions({
    required String userId,
    required UserPermissions permissions,
  }) async {
    try {
      await _usersCollection.doc(userId).update({
        'permissions': permissions.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException('Failed to update permissions: $e');
    }
  }

  Stream<List<UserModel>> watchEmployees(String storeId) {
    return _usersCollection
        .where(FirebaseConstants.storeId, isEqualTo: storeId)
        .where(FirebaseConstants.role,
            isEqualTo: FirebaseConstants.employeeRole)
        .orderBy(FirebaseConstants.createdAt, descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList())
        .handleError((error) {
      AppErrorHandler.handle(error, operation: 'EmployeeRepository.watchEmployees');
      throw error;
    });
  }

  Future<void> provisionIdentity(UserModel employee) async {
    try {
      if (employee.phone == null || employee.pin == null) return;
      
      final uid = await IdentityService.provisionIdentity(
        phone: employee.phone!,
        storeId: employee.storeId,
        pin: employee.pin!,
      );

      if (uid != null) {
        await _usersCollection.doc(employee.userId).update({
          'firebaseUid': uid,
        });
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'EmployeeRepository.provisionIdentity',
      );
    }
  }

  Future<void> syncCredential(UserModel employee, String newPin) async {
    try {
      if (employee.phone == null) return;
      
      final hashedPin = newPin.length == 4 ? PasswordHasher.hashPassword(newPin) : newPin;
      
      await IdentityService.updateCredential(
        phone: employee.phone!,
        storeId: employee.storeId,
        newPin: hashedPin, 
      );
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'EmployeeRepository.syncCredential',
      );
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
    }
  }
}
