import '../../core/utils/number_parser.dart';

class DailyStatsModel {
  final String date;
  final int transactionCount;
  final double totalCommission;
  final double totalServiceFee;
  final double totalAmount;

  DailyStatsModel({
    required this.date,
    required this.transactionCount,
    required this.totalCommission,
    required this.totalServiceFee,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'transactionCount': transactionCount,
      'totalCommission': totalCommission,
      'totalServiceFee': totalServiceFee,
      'totalAmount': totalAmount,
    };
  }

  factory DailyStatsModel.fromMap(Map<String, dynamic> map, String docId) {
    return DailyStatsModel(
      date: docId,
      transactionCount: NumberParser.toInt(map['transactionCount']),
      totalCommission: NumberParser.toDouble(map['totalCommission']),
      totalServiceFee: NumberParser.toDouble(map['totalServiceFee']),
      totalAmount: NumberParser.toDouble(map['totalAmount']),
    );
  }

  factory DailyStatsModel.empty(String date) {
    return DailyStatsModel(
      date: date,
      transactionCount: 0,
      totalCommission: 0.0,
      totalServiceFee: 0.0,
      totalAmount: 0.0,
    );
  }

  DailyStatsModel copyWith({
    String? date,
    int? transactionCount,
    double? totalCommission,
    double? totalServiceFee,
    double? totalAmount,
  }) {
    return DailyStatsModel(
      date: date ?? this.date,
      transactionCount: transactionCount ?? this.transactionCount,
      totalCommission: totalCommission ?? this.totalCommission,
      totalServiceFee: totalServiceFee ?? this.totalServiceFee,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
