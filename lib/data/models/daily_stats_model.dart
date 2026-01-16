class DailyStatsModel {
  final String date;
  final int transactionCount;
  final double totalCommission;
  final double totalAmount;

  DailyStatsModel({
    required this.date,
    required this.transactionCount,
    required this.totalCommission,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'transactionCount': transactionCount,
      'totalCommission': totalCommission,
      'totalAmount': totalAmount,
    };
  }

  factory DailyStatsModel.fromMap(Map<String, dynamic> map, String docId) {
    return DailyStatsModel(
      date: docId,
      transactionCount: (map['transactionCount'] ?? 0) as int,
      totalCommission: (map['totalCommission'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
    );
  }

  factory DailyStatsModel.empty(String date) {
    return DailyStatsModel(
      date: date,
      transactionCount: 0,
      totalCommission: 0.0,
      totalAmount: 0.0,
    );
  }
}
