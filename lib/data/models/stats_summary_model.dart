import 'package:cloud_firestore/cloud_firestore.dart';

class StatsSummaryModel {
  // Wallets
  final int totalWallets;
  final double totalBalance;

  // Transactions
  final int totalTransactions;
  final int sendCount;
  final int receiveCount;
  final double totalSentAmount;
  final double totalReceivedAmount;
  final double totalCommission;

  // Debts
  final int openDebtsCount;
  final int paidDebtsCount;
  final double totalOpenAmount;
  final double totalPaidAmount;

  // Timestamp
  final Timestamp lastUpdated;

  StatsSummaryModel({
    required this.totalWallets,
    required this.totalBalance,
    required this.totalTransactions,
    required this.sendCount,
    required this.receiveCount,
    required this.totalSentAmount,
    required this.totalReceivedAmount,
    required this.totalCommission,
    required this.openDebtsCount,
    required this.paidDebtsCount,
    required this.totalOpenAmount,
    required this.totalPaidAmount,
    required this.lastUpdated,
  });

  factory StatsSummaryModel.fromMap(Map<String, dynamic> map) {
    return StatsSummaryModel(
      totalWallets: map['totalWallets'] ?? 0,
      totalBalance: (map['totalBalance'] ?? 0.0).toDouble(),
      totalTransactions: map['totalTransactions'] ?? 0,
      sendCount: map['sendCount'] ?? 0,
      receiveCount: map['receiveCount'] ?? 0,
      totalSentAmount: (map['totalSentAmount'] ?? 0.0).toDouble(),
      totalReceivedAmount: (map['totalReceivedAmount'] ?? 0.0).toDouble(),
      totalCommission: (map['totalCommission'] ?? 0.0).toDouble(),
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
      'totalBalance': totalBalance,
      'totalTransactions': totalTransactions,
      'sendCount': sendCount,
      'receiveCount': receiveCount,
      'totalSentAmount': totalSentAmount,
      'totalReceivedAmount': totalReceivedAmount,
      'totalCommission': totalCommission,
      'openDebtsCount': openDebtsCount,
      'paidDebtsCount': paidDebtsCount,
      'totalOpenAmount': totalOpenAmount,
      'totalPaidAmount': totalPaidAmount,
      'lastUpdated': lastUpdated,
    };
  }

  StatsSummaryModel copyWith({
    int? totalWallets,
    double? totalBalance,
    int? totalTransactions,
    int? sendCount,
    int? receiveCount,
    double? totalSentAmount,
    double? totalReceivedAmount,
    double? totalCommission,
    int? openDebtsCount,
    int? paidDebtsCount,
    double? totalOpenAmount,
    double? totalPaidAmount,
    Timestamp? lastUpdated,
  }) {
    return StatsSummaryModel(
      totalWallets: totalWallets ?? this.totalWallets,
      totalBalance: totalBalance ?? this.totalBalance,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      sendCount: sendCount ?? this.sendCount,
      receiveCount: receiveCount ?? this.receiveCount,
      totalSentAmount: totalSentAmount ?? this.totalSentAmount,
      totalReceivedAmount: totalReceivedAmount ?? this.totalReceivedAmount,
      totalCommission: totalCommission ?? this.totalCommission,
      openDebtsCount: openDebtsCount ?? this.openDebtsCount,
      paidDebtsCount: paidDebtsCount ?? this.paidDebtsCount,
      totalOpenAmount: totalOpenAmount ?? this.totalOpenAmount,
      totalPaidAmount: totalPaidAmount ?? this.totalPaidAmount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static StatsSummaryModel empty() {
    return StatsSummaryModel(
      totalWallets: 0,
      totalBalance: 0.0,
      totalTransactions: 0,
      sendCount: 0,
      receiveCount: 0,
      totalSentAmount: 0.0,
      totalReceivedAmount: 0.0,
      totalCommission: 0.0,
      openDebtsCount: 0,
      paidDebtsCount: 0,
      totalOpenAmount: 0.0,
      totalPaidAmount: 0.0,
      lastUpdated: Timestamp.fromDate(DateTime(2000)),
    );
  }
}
