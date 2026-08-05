import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/utils/number_parser.dart';
import '../../core/enums/wallet_enums.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/amount_validator.dart';
import '../../core/di/service_locator.dart';
import '../../providers/platform_settings_provider.dart';
import 'platform_settings_model.dart';

class WalletLimits {
  final double dailyLimit;
  final double dailyUsed;
  final double monthlyLimit;
  final double monthlyUsed;

  WalletLimits({
    required this.dailyLimit,
    this.dailyUsed = 0.0,
    required this.monthlyLimit,
    this.monthlyUsed = 0.0,
  });

  factory WalletLimits.fromMap(Map<String, dynamic> map) {
    return WalletLimits(
      dailyLimit: NumberParser.toDouble(map['dailyLimit']),
      dailyUsed: NumberParser.toDouble(map['dailyUsed']),
      monthlyLimit: NumberParser.toDouble(map['monthlyLimit']),
      monthlyUsed: NumberParser.toDouble(map['monthlyUsed']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyLimit': dailyLimit,
      'dailyUsed': dailyUsed,
      'monthlyLimit': monthlyLimit,
      'monthlyUsed': monthlyUsed,
    };
  }

  WalletLimits copyWith({
    double? dailyLimit,
    double? dailyUsed,
    double? monthlyLimit,
    double? monthlyUsed,
  }) {
    return WalletLimits(
      dailyLimit: dailyLimit ?? this.dailyLimit,
      dailyUsed: dailyUsed ?? this.dailyUsed,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      monthlyUsed: monthlyUsed ?? this.monthlyUsed,
    );
  }

  double get dailyRemaining => dailyLimit - dailyUsed;
  double get monthlyRemaining => monthlyLimit - monthlyUsed;
  double get dailyPercentage =>
      dailyLimit > 0 ? ((dailyUsed / dailyLimit) * 100).clamp(0, 100) : 0;
  double get monthlyPercentage =>
      monthlyLimit > 0 ? ((monthlyUsed / monthlyLimit) * 100).clamp(0, 100) : 0;
  bool get isDailyLimitReached => dailyUsed >= dailyLimit;
  bool get isMonthlyLimitReached => monthlyUsed >= monthlyLimit;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletLimits &&
        other.dailyLimit == dailyLimit &&
        other.dailyUsed == dailyUsed &&
        other.monthlyLimit == monthlyLimit &&
        other.monthlyUsed == monthlyUsed;
  }

  @override
  int get hashCode =>
      dailyLimit.hashCode ^
      dailyUsed.hashCode ^
      monthlyLimit.hashCode ^
      monthlyUsed.hashCode;
}

class WalletStats {
  final int totalTransactions;
  final double totalSentAmount;
  final double totalReceivedAmount;
  final double totalCommission;
  final double totalServiceFee;
  final DateTime? lastTransactionDate;

  double get totalEarnings => totalCommission + totalServiceFee;

  WalletStats({
    this.totalTransactions = 0,
    this.totalSentAmount = 0.0,
    this.totalReceivedAmount = 0.0,
    this.totalCommission = 0.0,
    this.totalServiceFee = 0.0,
    this.lastTransactionDate,
  });

  factory WalletStats.fromMap(Map<String, dynamic> map) {
    return WalletStats(
      totalTransactions: NumberParser.toInt(map['totalTransactions']),
      totalSentAmount: NumberParser.toDouble(map['totalSentAmount']),
      totalReceivedAmount: NumberParser.toDouble(map['totalReceivedAmount']),
      totalCommission: NumberParser.toDouble(map['totalCommission']),
      totalServiceFee: NumberParser.toDouble(map['totalServiceFee']),
      lastTransactionDate: (map['lastTransactionDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalTransactions': totalTransactions,
      'totalSentAmount': totalSentAmount,
      'totalReceivedAmount': totalReceivedAmount,
      'totalCommission': totalCommission,
      'totalServiceFee': totalServiceFee,
      'lastTransactionDate': lastTransactionDate != null
          ? Timestamp.fromDate(lastTransactionDate!)
          : null,
    };
  }

  WalletStats copyWith({
    int? totalTransactions,
    double? totalSentAmount,
    double? totalReceivedAmount,
    double? totalCommission,
    double? totalServiceFee,
    DateTime? lastTransactionDate,
  }) {
    return WalletStats(
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalSentAmount: totalSentAmount ?? this.totalSentAmount,
      totalReceivedAmount: totalReceivedAmount ?? this.totalReceivedAmount,
      totalCommission: totalCommission ?? this.totalCommission,
      totalServiceFee: totalServiceFee ?? this.totalServiceFee,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }

  double get totalAmount => totalSentAmount + totalReceivedAmount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletStats &&
        other.totalTransactions == totalTransactions &&
        other.totalSentAmount == totalSentAmount &&
        other.totalReceivedAmount == totalReceivedAmount &&
        other.totalCommission == totalCommission &&
        other.totalServiceFee == totalServiceFee &&
        other.lastTransactionDate == lastTransactionDate;
  }

  @override
  int get hashCode =>
      totalTransactions.hashCode ^
      totalSentAmount.hashCode ^
      totalReceivedAmount.hashCode ^
      totalCommission.hashCode ^
      totalServiceFee.hashCode ^
      lastTransactionDate.hashCode;
}

class WalletModel {
  final String walletId;
  final String storeId;
  final String phoneNumber;
  final WalletType walletType; // ENUM refactor
  final WalletStatus walletStatus; // ENUM refactor
  final double balance;
  final String? notes;
  final bool isActive;
  final bool isFrozen;
  final DateTime? createdAt; // Made nullable
  final String createdBy;
  final DateTime? updatedAt;
  final WalletLimits sendLimits;
  final WalletLimits receiveLimits;
  final DateTime? lastDailyReset; // Made nullable
  final DateTime? lastMonthlyReset; // Made nullable
  final WalletStats stats;

  WalletModel({
    required this.walletId,
    required this.storeId,
    required this.phoneNumber,
    required this.walletType,
    required this.walletStatus,
    this.balance = 0.0,
    this.notes,
    this.isActive = true,
    this.isFrozen = false,
    this.createdAt,
    required this.createdBy,
    this.updatedAt,
    required this.sendLimits,
    required this.receiveLimits,
    this.lastDailyReset,
    this.lastMonthlyReset,
    required this.stats,
  });

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel.fromMap(data, doc.id);
  }

  factory WalletModel.fromMap(Map<String, dynamic> data, String docId) {
    final createdAt =
        (data[FirebaseConstants.createdAt] as Timestamp?)?.toDate();
    final lastDailyReset =
        (data[FirebaseConstants.lastDailyReset] as Timestamp?)?.toDate();
    final lastMonthlyReset =
        (data[FirebaseConstants.lastMonthlyReset] as Timestamp?)?.toDate();

    final balance = NumberParser.toDouble(data['balance']);
    // Phase 3: Boundary Guard
    AmountValidator.ensurePositiveOrZero(balance);

    // Lazy Migration Fallbacks:
    // 1. Missing walletStatus defaults to WalletStatus.inactive (never active/new).
    // 2. Missing sendLimits/receiveLimits reconstruct from legacy root fields or networkOldLimits.
    // 3. Null lastDailyReset/lastMonthlyReset are intentionally preserved so WalletProvider.needsDailyReset
    //    triggers a silent auto-heal limit reset via pinpoint serverTimestamp updates in Firestore.
    final rawStatus = data[FirebaseConstants.walletStatus] as String?;
    final walletStatus = (rawStatus != null && rawStatus.isNotEmpty)
        ? WalletStatus.fromString(rawStatus)
        : WalletStatus.inactive;

    final resolvedSettings = sl.isRegistered<PlatformSettingsProvider>()
        ? sl<PlatformSettingsProvider>().settings
        : const PlatformSettingsModel.defaults();

    final sendLimitsMap =
        data[FirebaseConstants.sendLimits] as Map<String, dynamic>?;
    final sendLimits = (sendLimitsMap != null && sendLimitsMap.isNotEmpty)
        ? WalletLimits.fromMap(sendLimitsMap)
        : _resolveLegacySendLimits(data, resolvedSettings);

    final receiveLimitsMap =
        data[FirebaseConstants.receiveLimits] as Map<String, dynamic>?;
    final receiveLimits = (receiveLimitsMap != null && receiveLimitsMap.isNotEmpty)
        ? WalletLimits.fromMap(receiveLimitsMap)
        : _resolveLegacyReceiveLimits(data, resolvedSettings);

    return WalletModel(
      walletId: docId,
      storeId: data[FirebaseConstants.storeId] as String? ?? '',
      phoneNumber: data[FirebaseConstants.phoneNumber] as String? ?? '',
      walletType: WalletType.fromString(
          data[FirebaseConstants.walletType] as String? ?? ''),
      walletStatus: walletStatus,
      balance: balance,
      notes: data[FirebaseConstants.notes] as String?,
      isActive: data[FirebaseConstants.isActive] as bool? ?? true,
      isFrozen: false,
      createdAt: createdAt,
      createdBy: data[FirebaseConstants.createdBy] as String? ?? '',
      updatedAt: (data[FirebaseConstants.updatedAt] as Timestamp?)?.toDate(),
      sendLimits: sendLimits,
      receiveLimits: receiveLimits,
      lastDailyReset: lastDailyReset,
      lastMonthlyReset: lastMonthlyReset,
      stats: WalletStats.fromMap(
          data[FirebaseConstants.stats] as Map<String, dynamic>? ?? {}),
    );
  }

  static WalletLimits _resolveLegacySendLimits(
      Map<String, dynamic> data, PlatformSettingsModel settings) {
    final rootDaily = data['dailyLimit'];
    final rootMonthly = data['monthlyLimit'];

    final dailyLimit = rootDaily != null
        ? NumberParser.toDouble(rootDaily)
        : settings.networkOldLimits.dailySend;
    final monthlyLimit = rootMonthly != null
        ? NumberParser.toDouble(rootMonthly)
        : settings.networkOldLimits.monthlySend;

    return WalletLimits(
      dailyLimit: dailyLimit,
      dailyUsed: 0.0,
      monthlyLimit: monthlyLimit,
      monthlyUsed: 0.0,
    );
  }

  static WalletLimits _resolveLegacyReceiveLimits(
      Map<String, dynamic> data, PlatformSettingsModel settings) {
    final rootDaily = data['dailyLimit'];
    final rootMonthly = data['monthlyLimit'];

    final dailyLimit = rootDaily != null
        ? NumberParser.toDouble(rootDaily)
        : settings.networkOldLimits.dailyReceive;
    final monthlyLimit = rootMonthly != null
        ? NumberParser.toDouble(rootMonthly)
        : settings.networkOldLimits.monthlyReceive;

    return WalletLimits(
      dailyLimit: dailyLimit,
      dailyUsed: 0.0,
      monthlyLimit: monthlyLimit,
      monthlyUsed: 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.storeId: storeId,
      FirebaseConstants.phoneNumber: phoneNumber,
      FirebaseConstants.walletType: walletType.name,
      FirebaseConstants.walletStatus: walletStatus.name,
      'balance': balance,
      FirebaseConstants.notes: notes,
      FirebaseConstants.isActive: isActive,
      FirebaseConstants.createdAt:
          createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      FirebaseConstants.createdBy: createdBy,
      FirebaseConstants.updatedAt:
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      FirebaseConstants.sendLimits: sendLimits.toMap(),
      FirebaseConstants.receiveLimits: receiveLimits.toMap(),
      FirebaseConstants.lastDailyReset:
          lastDailyReset != null ? Timestamp.fromDate(lastDailyReset!) : null,
      FirebaseConstants.lastMonthlyReset: lastMonthlyReset != null
          ? Timestamp.fromDate(lastMonthlyReset!)
          : null,
      FirebaseConstants.stats: stats.toMap(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'walletId': walletId,
      'storeId': storeId,
      'phoneNumber': phoneNumber,
      'walletType': walletType.name,
      'walletStatus': walletStatus.name,
      'balance': balance,
      'notes': notes,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt?.toIso8601String(),
      'sendLimits': sendLimits.toMap(),
      'receiveLimits': receiveLimits.toMap(),
      'lastDailyReset': lastDailyReset?.toIso8601String(),
      'lastMonthlyReset': lastMonthlyReset?.toIso8601String(),
      'stats': stats.toMap(),
    };
  }

  WalletModel copyWith({
    String? walletId,
    String? storeId,
    String? phoneNumber,
    WalletType? walletType,
    WalletStatus? walletStatus,
    double? balance,
    String? notes,
    bool? isActive,
    bool? isFrozen,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    WalletLimits? sendLimits,
    WalletLimits? receiveLimits,
    DateTime? lastDailyReset,
    DateTime? lastMonthlyReset,
    WalletStats? stats,
  }) {
    return WalletModel(
      walletId: walletId ?? this.walletId,
      storeId: storeId ?? this.storeId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      walletType: walletType ?? this.walletType,
      walletStatus: walletStatus ?? this.walletStatus,
      balance: balance ?? this.balance,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      isFrozen: isFrozen ?? this.isFrozen,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      sendLimits: sendLimits ?? this.sendLimits,
      receiveLimits: receiveLimits ?? this.receiveLimits,
      lastDailyReset: lastDailyReset ?? this.lastDailyReset,
      lastMonthlyReset: lastMonthlyReset ?? this.lastMonthlyReset,
      stats: stats ?? this.stats,
    );
  }

  factory WalletModel.fromWalletStatus({
    required String walletId,
    required String storeId,
    required String phoneNumber,
    required String walletType,
    required String walletStatus,
    required double balance,
    required String createdBy,
    String? notes,
    PlatformSettingsModel? settings,
  }) {
    final now = DateTime.now();
    final typeEnum = WalletType.fromString(walletType);
    final statusEnum = WalletStatus.fromString(walletStatus);

    final resolvedSettings = settings ??
        (sl.isRegistered<PlatformSettingsProvider>()
            ? sl<PlatformSettingsProvider>().settings
            : const PlatformSettingsModel.defaults());

    final NetworkLimits networkLimits;
    if (typeEnum == WalletType.instaPay) {
      networkLimits = resolvedSettings.instapayLimits;
    } else if (statusEnum == WalletStatus.suspended ||
        walletStatus == 'registered_store') {
      networkLimits = resolvedSettings.networkCommercialLimits;
    } else if (statusEnum == WalletStatus.active || walletStatus == 'new') {
      networkLimits = resolvedSettings.networkNewLimits;
    } else {
      networkLimits = resolvedSettings.networkOldLimits;
    }

    return WalletModel(
      walletId: walletId,
      storeId: storeId,
      phoneNumber: phoneNumber,
      walletType: typeEnum,
      walletStatus: statusEnum,
      balance: balance,
      notes: notes,
      isActive: true,
      isFrozen: false,
      createdAt: now,
      createdBy: createdBy,
      lastDailyReset: now,
      lastMonthlyReset: now,
      sendLimits: WalletLimits(
        dailyLimit: networkLimits.dailySend,
        monthlyLimit: networkLimits.monthlySend,
      ),
      receiveLimits: WalletLimits(
        dailyLimit: networkLimits.dailyReceive,
        monthlyLimit: networkLimits.monthlyReceive,
      ),
      stats: WalletStats(),
    );
  }

  NetworkLimits getDynamicNetworkLimits(PlatformSettingsModel settings) {
    final isInstapay = walletType == WalletType.instaPay;
    if (isInstapay) return settings.instapayLimits;

    if (walletStatus == WalletStatus.suspended) {
      return settings.networkCommercialLimits;
    }

    if (walletStatus == WalletStatus.active) {
      return settings.networkNewLimits;
    } else {
      return settings.networkOldLimits;
    }
  }

  bool get needsDailyReset {
    final now = DateTime.now();
    final lastReset = lastDailyReset;
    if (lastReset == null) return true;
    return now.day != lastReset.day ||
        now.month != lastReset.month ||
        now.year != lastReset.year;
  }

  bool get needsMonthlyReset {
    final now = DateTime.now();
    final lastReset = lastMonthlyReset;
    if (lastReset == null) return true;
    return now.month != lastReset.month || now.year != lastReset.year;
  }

  bool canSendAmount(double amount, {double totalFees = 0.0}) {
    final totalDeduction = amount + totalFees;
    final limits = getLimits();
    return balance >= totalDeduction &&
        totalDeduction <= limits.dailyRemaining &&
        !limits.isMonthlyLimitReached &&
        (limits.monthlyRemaining >= totalDeduction);
  }

  bool canReceiveAmount(double amount) {
    final limits = getReceiveLimits();

    return amount <= limits.dailyRemaining &&
        !limits.isMonthlyLimitReached &&
        (limits.monthlyRemaining >= amount);
  }

  WalletLimits getLimits() {
    return sendLimits;
  }

  WalletLimits getReceiveLimits() {
    return receiveLimits;
  }

  String get sendDailyWarningLevel {
    final percentage = getLimits().dailyPercentage;
    if (percentage >= 90) return 'red';
    if (percentage >= 70) return 'yellow';
    return 'green';
  }

  String get sendMonthlyWarningLevel {
    final percentage = getLimits().monthlyPercentage;
    if (percentage >= 90) return 'red';
    if (percentage >= 70) return 'yellow';
    return 'green';
  }

  bool get isInstaPay => walletType == WalletType.instaPay;

  double get availableToReceiveDaily => receiveLimits.dailyRemaining;

  double get availableToReceiveMonthly {
    if (isInstaPay) {
      return receiveLimits.monthlyRemaining;
    }
    final capacityRemaining = receiveLimits.monthlyLimit - balance;
    final safeCapacity = capacityRemaining < 0 ? 0.0 : capacityRemaining;
    return receiveLimits.monthlyRemaining < safeCapacity
        ? receiveLimits.monthlyRemaining
        : safeCapacity;
  }

  @override
  String toString() {
    return 'WalletModel(walletId: $walletId, phoneNumber: $phoneNumber, walletType: $walletType, walletStatus: $walletStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WalletModel &&
        other.walletId == walletId &&
        other.storeId == storeId &&
        other.phoneNumber == phoneNumber &&
        other.walletType == walletType &&
        other.walletStatus == walletStatus &&
        other.balance == balance &&
        other.isActive == isActive &&
        other.isFrozen == isFrozen &&
        other.sendLimits == sendLimits &&
        other.receiveLimits == receiveLimits &&
        other.stats == stats;
  }

  @override
  int get hashCode =>
      walletId.hashCode ^
      storeId.hashCode ^
      phoneNumber.hashCode ^
      walletType.hashCode ^
      walletStatus.hashCode ^
      balance.hashCode ^
      isActive.hashCode ^
      isFrozen.hashCode ^
      sendLimits.hashCode ^
      receiveLimits.hashCode ^
      stats.hashCode;
}
