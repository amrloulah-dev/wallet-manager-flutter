import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/number_parser.dart';
import '../../core/enums/subscription_enums.dart';
import '../../core/errors/app_error_handler.dart';

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

  final DateTime? createdAt; // Made nullable
  final DateTime? updatedAt;

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
    this.createdAt,
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

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) {
      AppErrorHandler.handle(
        'Missing createdAt in Store document: ${doc.id}',
        operation: 'StoreModel.fromFirestore',
      );
    }

    return StoreModel(
      storeId: doc.id,
      storeName: data['storeName'] as String? ?? '',
      storePassword: data['storePassword'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      ownerEmail: data['ownerEmail'] as String? ?? '',
      ownerPhoto: data['ownerPhoto'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      isSuspended: data['isSuspended'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      subscription: data['subscription'] != null 
          ? StoreSubscription.fromMap(data['subscription'] as Map<String, dynamic>)
          : _withMigrationWarning(), // FR-17 legacy migration
      settings: StoreSettings.fromMap(data['settings'] as Map<String, dynamic>? ?? {}),
      stats: StoreStats.fromMap(data['stats'] as Map<String, dynamic>? ?? {}),
      legacyData: data['legacyData'] as Map<String, dynamic>? ?? {
        if (data.containsKey('licenseKey')) 'licenseKey': data['licenseKey'],
        if (data.containsKey('licenseKeyId')) 'licenseKeyId': data['licenseKeyId'],
        if (data.containsKey('activeLicenseKey')) 'activeLicenseKey': data['activeLicenseKey'],
      },
    );
  }

  static StoreSubscription _withMigrationWarning() {
    debugPrint('⚠️ [MIGRATION] Store using legacy lifetime subscription (migration needed)');
    return StoreSubscription.migratedLifetime();
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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
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
    DateTime? createdAt,
    DateTime? updatedAt,
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
  final SubscriptionPlan planId; // ENUM refactor
  final SubscriptionStatus status; // ENUM refactor
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

  /// T058: Pure POJO — accepts a pre-resolved server timestamp from SubscriptionProvider.
  /// Never call TimeService directly from within this model.
  bool isExpiredAt(DateTime serverNow) {
    if (planId == SubscriptionPlan.lifetime) return false;
    if (endDate == null) return false;

    // T026/T044: 48-hour grace period anchored to pendingRequestDate
    if (pendingRequestDate != null) {
      final graceEnd = pendingRequestDate!.add(const Duration(hours: 48));
      if (serverNow.isBefore(graceEnd)) return false;
    }

    return serverNow.isAfter(endDate!);
  }

  /// T058: Days remaining computed from a pre-resolved server timestamp.
  int? daysRemainingAt(DateTime serverNow) {
    if (endDate == null) return null; // Lifetime — no end date
    final remaining = endDate!.difference(serverNow);
    return remaining.inDays >= 0 ? remaining.inDays + 1 : 0;
  }

  factory StoreSubscription.migratedLifetime() {
    return StoreSubscription(
      planId: SubscriptionPlan.lifetime,
      status: SubscriptionStatus.active,
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
      planId: SubscriptionPlan.fromString(map['planId'] as String? ?? 'free'),
      status: SubscriptionStatus.fromString(map['status'] as String? ?? 'active'),
      endDate: map['endDate'] != null 
          ? (map['endDate'] as Timestamp).toDate() 
          : null,
      trialConsumed: map['trialConsumed'] as bool? ?? false,
      maxWallets: NumberParser.toInt(map['maxWallets'], 3),
      maxEmployees: NumberParser.toInt(map['maxEmployees'], 1),
      smsEnabled: map['smsEnabled'] as bool? ?? false,
      pendingRequestDate: map['pendingRequestDate'] != null 
          ? (map['pendingRequestDate'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'planId': planId.name,
      'status': status.name,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'trialConsumed': trialConsumed,
      'maxWallets': maxWallets,
      'maxEmployees': maxEmployees,
      'smsEnabled': smsEnabled,
      'pendingRequestDate': pendingRequestDate != null ? Timestamp.fromDate(pendingRequestDate!) : null,
    };
  }

  StoreSubscription copyWith({
    SubscriptionPlan? planId,
    SubscriptionStatus? status,
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

class StoreSettings {
  final String currency;
  final String timezone;

  StoreSettings({
    this.currency = 'EGP',
    this.timezone = 'Africa/Cairo',
  });

  factory StoreSettings.fromMap(Map<String, dynamic> map) {
    return StoreSettings(
      currency: map['currency'] as String? ?? 'EGP',
      timezone: map['timezone'] as String? ?? 'Africa/Cairo',
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

class StoreStats {
  final int totalWallets;
  final int activeWallets;
  final int totalTransactionsToday;
  final double totalCommissionToday;
  final double totalServiceFeeToday;
  final DateTime? lastUpdated; // Made nullable

  StoreStats({
    this.totalWallets = 0,
    this.activeWallets = 0,
    this.totalTransactionsToday = 0,
    this.totalCommissionToday = 0.0,
    this.totalServiceFeeToday = 0.0,
    this.lastUpdated,
  });

  factory StoreStats.fromMap(Map<String, dynamic> map) {
    final lastUpdated = (map['lastUpdated'] as Timestamp?)?.toDate();
    return StoreStats(
      totalWallets: NumberParser.toInt(map['totalWallets']),
      activeWallets: NumberParser.toInt(map['activeWallets']),
      totalTransactionsToday: NumberParser.toInt(map['totalTransactionsToday']),
      totalCommissionToday: NumberParser.toDouble(map['totalCommissionToday']),
      totalServiceFeeToday: NumberParser.toDouble(map['totalServiceFeeToday']),
      lastUpdated: lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalWallets': totalWallets,
      'activeWallets': activeWallets,
      'totalTransactionsToday': totalTransactionsToday,
      'totalCommissionToday': totalCommissionToday,
      'totalServiceFeeToday': totalServiceFeeToday,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }

  StoreStats copyWith({
    int? totalWallets,
    int? activeWallets,
    int? totalTransactionsToday,
    double? totalCommissionToday,
    double? totalServiceFeeToday,
    DateTime? lastUpdated,
  }) {
    return StoreStats(
      totalWallets: totalWallets ?? this.totalWallets,
      activeWallets: activeWallets ?? this.activeWallets,
      totalTransactionsToday:
          totalTransactionsToday ?? this.totalTransactionsToday,
      totalCommissionToday: totalCommissionToday ?? this.totalCommissionToday,
      totalServiceFeeToday: totalServiceFeeToday ?? this.totalServiceFeeToday,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
