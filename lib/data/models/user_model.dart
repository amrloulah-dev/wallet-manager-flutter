import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_permissions.dart';

// ===========================
// Main User Model
// ===========================

class UserModel {
  // Identity
  final String userId;
  final String storeId;
  final String role; // "owner" | "employee"

  // Personal Info
  final String fullName;
  final String? email; // For owner
  final String? phone; // For employee
  final String? photoURL;

  // Authentication
  final String firebaseUid;
  final String? pin; // Hashed PIN for employees

  // Status
  final bool isActive;

  // Timestamps
  final Timestamp createdAt;
  final String?
      createdBy; // ID of the user who created this user (e.g., owner ID)
  final Timestamp? updatedAt;
  final Timestamp lastLogin;

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
    required this.firebaseUid,
    this.pin,
    this.isActive = true,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    required this.lastLogin,
    this.permissions,
    this.stats,
  });

  // Getters
  bool get isOwner => role == 'owner';
  bool get isEmployee => role == 'employee';

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
    final role = data['role'] ?? 'employee';

    return UserModel(
      userId: doc.id,
      storeId: data['storeId'] ?? '',
      role: role,
      fullName: data['fullName'] ?? '',
      email: data['email'],
      phone: data['phone'],
      photoURL: data['photoURL'],
      firebaseUid: data['firebaseUid'] ?? '',
      pin: data['pin'],
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'],
      updatedAt: data['updatedAt'],
      lastLogin: data['lastLogin'] ?? Timestamp.now(),
      permissions: role == 'employee'
          ? UserPermissions.fromMap(data['permissions'] ?? {})
          : null,
      stats: role == 'employee' ? UserStats.fromMap(data['stats'] ?? {}) : null,
    );
  }

  /// Converts the UserModel instance to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    final map = {
      'storeId': storeId,
      'role': role,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'photoURL': photoURL,
      'firebaseUid': firebaseUid,
      'pin': pin,
      'isActive': isActive,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'lastLogin': lastLogin,
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
    String? role,
    String? fullName,
    String? email,
    String? phone,
    String? photoURL,
    String? firebaseUid,
    String? pin,
    bool? isActive,
    Timestamp? createdAt,
    String? createdBy,
    Timestamp? updatedAt,
    Timestamp? lastLogin,
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

// ===========================
// Nested: User Stats
// ===========================

class UserStats {
  final int totalTransactions;
  final double totalCommission;
  final int totalDebtsCreated;
  final Timestamp? lastTransactionDate;

  UserStats({
    this.totalTransactions = 0,
    this.totalCommission = 0.0,
    this.totalDebtsCreated = 0,
    this.lastTransactionDate,
  });

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalTransactions: map['totalTransactions'] ?? 0,
      totalCommission: (map['totalCommission'] ?? 0.0).toDouble(),
      totalDebtsCreated: map['totalDebtsCreated'] ?? 0,
      lastTransactionDate: map['lastTransactionDate'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalTransactions': totalTransactions,
      'totalCommission': totalCommission,
      'totalDebtsCreated': totalDebtsCreated,
      'lastTransactionDate': lastTransactionDate,
    };
  }

  UserStats copyWith({
    int? totalTransactions,
    double? totalCommission,
    int? totalDebtsCreated,
    Timestamp? lastTransactionDate,
  }) {
    return UserStats(
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalCommission: totalCommission ?? this.totalCommission,
      totalDebtsCreated: totalDebtsCreated ?? this.totalDebtsCreated,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }
}
