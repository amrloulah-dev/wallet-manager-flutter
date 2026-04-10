import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/time_service.dart';

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

  final StoreSubscription subscription;
  final StoreSettings settings;
  final StoreStats stats;
  final Map<String, dynamic>? legacyData;

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
    required this.subscription,
    required this.settings,
    required this.stats,
    this.legacyData,
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
      subscription: data['subscription'] != null 
          ? StoreSubscription.fromMap(data['subscription'])
          : StoreSubscription.migratedLifetime(), // FR-17 legacy migration
      settings: StoreSettings.fromMap(data['settings'] ?? {}),
      stats: StoreStats.fromMap(data['stats'] ?? {}),
      legacyData: data['legacyData'] ?? {
        if (data.containsKey('licenseKey')) 'licenseKey': data['licenseKey'],
        if (data.containsKey('licenseKeyId')) 'licenseKeyId': data['licenseKeyId'],
        if (data.containsKey('activeLicenseKey')) 'activeLicenseKey': data['activeLicenseKey'],
      },
    );
  }

  /// Converts the StoreModel instance to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    final map = {
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
      'subscription': subscription.toMap(),
      'settings': settings.toMap(),
      'stats': stats.toMap(),
      if (legacyData != null && legacyData!.isNotEmpty) 'legacyData': legacyData,
    };
    
    // Preserve legacy fields at root if they were stored in legacyData
    if (legacyData != null) {
      if (legacyData!.containsKey('licenseKey')) {
        map['licenseKey'] = legacyData!['licenseKey'];
      }
      if (legacyData!.containsKey('licenseKeyId')) {
        map['licenseKeyId'] = legacyData!['licenseKeyId'];
      }
      if (legacyData!.containsKey('activeLicenseKey')) {
        map['activeLicenseKey'] = legacyData!['activeLicenseKey'];
      }
    }

    return map;
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
    StoreSubscription? subscription,
    StoreSettings? settings,
    StoreStats? stats,
    Map<String, dynamic>? legacyData,
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
      subscription: subscription ?? this.subscription,
      settings: settings ?? this.settings,
      stats: stats ?? this.stats,
      legacyData: legacyData ?? this.legacyData,
    );
  }

  @override
  String toString() {
    return 'StoreModel(storeId: $storeId, storeName: $storeName, owner: $ownerName, planId: ${subscription.planId})';
  }
}

// ===========================
// Nested: Store Subscription
// ===========================

class StoreSubscription {
  final String planId; // 'free', 'trial', 'pro_yearly', 'lifetime'
  final String status; // 'active', 'suspended'
  final DateTime? endDate; // null for lifetime
  final bool trialConsumed; // true if trial was used
  final int maxWallets; // e.g., 3 or 999
  final int maxEmployees; // e.g., 1 or 999
  final bool smsEnabled;
  final DateTime? pendingRequestDate;

  StoreSubscription({
    required this.planId,
    required this.status,
    this.endDate,
    required this.trialConsumed,
    required this.maxWallets,
    required this.maxEmployees,
    required this.smsEnabled,
    this.pendingRequestDate,
  });

  bool get isExpired {
    if (endDate == null) return planId != 'lifetime';
    
    // T026: 48-hour grace period if there is an active pending request
    if (pendingRequestDate != null) {
      final graceEnd = pendingRequestDate!.add(const Duration(hours: 48));
      if (TimeService.now().isBefore(graceEnd)) {
        return false;
      }
    }
    
    // T013 Uses NTP time_service offset
    return TimeService.now().isAfter(endDate!);
  }

  int? get daysRemaining {
    if (endDate == null) return null; // Lifetime or no end date
    final remaining = endDate!.difference(TimeService.now());
    return remaining.inDays >= 0 ? remaining.inDays + 1 : 0;
  }

  factory StoreSubscription.migratedLifetime() {
    return StoreSubscription(
      planId: 'lifetime',
      status: 'active',
      endDate: null,
      trialConsumed: true,
      maxWallets: 999,
      maxEmployees: 999,
      smsEnabled: true,
      pendingRequestDate: null,
    );
  }

  factory StoreSubscription.fromMap(Map<String, dynamic> map) {
    return StoreSubscription(
      planId: map['planId'] ?? 'free',
      status: map['status'] ?? 'active',
      endDate: map['endDate'] != null 
          ? (map['endDate'] as Timestamp).toDate() 
          : null,
      trialConsumed: map['trialConsumed'] ?? false,
      maxWallets: map['maxWallets'] ?? 3,
      maxEmployees: map['maxEmployees'] ?? 1,
      smsEnabled: map['smsEnabled'] ?? false,
      pendingRequestDate: map['pendingRequestDate'] != null 
          ? (map['pendingRequestDate'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'status': status,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'trialConsumed': trialConsumed,
      'maxWallets': maxWallets,
      'maxEmployees': maxEmployees,
      'smsEnabled': smsEnabled,
      'pendingRequestDate': pendingRequestDate != null ? Timestamp.fromDate(pendingRequestDate!) : null,
    };
  }

  StoreSubscription copyWith({
    String? planId,
    String? status,
    DateTime? endDate,
    bool? trialConsumed,
    int? maxWallets,
    int? maxEmployees,
    bool? smsEnabled,
    DateTime? pendingRequestDate,
  }) {
    return StoreSubscription(
      planId: planId ?? this.planId,
      status: status ?? this.status,
      endDate: endDate ?? this.endDate,
      trialConsumed: trialConsumed ?? this.trialConsumed,
      maxWallets: maxWallets ?? this.maxWallets,
      maxEmployees: maxEmployees ?? this.maxEmployees,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      pendingRequestDate: pendingRequestDate ?? this.pendingRequestDate,
    );
  }
}

// ===========================
// Nested: Store Settings
// ===========================

class StoreSettings {
  final String currency;
  final String timezone;

  StoreSettings({
    this.currency = 'EGP',
    this.timezone = 'Africa/Cairo',
  });

  factory StoreSettings.fromMap(Map<String, dynamic> map) {
    return StoreSettings(
      currency: map['currency'] ?? 'EGP',
      timezone: map['timezone'] ?? 'Africa/Cairo',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currency': currency,
      'timezone': timezone,
    };
  }

  StoreSettings copyWith({String? currency, String? timezone}) {
    return StoreSettings(
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
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
      totalTransactionsToday:
          totalTransactionsToday ?? this.totalTransactionsToday,
      totalCommissionToday: totalCommissionToday ?? this.totalCommissionToday,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
