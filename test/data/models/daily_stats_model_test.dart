import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';

void main() {
  group('DailyStatsModel Tests', () {
    test('empty factory should initialize all fields to zero', () {
      final stats = DailyStatsModel.empty('2026-05-26');
      expect(stats.date, '2026-05-26');
      expect(stats.totalTransactions, 0);
      expect(stats.totalCommission, 0.0);

      // New fields
      expect(stats.sendCount, 0);
      expect(stats.receiveCount, 0);
      expect(stats.totalSentAmount, 0.0);
      expect(stats.totalReceivedAmount, 0.0);
      expect(stats.openDebtsCount, 0);
      expect(stats.totalOpenAmount, 0.0);
      expect(stats.paidDebtsCount, 0);
      expect(stats.totalPaidAmount, 0.0);
    });

    test('fromMap should parse all fields including new metrics', () {
      final map = {
        'transactionCount': 5,
        'totalCommission': 25.0,
        'sendCount': 3,
        'receiveCount': 2,
        'totalSentAmount': 300.0,
        'totalReceivedAmount': 200.0,
        'openDebtsCount': 2,
        'totalOpenAmount': 150.0,
        'paidDebtsCount': 1,
        'totalPaidAmount': 50.0,
      };

      final stats = DailyStatsModel.fromMap(map, '2026-05-26');

      expect(stats.date, '2026-05-26');
      expect(stats.totalTransactions, 5);
      expect(stats.totalCommission, 25.0);
      expect(stats.sendCount, 3);
      expect(stats.receiveCount, 2);
      expect(stats.totalSentAmount, 300.0);
      expect(stats.totalReceivedAmount, 200.0);
      expect(stats.openDebtsCount, 2);
      expect(stats.totalOpenAmount, 150.0);
      expect(stats.paidDebtsCount, 1);
      expect(stats.totalPaidAmount, 50.0);
    });

    test('toMap should serialize all fields including new metrics', () {
      final stats = DailyStatsModel(
        date: '2026-05-26',
        totalTransactions: 5,
        totalCommission: 25.0,
        sendCount: 3,
        receiveCount: 2,
        totalSentAmount: 300.0,
        totalReceivedAmount: 200.0,
        openDebtsCount: 2,
        totalOpenAmount: 150.0,
        paidDebtsCount: 1,
        totalPaidAmount: 50.0,
      );

      final map = stats.toMap();

      expect(map['date'], '2026-05-26');
      expect(map['transactionCount'], 5);
      expect(map['totalCommission'], 25.0);
      expect(map['sendCount'], 3);
      expect(map['receiveCount'], 2);
      expect(map['totalSentAmount'], 300.0);
      expect(map['totalReceivedAmount'], 200.0);
      expect(map['openDebtsCount'], 2);
      expect(map['totalOpenAmount'], 150.0);
      expect(map['paidDebtsCount'], 1);
      expect(map['totalPaidAmount'], 50.0);

      // Verify that removed fields are not present
      expect(map.containsKey('totalAmount'), isFalse);
      expect(map.containsKey('totalServiceFee'), isFalse);
    });

    test('copyWith should correctly clone and modify selected fields', () {
      final stats = DailyStatsModel.empty('2026-05-26');

      final updated = stats.copyWith(
        totalTransactions: 10,
        sendCount: 6,
        totalSentAmount: 600.0,
      );

      expect(updated.date, '2026-05-26');
      expect(updated.totalTransactions, 10);
      expect(updated.sendCount, 6);
      expect(updated.totalSentAmount, 600.0);
      expect(updated.receiveCount, 0); // Unchanged
    });
  });
}
