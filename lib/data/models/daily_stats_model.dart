import '../../core/utils/number_parser.dart';

class DailyStatsModel {
  final String date;
  final int totalTransactions;
  final double totalCommission;

  // New fields
  final int sendCount;
  final int receiveCount;
  final double totalSentAmount;
  final double totalReceivedAmount;
  final int openDebtsCount;
  final double totalOpenAmount;
  final int paidDebtsCount;
  final double totalPaidAmount;
  final double totalServiceFee;
  final double totalAmount;

  DailyStatsModel({
    required this.date,
    required this.totalTransactions,
    required this.totalCommission,
    this.sendCount = 0,
    this.receiveCount = 0,
    this.totalSentAmount = 0.0,
    this.totalReceivedAmount = 0.0,
    this.openDebtsCount = 0,
    this.totalOpenAmount = 0.0,
    this.paidDebtsCount = 0,
    this.totalPaidAmount = 0.0,
    this.totalServiceFee = 0.0,
    this.totalAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'transactionCount': totalTransactions,
      'totalCommission': totalCommission,
      'sendCount': sendCount,
      'receiveCount': receiveCount,
      'totalSentAmount': totalSentAmount,
      'totalReceivedAmount': totalReceivedAmount,
      'openDebtsCount': openDebtsCount,
      'totalOpenAmount': totalOpenAmount,
      'paidDebtsCount': paidDebtsCount,
      'totalPaidAmount': totalPaidAmount,
      'totalServiceFee': totalServiceFee,
      'totalAmount': totalAmount,
    };
  }

  factory DailyStatsModel.fromMap(Map<String, dynamic> map, String docId) {
    return DailyStatsModel(
      date: docId,
      totalTransactions: NumberParser.toInt(map['transactionCount']),
      totalCommission: NumberParser.toDouble(map['totalCommission']),
      sendCount: NumberParser.toInt(map['sendCount']),
      receiveCount: NumberParser.toInt(map['receiveCount']),
      totalSentAmount: NumberParser.toDouble(map['totalSentAmount']),
      totalReceivedAmount: NumberParser.toDouble(map['totalReceivedAmount']),
      openDebtsCount: NumberParser.toInt(map['openDebtsCount']),
      totalOpenAmount: NumberParser.toDouble(map['totalOpenAmount']),
      paidDebtsCount: NumberParser.toInt(map['paidDebtsCount']),
      totalPaidAmount: NumberParser.toDouble(map['totalPaidAmount']),
      totalServiceFee: NumberParser.toDouble(map['totalServiceFee']),
      totalAmount: NumberParser.toDouble(map['totalAmount']),
    );
  }

  factory DailyStatsModel.empty(String date) {
    return DailyStatsModel(
      date: date,
      totalTransactions: 0,
      totalCommission: 0.0,
      sendCount: 0,
      receiveCount: 0,
      totalSentAmount: 0.0,
      totalReceivedAmount: 0.0,
      openDebtsCount: 0,
      totalOpenAmount: 0.0,
      paidDebtsCount: 0,
      totalPaidAmount: 0.0,
      totalServiceFee: 0.0,
      totalAmount: 0.0,
    );
  }

  DailyStatsModel copyWith({
    String? date,
    int? totalTransactions,
    double? totalCommission,
    int? sendCount,
    int? receiveCount,
    double? totalSentAmount,
    double? totalReceivedAmount,
    int? openDebtsCount,
    double? totalOpenAmount,
    int? paidDebtsCount,
    double? totalPaidAmount,
    double? totalServiceFee,
    double? totalAmount,
  }) {
    return DailyStatsModel(
      date: date ?? this.date,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalCommission: totalCommission ?? this.totalCommission,
      sendCount: sendCount ?? this.sendCount,
      receiveCount: receiveCount ?? this.receiveCount,
      totalSentAmount: totalSentAmount ?? this.totalSentAmount,
      totalReceivedAmount: totalReceivedAmount ?? this.totalReceivedAmount,
      openDebtsCount: openDebtsCount ?? this.openDebtsCount,
      totalOpenAmount: totalOpenAmount ?? this.totalOpenAmount,
      paidDebtsCount: paidDebtsCount ?? this.paidDebtsCount,
      totalPaidAmount: totalPaidAmount ?? this.totalPaidAmount,
      totalServiceFee: totalServiceFee ?? this.totalServiceFee,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
