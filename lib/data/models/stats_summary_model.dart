import 'package:cloud_firestore/cloud_firestore.dart';

class StatsSummaryModel {
  // Wallets
  final int totalWallets;
  final int activeWallets; // تمت الإضافة
  final double totalBalance;

  // Employees
  final int totalEmployees; // تمت الإضافة

  // Transactions
  final int totalTransactions;
  final int totalTransactionsToday; // تمت الإضافة
  final int sendCount;
  final int receiveCount;
  final double totalSentAmount;
  final double totalReceivedAmount;
  final double totalCommission;
  final double totalCommissionToday; // تمت الإضافة

  // Debts
  final int openDebtsCount;
  final int paidDebtsCount;
  final double totalOpenAmount;
  final double totalPaidAmount;

  // Timestamp
  final Timestamp lastUpdated;

  StatsSummaryModel({
    required this.totalWallets,
    required this.activeWallets,
    required this.totalBalance,
    required this.totalEmployees,
    required this.totalTransactions,
    required this.totalTransactionsToday,
    required this.sendCount,
    required this.receiveCount,
    required this.totalSentAmount,
    required this.totalReceivedAmount,
    required this.totalCommission,
    required this.totalCommissionToday,
    required this.openDebtsCount,
    required this.paidDebtsCount,
    required this.totalOpenAmount,
    required this.totalPaidAmount,
    required this.lastUpdated,
  });

  factory StatsSummaryModel.fromMap(Map<String, dynamic> map) {
    return StatsSummaryModel(
      totalWallets: map['totalWallets'] ?? 0,
      activeWallets: map['activeWallets'] ?? 0,
      totalBalance: (map['totalBalance'] ?? 0.0).toDouble(),
      totalEmployees: map['totalEmployees'] ?? 0,
      totalTransactions: map['totalTransactions'] ?? 0,
      totalTransactionsToday: map['totalTransactionsToday'] ?? 0,
      sendCount: map['sendCount'] ?? 0,
      receiveCount: map['receiveCount'] ?? 0,
      totalSentAmount: (map['totalSentAmount'] ?? 0.0).toDouble(),
      totalReceivedAmount: (map['totalReceivedAmount'] ?? 0.0).toDouble(),
      totalCommission: (map['totalCommission'] ?? 0.0).toDouble(),
      totalCommissionToday: (map['totalCommissionToday'] ?? 0.0).toDouble(),
      openDebtsCount: map['openDebtsCount'] ?? 0,
      paidDebtsCount: map['paidDebtsCount'] ?? 0,
      totalOpenAmount: (map['totalOpenAmount'] ?? 0.0).toDouble(),
      totalPaidAmount: (map['totalPaidAmount'] ?? 0.0).toDouble(),
      lastUpdated: map['lastUpdated'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalWallets': totalWallets,
      'activeWallets': activeWallets,
      'totalBalance': totalBalance,
      'totalEmployees': totalEmployees,
      'totalTransactions': totalTransactions,
      'totalTransactionsToday': totalTransactionsToday,
      'sendCount': sendCount,
      'receiveCount': receiveCount,
      'totalSentAmount': totalSentAmount,
      'totalReceivedAmount': totalReceivedAmount,
      'totalCommission': totalCommission,
      'totalCommissionToday': totalCommissionToday,
      'openDebtsCount': openDebtsCount,
      'paidDebtsCount': paidDebtsCount,
      'totalOpenAmount': totalOpenAmount,
      'totalPaidAmount': totalPaidAmount,
      'lastUpdated': lastUpdated,
    };
  }

  StatsSummaryModel copyWith({
    int? totalWallets,
    int? activeWallets,
    double? totalBalance,
    int? totalEmployees,
    int? totalTransactions,
    int? totalTransactionsToday,
    int? sendCount,
    int? receiveCount,
    double? totalSentAmount,
    double? totalReceivedAmount,
    double? totalCommission,
    double? totalCommissionToday,
    int? openDebtsCount,
    int? paidDebtsCount,
    double? totalOpenAmount,
    double? totalPaidAmount,
    Timestamp? lastUpdated,
  }) {
    return StatsSummaryModel(
      totalWallets: totalWallets ?? this.totalWallets,
      activeWallets: activeWallets ?? this.activeWallets,
      totalBalance: totalBalance ?? this.totalBalance,
      totalEmployees: totalEmployees ?? this.totalEmployees,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalTransactionsToday:
          totalTransactionsToday ?? this.totalTransactionsToday,
      sendCount: sendCount ?? this.sendCount,
      receiveCount: receiveCount ?? this.receiveCount,
      totalSentAmount: totalSentAmount ?? this.totalSentAmount,
      totalReceivedAmount: totalReceivedAmount ?? this.totalReceivedAmount,
      totalCommission: totalCommission ?? this.totalCommission,
      totalCommissionToday: totalCommissionToday ?? this.totalCommissionToday,
      openDebtsCount: openDebtsCount ?? this.openDebtsCount,
      paidDebtsCount: paidDebtsCount ?? this.paidDebtsCount,
      totalOpenAmount: totalOpenAmount ?? this.totalOpenAmount,
      totalPaidAmount: totalPaidAmount ?? this.totalPaidAmount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // الدالة المهمة لإنشاء بيانات صفرية عند التسجيل
  static StatsSummaryModel empty() {
    return StatsSummaryModel(
      totalWallets: 0,
      activeWallets: 0,
      totalBalance: 0.0,
      totalEmployees: 0,
      totalTransactions: 0,
      totalTransactionsToday: 0,
      sendCount: 0,
      receiveCount: 0,
      totalSentAmount: 0.0,
      totalReceivedAmount: 0.0,
      totalCommission: 0.0,
      totalCommissionToday: 0.0,
      openDebtsCount: 0,
      paidDebtsCount: 0,
      totalOpenAmount: 0.0,
      totalPaidAmount: 0.0,
      lastUpdated: Timestamp.now(), // استخدام الوقت الحالي أفضل
    );
  }
}
