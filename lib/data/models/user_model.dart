import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/number_parser.dart';
import '../../core/enums/user_enums.dart';
import '../../core/errors/app_exceptions.dart';

import 'user_permissions.dart';

// ===========================
// Main User Model
// ===========================

class UserModel {
  // Identity
  final String userId;
  final String storeId;
  final UserRole role; // ENUM refactor

  // Personal Info
  final String fullName;
  final String? email; // For owner
  final String? phone; // For employee
  final String? photoURL;

  // Authentication
  final String? firebaseUid;
  final String? pin; // Hashed PIN for employees

  // Status
  final bool isActive;

  // Timestamps
  final DateTime? createdAt; // Made nullable
  final String?
      createdBy; // ID of the user who created this user (e.g., owner ID)
  final DateTime? updatedAt;
  final DateTime? lastLogin; // Made nullable

  // Nested objects (for employees)
  final UserPermissions? permissions;
  final UserStats? stats;

  UserModel({
    required this.userId,
    required this.storeId,
    required this.role,
    required this.fullName,
    this.email,
    this.phone,
    this.photoURL,
    this.firebaseUid,
    this.pin,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.lastLogin,
    this.permissions,
    this.stats,
  });

  // Getters
  bool get isOwner => role == UserRole.owner;
  bool get isEmployee => role == UserRole.employee;

  /// Helper to check permissions easily.
  /// Example: user.hasPermission((p) => p.createDebt)
  bool hasPermission(bool Function(UserPermissions) selector) {
    if (isOwner) return true;
    if (permissions == null) return false;
    return selector(permissions!);
  }

  /// Creates a UserModel from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('User document does not exist!');
    }
    final data = doc.data() as Map<String, dynamic>;
    final roleStr = data['role'] as String? ?? 'employee';
    final role = UserRole.fromString(roleStr);

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final lastLogin = (data['lastLogin'] as Timestamp?)?.toDate();

    if (createdAt == null || lastLogin == null) {
      throw NotFoundException(
          'User document ${doc.id} missing required audit timestamps (createdAt or lastLogin)');
    }

    return UserModel(
      userId: doc.id,
      storeId: data['storeId'] as String? ?? '',
      role: role,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      photoURL: data['photoURL'] as String?,
      firebaseUid: data['firebaseUid'] as String?,
      pin: data['pin'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: createdAt,
      createdBy: data['createdBy'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastLogin: lastLogin,
      permissions: role == UserRole.employee
          ? UserPermissions.fromMap(
              data['permissions'] as Map<String, dynamic>? ?? {})
          : null,
      stats: role == UserRole.employee
          ? UserStats.fromMap(data['stats'] as Map<String, dynamic>? ?? {})
          : null,
    );
  }

  /// Converts the UserModel instance to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    final map = {
      'storeId': storeId,
      'role': role.name,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'photoURL': photoURL,
      'firebaseUid': firebaseUid,
      'pin': pin,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'createdBy': createdBy,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
    };

    if (isEmployee) {
      map['permissions'] = permissions?.toMap();
      map['stats'] = stats?.toMap();
    }

    return map;
  }

  UserModel copyWith({
    String? userId,
    String? storeId,
    UserRole? role,
    String? fullName,
    String? email,
    String? phone,
    String? photoURL,
    String? firebaseUid,
    String? pin,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    DateTime? lastLogin,
    UserPermissions? permissions,
    UserStats? stats,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoURL: photoURL ?? this.photoURL,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      pin: pin ?? this.pin,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      permissions: permissions ?? this.permissions,
      stats: stats ?? this.stats,
    );
  }

  @override
  String toString() {
    return 'UserModel(userId: $userId, fullName: $fullName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserModel &&
        other.userId == userId &&
        other.storeId == storeId;
  }

  @override
  int get hashCode => userId.hashCode ^ storeId.hashCode;
}

class UserStats {
  final int totalTransactions;
  final double totalCommission;
  final int totalDebtsCreated;
  final DateTime? lastTransactionDate;

  UserStats({
    this.totalTransactions = 0,
    this.totalCommission = 0.0,
    this.totalDebtsCreated = 0,
    this.lastTransactionDate,
  });

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalTransactions: NumberParser.toInt(map['totalTransactions']),
      totalCommission: NumberParser.toDouble(map['totalCommission']),
      totalDebtsCreated: NumberParser.toInt(map['totalDebtsCreated']),
      lastTransactionDate: (map['lastTransactionDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalTransactions': totalTransactions,
      'totalCommission': totalCommission,
      'totalDebtsCreated': totalDebtsCreated,
      'lastTransactionDate': lastTransactionDate != null
          ? Timestamp.fromDate(lastTransactionDate!)
          : null,
    };
  }

  UserStats copyWith({
    int? totalTransactions,
    double? totalCommission,
    int? totalDebtsCreated,
    DateTime? lastTransactionDate,
  }) {
    return UserStats(
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalCommission: totalCommission ?? this.totalCommission,
      totalDebtsCreated: totalDebtsCreated ?? this.totalDebtsCreated,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }
}
