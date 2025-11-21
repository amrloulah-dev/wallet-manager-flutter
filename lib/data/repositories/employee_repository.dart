
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/password_hasher.dart';

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
          .where(FirebaseConstants.role, isEqualTo: FirebaseConstants.employeeRole);

      if (activeOnly) {
        query = query.where(FirebaseConstants.isActive, isEqualTo: true);
      }

      final snapshot = await query.orderBy(FirebaseConstants.createdAt, descending: true).get();
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
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
          .where(FirebaseConstants.role, isEqualTo: FirebaseConstants.employeeRole)
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

  Future<void> addEmployee({
    required String storeId,
    required String fullName,
    required String phone,
    required String pin,
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
      firebaseUid: '', // Initially empty
      pin: hashedPin,
      isActive: true,
      createdAt: Timestamp.now(),
      lastLogin: Timestamp.now(),
      permissions: UserPermissions.defaultPermissions(),
      stats: UserStats(),
    );

    await _firestore.runTransaction((transaction) async {
      final storeRef = _firestore.collection(FirebaseConstants.storesCollection).doc(storeId);
      final storeSnap = await transaction.get(storeRef);

      if (!storeSnap.exists) {
        throw ServerException('المتجر غير موجود.');
      }

      final storeData = storeSnap.data()!;
      final maxEmployees = storeData['settings']?['maxEmployees'] ?? 5;
      
      // We need to get the current count of employees within the transaction
      final employeesQuery = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role, isEqualTo: FirebaseConstants.employeeRole)
          .where(FirebaseConstants.isActive, isEqualTo: true)
          .get();
      
      final currentCount = employeesQuery.docs.length;

      if (currentCount >= maxEmployees) {
        throw ServerException('تم الوصول للحد الأقصى من الموظفين');
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
      transaction.update(storeRef, {'stats.totalEmployees': FieldValue.increment(1)});
    });
  }

  Future<int> getEmployeesCount(String storeId) async {
    try {
      final snapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where(FirebaseConstants.role, isEqualTo: FirebaseConstants.employeeRole)
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

      transaction.update(userRef, {
        FirebaseConstants.isActive: false,
        FirebaseConstants.updatedAt: Timestamp.now(),
      });

      if (wasActive && storeId != null) {
        final storeRef = _firestore.collection(FirebaseConstants.storesCollection).doc(storeId);
        transaction.update(storeRef, {'stats.totalEmployees': FieldValue.increment(-1)});
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

      final existingEmployee = await getEmployeeByPIN(storeId: storeId, pin: newPin);
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

  Stream<List<UserModel>> watchEmployees(String storeId) {
    return _usersCollection
        .where(FirebaseConstants.storeId, isEqualTo: storeId)
        .where(FirebaseConstants.role, isEqualTo: FirebaseConstants.employeeRole)
        .orderBy(FirebaseConstants.createdAt, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList())
        .handleError((error) {
      // Silently handle stream errors or use a proper logger in a real app
      return <UserModel>[];
    });
  }
}
