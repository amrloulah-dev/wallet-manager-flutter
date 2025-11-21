import 'package:cloud_firestore/cloud_firestore.dart';

// ===========================
// Main Store Model
// ===========================

class StoreModel {
  final String storeId;
  final String storeName;
  final String storePassword; // Hashed password

  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final String? ownerPhoto;

  final bool isActive;
  final bool isSuspended;

  final Timestamp createdAt;
  final Timestamp? updatedAt;

  final StoreLicense license;
  final StoreSettings settings;
  final StoreStats stats;

  final String activeLicenseKey;
  final String licenseKeyId;

  StoreModel({
    required this.storeId,
    required this.storeName,
    required this.storePassword,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    this.ownerPhoto,
    this.isActive = true,
    this.isSuspended = false,
    required this.createdAt,
    this.updatedAt,
    required this.license,
    required this.settings,
    required this.stats,
    required this.activeLicenseKey,
    required this.licenseKeyId,
  });

  /// Creates a StoreModel from a Firestore document snapshot.
  factory StoreModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('Store document does not exist!');
    }
    final data = doc.data() as Map<String, dynamic>;

    return StoreModel(
      storeId: doc.id,
      storeName: data['storeName'] ?? '',
      storePassword: data['storePassword'] ?? '',
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      ownerPhoto: data['ownerPhoto'],
      isActive: data['isActive'] ?? true,
      isSuspended: data['isSuspended'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      license: StoreLicense.fromMap(data['license'] ?? {}),
      settings: StoreSettings.fromMap(data['settings'] ?? {}),
      stats: StoreStats.fromMap(data['stats'] ?? {}),
      activeLicenseKey: data['activeLicenseKey'] ?? '',
      licenseKeyId: data['licenseKeyId'] ?? '',
    );
  }

  /// Converts the StoreModel instance to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'storeName': storeName,
      'storePassword': storePassword,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'ownerPhoto': ownerPhoto,
      'isActive': isActive,
      'isSuspended': isSuspended,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'license': license.toMap(),
      'settings': settings.toMap(),
      'stats': stats.toMap(),
      'activeLicenseKey': activeLicenseKey,
      'licenseKeyId': licenseKeyId,
    };
  }

  /// Creates a copy of the instance with updated fields.
  StoreModel copyWith({
    String? storeId,
    String? storeName,
    String? storePassword,
    String? ownerId,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhoto,
    bool? isActive,
    bool? isSuspended,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    StoreLicense? license,
    StoreSettings? settings,
    StoreStats? stats,
    String? activeLicenseKey,
    String? licenseKeyId,
  }) {
    return StoreModel(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storePassword: storePassword ?? this.storePassword,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhoto: ownerPhoto ?? this.ownerPhoto,
      isActive: isActive ?? this.isActive,
      isSuspended: isSuspended ?? this.isSuspended,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      license: license ?? this.license,
      settings: settings ?? this.settings,
      stats: stats ?? this.stats,
      activeLicenseKey: activeLicenseKey ?? this.activeLicenseKey,
      licenseKeyId: licenseKeyId ?? this.licenseKeyId,
    );
  }

  @override
  String toString() {
    return 'StoreModel(storeId: $storeId, storeName: $storeName, owner: $ownerName)';
  }
}

// ===========================
// Nested: Store License
// ===========================

class StoreLicense {
  final String licenseKey;
  final String licenseType; // e.g., 'trial', 'premium', 'enterprise'
  final String status; // e.g., 'active', 'expired', 'suspended'
  final Timestamp startDate;
  final Timestamp expiryDate;
  final bool autoRenew;
  final Timestamp lastCheck;

  StoreLicense({
    required this.licenseKey,
    required this.licenseType,
    required this.status,
    required this.startDate,
    required this.expiryDate,
    this.autoRenew = false,
    required this.lastCheck,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate.toDate());
  int get daysRemaining {
    if (isExpired) return 0;
    return expiryDate.toDate().difference(DateTime.now()).inDays;
  }

  factory StoreLicense.fromMap(Map<String, dynamic> map) {
    return StoreLicense(
      licenseKey: map['licenseKey'] ?? '',
      licenseType: map['licenseType'] ?? 'trial',
      status: map['status'] ?? 'inactive',
      startDate: map['startDate'] ?? Timestamp.now(),
      expiryDate: map['expiryDate'] ?? Timestamp.now(),
      autoRenew: map['autoRenew'] ?? false,
      lastCheck: map['lastCheck'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'licenseKey': licenseKey,
      'licenseType': licenseType,
      'status': status,
      'startDate': startDate,
      'expiryDate': expiryDate,
      'autoRenew': autoRenew,
      'lastCheck': lastCheck,
    };
  }

  StoreLicense copyWith({
    String? licenseKey,
    String? licenseType,
    String? status,
    Timestamp? startDate,
    Timestamp? expiryDate,
    bool? autoRenew,
    Timestamp? lastCheck,
  }) {
    return StoreLicense(
      licenseKey: licenseKey ?? this.licenseKey,
      licenseType: licenseType ?? this.licenseType,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      autoRenew: autoRenew ?? this.autoRenew,
      lastCheck: lastCheck ?? this.lastCheck,
    );
  }
}

// ===========================
// Nested: Store Settings
// ===========================

class StoreSettings {
  final String currency;
  final String timezone;
  final int maxEmployees;

  StoreSettings({this.currency = 'EGP', this.timezone = 'Africa/Cairo', this.maxEmployees = 5});

  factory StoreSettings.fromMap(Map<String, dynamic> map) {
    return StoreSettings(
      currency: map['currency'] ?? 'EGP',
      timezone: map['timezone'] ?? 'Africa/Cairo',
      maxEmployees: map['maxEmployees'] ?? 5,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currency': currency,
      'timezone': timezone,
      'maxEmployees': maxEmployees,
    };
  }

  StoreSettings copyWith({String? currency, String? timezone, int? maxEmployees}) {
    return StoreSettings(
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      maxEmployees: maxEmployees ?? this.maxEmployees,
    );
  }
}

// ===========================
// Nested: Store Stats
// ===========================

class StoreStats {
  final int totalWallets;
  final int activeWallets;
  final int totalTransactionsToday;
  final double totalCommissionToday;
  final Timestamp lastUpdated;

  StoreStats({
    this.totalWallets = 0,
    this.activeWallets = 0,
    this.totalTransactionsToday = 0,
    this.totalCommissionToday = 0.0,
    required this.lastUpdated,
  });

  factory StoreStats.fromMap(Map<String, dynamic> map) {
    return StoreStats(
      totalWallets: map['totalWallets'] ?? 0,
      activeWallets: map['activeWallets'] ?? 0,
      totalTransactionsToday: map['totalTransactionsToday'] ?? 0,
      totalCommissionToday: (map['totalCommissionToday'] ?? 0.0).toDouble(),
      lastUpdated: map['lastUpdated'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalWallets': totalWallets,
      'activeWallets': activeWallets,
      'totalTransactionsToday': totalTransactionsToday,
      'totalCommissionToday': totalCommissionToday,
      'lastUpdated': lastUpdated,
    };
  }

  StoreStats copyWith({
    int? totalWallets,
    int? activeWallets,
    int? totalTransactionsToday,
    double? totalCommissionToday,
    Timestamp? lastUpdated,
  }) {
    return StoreStats(
      totalWallets: totalWallets ?? this.totalWallets,
      activeWallets: activeWallets ?? this.activeWallets,
      totalTransactionsToday: totalTransactionsToday ?? this.totalTransactionsToday,
      totalCommissionToday: totalCommissionToday ?? this.totalCommissionToday,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
