import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/number_parser.dart';

class StatsSummaryToday {
  final double totalCommission;
  final int totalTransactions;

  StatsSummaryToday({
    this.totalCommission = 0.0,
    this.totalTransactions = 0,
  });

  factory StatsSummaryToday.fromMap(Map<String, dynamic> map) {
    return StatsSummaryToday(
      totalCommission: NumberParser.toDouble(map['totalCommission']),
      totalTransactions: NumberParser.toInt(map['totalTransactions']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCommission': totalCommission,
      'totalTransactions': totalTransactions,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatsSummaryToday &&
        other.totalCommission == totalCommission &&
        other.totalTransactions == totalTransactions;
  }

  @override
  int get hashCode => totalCommission.hashCode ^ totalTransactions.hashCode;
}

class StatsSummaryModel {
  // Wallets
  final int totalWallets;
  final int activeWallets;
  final double totalBalance;

  // Transactions
  final int totalTransactions;
  final double totalSentAmount;
  final double totalReceivedAmount;
  final int sendCount;
  final int receiveCount;

  // Commission
  final double totalCommission;

  // Debts
  final int openDebtsCount;
  final int paidDebtsCount;
  final double totalOpenAmount;
  final double totalPaidAmount;

  final DateTime? lastUpdated;

  StatsSummaryModel({
    this.totalWallets = 0,
    this.activeWallets = 0,
    this.totalBalance = 0.0,
    this.totalTransactions = 0,
    this.totalSentAmount = 0.0,
    this.totalReceivedAmount = 0.0,
    this.sendCount = 0,
    this.receiveCount = 0,
    this.totalCommission = 0.0,
    this.openDebtsCount = 0,
    this.paidDebtsCount = 0,
    this.totalOpenAmount = 0.0,
    this.totalPaidAmount = 0.0,
    this.lastUpdated,
  });

  factory StatsSummaryModel.fromMap(Map<String, dynamic> data) {
    return StatsSummaryModel(
      totalWallets: NumberParser.toInt(data['totalWallets']),
      activeWallets: NumberParser.toInt(data['activeWallets']),
      totalBalance: NumberParser.toDouble(data['totalBalance']),
      totalTransactions: NumberParser.toInt(data['totalTransactions']),
      totalSentAmount: NumberParser.toDouble(data['totalSentAmount']),
      totalReceivedAmount: NumberParser.toDouble(data['totalReceivedAmount']),
      sendCount: NumberParser.toInt(data['sendCount']),
      receiveCount: NumberParser.toInt(data['receiveCount']),
      totalCommission: NumberParser.toDouble(data['totalCommission']),
      openDebtsCount: NumberParser.toInt(data['openDebtsCount']),
      paidDebtsCount: NumberParser.toInt(data['paidDebtsCount']),
      totalOpenAmount: NumberParser.toDouble(data['totalOpenAmount']),
      totalPaidAmount: NumberParser.toDouble(data['totalPaidAmount']),
      // Phase 3: No more silent fallback to DateTime.now()
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalWallets': totalWallets,
      'activeWallets': activeWallets,
      'totalBalance': totalBalance,
      'totalTransactions': totalTransactions,
      'totalSentAmount': totalSentAmount,
      'totalReceivedAmount': totalReceivedAmount,
      'sendCount': sendCount,
      'receiveCount': receiveCount,
      'totalCommission': totalCommission,
      'openDebtsCount': openDebtsCount,
      'paidDebtsCount': paidDebtsCount,
      'totalOpenAmount': totalOpenAmount,
      'totalPaidAmount': totalPaidAmount,
      'lastUpdated':
          lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }

  StatsSummaryModel copyWith({
    int? totalWallets,
    int? activeWallets,
    double? totalBalance,
    int? totalTransactions,
    double? totalSentAmount,
    double? totalReceivedAmount,
    int? sendCount,
    int? receiveCount,
    double? totalCommission,
    int? openDebtsCount,
    int? paidDebtsCount,
    double? totalOpenAmount,
    double? totalPaidAmount,
    DateTime? lastUpdated,
  }) {
    return StatsSummaryModel(
      totalWallets: totalWallets ?? this.totalWallets,
      activeWallets: activeWallets ?? this.activeWallets,
      totalBalance: totalBalance ?? this.totalBalance,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalSentAmount: totalSentAmount ?? this.totalSentAmount,
      totalReceivedAmount: totalReceivedAmount ?? this.totalReceivedAmount,
      sendCount: sendCount ?? this.sendCount,
      receiveCount: receiveCount ?? this.receiveCount,
      totalCommission: totalCommission ?? this.totalCommission,
      openDebtsCount: openDebtsCount ?? this.openDebtsCount,
      paidDebtsCount: paidDebtsCount ?? this.paidDebtsCount,
      totalOpenAmount: totalOpenAmount ?? this.totalOpenAmount,
      totalPaidAmount: totalPaidAmount ?? this.totalPaidAmount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatsSummaryModel &&
        other.totalWallets == totalWallets &&
        other.activeWallets == activeWallets &&
        other.totalBalance == totalBalance &&
        other.totalTransactions == totalTransactions &&
        other.totalSentAmount == totalSentAmount &&
        other.totalReceivedAmount == totalReceivedAmount &&
        other.sendCount == sendCount &&
        other.receiveCount == receiveCount &&
        other.totalCommission == totalCommission &&
        other.openDebtsCount == openDebtsCount &&
        other.paidDebtsCount == paidDebtsCount &&
        other.totalOpenAmount == totalOpenAmount &&
        other.totalPaidAmount == totalPaidAmount &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode =>
      totalWallets.hashCode ^
      activeWallets.hashCode ^
      totalBalance.hashCode ^
      totalTransactions.hashCode ^
      totalSentAmount.hashCode ^
      totalReceivedAmount.hashCode ^
      sendCount.hashCode ^
      receiveCount.hashCode ^
      totalCommission.hashCode ^
      openDebtsCount.hashCode ^
      paidDebtsCount.hashCode ^
      totalOpenAmount.hashCode ^
      totalPaidAmount.hashCode ^
      lastUpdated.hashCode;

  factory StatsSummaryModel.empty() {
    return StatsSummaryModel(
      totalWallets: 0,
      activeWallets: 0,
      totalBalance: 0.0,
      totalTransactions: 0,
      totalSentAmount: 0.0,
      totalReceivedAmount: 0.0,
      sendCount: 0,
      receiveCount: 0,
      totalCommission: 0.0,
      openDebtsCount: 0,
      paidDebtsCount: 0,
      totalOpenAmount: 0.0,
      totalPaidAmount: 0.0,
      lastUpdated: null,
    );
  }
}
