import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/utils/number_parser.dart';

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
      dailyLimit > 0 ? (dailyUsed / dailyLimit) * 100 : 0;
  double get monthlyPercentage =>
      monthlyLimit > 0 ? (monthlyUsed / monthlyLimit) * 100 : 0;
  bool get isDailyLimitReached => dailyUsed >= dailyLimit;
  bool get isMonthlyLimitReached => monthlyUsed >= monthlyLimit;
}

class WalletStats {
  final int totalTransactions;
  final double totalSentAmount;
  final double totalReceivedAmount;
  final double totalCommission;
  final DateTime? lastTransactionDate;

  WalletStats({
    this.totalTransactions = 0,
    this.totalSentAmount = 0.0,
    this.totalReceivedAmount = 0.0,
    this.totalCommission = 0.0,
    this.lastTransactionDate,
  });

  factory WalletStats.fromMap(Map<String, dynamic> map) {
    return WalletStats(
      totalTransactions: NumberParser.toInt(map['totalTransactions']),
      totalSentAmount: NumberParser.toDouble(map['totalSentAmount']),
      totalReceivedAmount: NumberParser.toDouble(map['totalReceivedAmount']),
      totalCommission: NumberParser.toDouble(map['totalCommission']),
      lastTransactionDate: (map['lastTransactionDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalTransactions': totalTransactions,
      'totalSentAmount': totalSentAmount,
      'totalReceivedAmount': totalReceivedAmount,
      'totalCommission': totalCommission,
      'lastTransactionDate': lastTransactionDate != null ? Timestamp.fromDate(lastTransactionDate!) : null,
    };
  }

  WalletStats copyWith({
    int? totalTransactions,
    double? totalSentAmount,
    double? totalReceivedAmount,
    double? totalCommission,
    DateTime? lastTransactionDate,
  }) {
    return WalletStats(
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalSentAmount: totalSentAmount ?? this.totalSentAmount,
      totalReceivedAmount: totalReceivedAmount ?? this.totalReceivedAmount,
      totalCommission: totalCommission ?? this.totalCommission,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }

  double get totalAmount => totalSentAmount + totalReceivedAmount;
}

class WalletModel {
  final String walletId;
  final String storeId;
  final String phoneNumber;
  final String walletType;
  final String walletStatus;
  final double balance;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final WalletLimits sendLimits;
  final WalletLimits receiveLimits;
  final DateTime lastDailyReset;
  final DateTime lastMonthlyReset;
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
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    required this.sendLimits,
    required this.receiveLimits,
    required this.lastDailyReset,
    required this.lastMonthlyReset,
    required this.stats,
  });

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel.fromMap(data, doc.id);
  }

  factory WalletModel.fromMap(Map<String, dynamic> data, String docId) {
    final createdAt = (data[FirebaseConstants.createdAt] as Timestamp?)?.toDate();
    if (createdAt == null) {
      throw const FormatException('Missing or invalid createdAt in WalletModel');
    }

    final lastDailyReset = (data[FirebaseConstants.lastDailyReset] as Timestamp?)?.toDate();
    if (lastDailyReset == null) {
      throw const FormatException('Missing or invalid lastDailyReset in WalletModel');
    }

    final lastMonthlyReset = (data[FirebaseConstants.lastMonthlyReset] as Timestamp?)?.toDate();
    if (lastMonthlyReset == null) {
      throw const FormatException('Missing or invalid lastMonthlyReset in WalletModel');
    }

    return WalletModel(
      walletId: docId,
      storeId: data[FirebaseConstants.storeId] ?? '',
      phoneNumber: data[FirebaseConstants.phoneNumber] ?? '',
      walletType: data[FirebaseConstants.walletType] ?? '',
      walletStatus: data[FirebaseConstants.walletStatus] ?? 'new',
      balance: NumberParser.toDouble(data['balance']),
      notes: data[FirebaseConstants.notes],
      isActive: data[FirebaseConstants.isActive] ?? true,
      createdAt: createdAt,
      createdBy: data[FirebaseConstants.createdBy] ?? '',
      updatedAt: (data[FirebaseConstants.updatedAt] as Timestamp?)?.toDate(),
      sendLimits:
          WalletLimits.fromMap(data[FirebaseConstants.sendLimits] ?? {}),
      receiveLimits:
          WalletLimits.fromMap(data[FirebaseConstants.receiveLimits] ?? {}),
      lastDailyReset: lastDailyReset,
      lastMonthlyReset: lastMonthlyReset,
      stats: WalletStats.fromMap(data[FirebaseConstants.stats] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.storeId: storeId,
      FirebaseConstants.phoneNumber: phoneNumber,
      FirebaseConstants.walletType: walletType,
      FirebaseConstants.walletStatus: walletStatus,
      'balance': balance,
      FirebaseConstants.notes: notes,
      FirebaseConstants.isActive: isActive,
      FirebaseConstants.createdAt: Timestamp.fromDate(createdAt),
      FirebaseConstants.createdBy: createdBy,
      FirebaseConstants.updatedAt: updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      FirebaseConstants.sendLimits: sendLimits.toMap(),
      FirebaseConstants.receiveLimits: receiveLimits.toMap(),
      FirebaseConstants.lastDailyReset: Timestamp.fromDate(lastDailyReset),
      FirebaseConstants.lastMonthlyReset: Timestamp.fromDate(lastMonthlyReset),
      FirebaseConstants.stats: stats.toMap(),
    };
  }

  WalletModel copyWith({
    String? walletId,
    String? storeId,
    String? phoneNumber,
    String? walletType,
    String? walletStatus,
    double? balance,
    String? notes,
    bool? isActive,
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
  }) {
    final now = DateTime.now();
    final isNew = walletStatus == 'new';
    final isInstapay = walletType == 'instapay';

    final double dailyLimit = isInstapay
        ? AppConstants.instapayTransactionLimit
        : (isNew
            ? AppConstants.newWalletTransactionLimit
            : (walletStatus == 'registered_store'
                ? AppConstants.registeredStoreTransactionLimit
                : AppConstants.oldWalletTransactionLimit));

    final double monthlyLimit = isInstapay
        ? AppConstants.instapayMonthlyLimit
        : (isNew
            ? AppConstants.newWalletMonthlyLimit
            : (walletStatus == 'registered_store'
                ? AppConstants.registeredStoreMonthlyLimit
                : AppConstants.oldWalletMonthlyLimit));

    return WalletModel(
      walletId: walletId,
      storeId: storeId,
      phoneNumber: phoneNumber,
      walletType: walletType,
      walletStatus: walletStatus,
      balance: balance,
      notes: notes,
      isActive: true,
      createdAt: now,
      createdBy: createdBy,
      lastDailyReset: now,
      lastMonthlyReset: now,
      sendLimits: WalletLimits(
        dailyLimit: dailyLimit,
        monthlyLimit: monthlyLimit,
      ),
      receiveLimits: WalletLimits(
        dailyLimit: dailyLimit,
        monthlyLimit: monthlyLimit,
      ),
      stats: WalletStats(),
    );
  }

  bool get needsDailyReset {
    final now = DateTime.now();
    final lastReset = lastDailyReset;
    return now.day != lastReset.day ||
        now.month != lastReset.month ||
        now.year != lastReset.year;
  }

  bool get needsMonthlyReset {
    final now = DateTime.now();
    final lastReset = lastMonthlyReset;
    return now.month != lastReset.month || now.year != lastReset.year;
  }

  bool canSendAmount(double amount) {
    // New Logic: Check Transaction Cap and Monthly Cap.
    // Daily Limit in the model now represents Transaction Limit.
    final limits = getLimits();
    return amount <= limits.dailyLimit &&
        !limits.isMonthlyLimitReached &&
        (limits.monthlyRemaining >= amount);
  }

  bool canReceiveAmount(double amount) {
    // New Logic: Check Transaction Cap and Monthly Cap.
    // Daily Limit in the model now represents Transaction Limit.
    final limits = getReceiveLimits();

    return amount <= limits.dailyLimit &&
        !limits.isMonthlyLimitReached &&
        (limits.monthlyRemaining >= amount);
  }

  // Helper to get limits easily as requested
  WalletLimits getLimits() {
    if (walletStatus == 'registered_store') {
      return sendLimits.copyWith(
        dailyLimit: AppConstants.registeredStoreTransactionLimit,
      );
    }
    return sendLimits;
  }

  WalletLimits getReceiveLimits() {
    if (walletStatus == 'registered_store') {
      return receiveLimits.copyWith(
        dailyLimit: AppConstants.registeredStoreTransactionLimit,
      );
    }
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

  @override
  String toString() {
    return 'WalletModel(walletId: $walletId, phoneNumber: $phoneNumber, walletType: $walletType, walletStatus: $walletStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WalletModel &&
        other.walletId == walletId &&
        other.balance == balance &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => walletId.hashCode ^ balance.hashCode ^ isActive.hashCode;
}
