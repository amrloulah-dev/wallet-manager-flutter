import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';

void main() {
  group('StatsSummaryModel Tests', () {
    test('empty factory should initialize all fields to zero/null', () {
      final stats = StatsSummaryModel.empty();
      expect(stats.totalWallets, 0);
      expect(stats.activeWallets, 0);
      expect(stats.totalBalance, 0.0);
      expect(stats.totalTransactions, 0);
      expect(stats.totalSentAmount, 0.0);
      expect(stats.totalReceivedAmount, 0.0);
      expect(stats.sendCount, 0);
      expect(stats.receiveCount, 0);
      expect(stats.totalCommission, 0.0);
      expect(stats.openDebtsCount, 0);
      expect(stats.paidDebtsCount, 0);
      expect(stats.totalOpenAmount, 0.0);
      expect(stats.totalPaidAmount, 0.0);
      expect(stats.lastUpdated, isNull);
    });

    test('fromMap should parse all fields and default missing fields to zero',
        () {
      final map = {
        'totalWallets': 10,
        'activeWallets': 8,
        'totalBalance': 5000.0,
        'totalTransactions': 100,
        'totalSentAmount': 3000.0,
        'totalReceivedAmount': 2000.0,
        'sendCount': 60,
        'receiveCount': 40,
        'totalCommission': 150.0,
        'openDebtsCount': 5,
        'paidDebtsCount': 12,
        'totalOpenAmount': 800.0,
        'totalPaidAmount': 1200.0,
        'lastUpdated': Timestamp.fromDate(DateTime(2026, 6, 12)),
      };

      final stats = StatsSummaryModel.fromMap(map);

      expect(stats.totalWallets, 10);
      expect(stats.activeWallets, 8);
      expect(stats.totalBalance, 5000.0);
      expect(stats.totalTransactions, 100);
      expect(stats.totalSentAmount, 3000.0);
      expect(stats.totalReceivedAmount, 2000.0);
      expect(stats.sendCount, 60);
      expect(stats.receiveCount, 40);
      expect(stats.totalCommission, 150.0);
      expect(stats.openDebtsCount, 5);
      expect(stats.paidDebtsCount, 12);
      expect(stats.totalOpenAmount, 800.0);
      expect(stats.totalPaidAmount, 1200.0);
      expect(stats.lastUpdated, DateTime(2026, 6, 12));
    });

    test('fromMap should gracefully default missing fields to zero', () {
      final stats = StatsSummaryModel.fromMap({});
      expect(stats.totalWallets, 0);
      expect(stats.activeWallets, 0);
      expect(stats.totalBalance, 0.0);
      expect(stats.totalTransactions, 0);
      expect(stats.totalSentAmount, 0.0);
      expect(stats.totalReceivedAmount, 0.0);
      expect(stats.sendCount, 0);
      expect(stats.receiveCount, 0);
      expect(stats.totalCommission, 0.0);
      expect(stats.openDebtsCount, 0);
      expect(stats.paidDebtsCount, 0);
      expect(stats.totalOpenAmount, 0.0);
      expect(stats.totalPaidAmount, 0.0);
      expect(stats.lastUpdated, isNull);
    });

    test('toMap should serialize all kept fields', () {
      final lastUpdated = DateTime(2026, 6, 12);
      final stats = StatsSummaryModel(
        totalWallets: 10,
        activeWallets: 8,
        totalBalance: 5000.0,
        totalTransactions: 100,
        totalSentAmount: 3000.0,
        totalReceivedAmount: 2000.0,
        sendCount: 60,
        receiveCount: 40,
        totalCommission: 150.0,
        openDebtsCount: 5,
        paidDebtsCount: 12,
        totalOpenAmount: 800.0,
        totalPaidAmount: 1200.0,
        lastUpdated: lastUpdated,
      );

      final map = stats.toMap();

      expect(map['totalWallets'], 10);
      expect(map['activeWallets'], 8);
      expect(map['totalBalance'], 5000.0);
      expect(map['totalTransactions'], 100);
      expect(map['totalSentAmount'], 3000.0);
      expect(map['totalReceivedAmount'], 2000.0);
      expect(map['sendCount'], 60);
      expect(map['receiveCount'], 40);
      expect(map['totalCommission'], 150.0);
      expect(map['openDebtsCount'], 5);
      expect(map['paidDebtsCount'], 12);
      expect(map['totalOpenAmount'], 800.0);
      expect(map['totalPaidAmount'], 1200.0);
      expect(map['lastUpdated'], isA<Timestamp>());
      expect((map['lastUpdated'] as Timestamp).toDate(), lastUpdated);

      expect(map['totalCommissionToday'], 0.0);
      expect(map['totalTransactionsToday'], 0);
      expect(map.containsKey('totalServiceFee'), isFalse);
      expect(map['totalServiceFeeToday'], 0.0);
    });

    test('copyWith should correctly clone and modify selected fields', () {
      final stats = StatsSummaryModel.empty();
      final updated = stats.copyWith(
        totalWallets: 5,
        totalBalance: 1000.0,
      );

      expect(updated.totalWallets, 5);
      expect(updated.totalBalance, 1000.0);
      expect(updated.activeWallets, 0); // Unchanged
    });

    test('equality and hashCode should include all kept fields', () {
      final lastUpdated = DateTime(2026, 6, 12);
      final stats1 = StatsSummaryModel(
        totalWallets: 10,
        activeWallets: 8,
        totalBalance: 5000.0,
        totalTransactions: 100,
        totalSentAmount: 3000.0,
        totalReceivedAmount: 2000.0,
        sendCount: 60,
        receiveCount: 40,
        totalCommission: 150.0,
        openDebtsCount: 5,
        paidDebtsCount: 12,
        totalOpenAmount: 800.0,
        totalPaidAmount: 1200.0,
        lastUpdated: lastUpdated,
      );

      final stats2 = StatsSummaryModel(
        totalWallets: 10,
        activeWallets: 8,
        totalBalance: 5000.0,
        totalTransactions: 100,
        totalSentAmount: 3000.0,
        totalReceivedAmount: 2000.0,
        sendCount: 60,
        receiveCount: 40,
        totalCommission: 150.0,
        openDebtsCount: 5,
        paidDebtsCount: 12,
        totalOpenAmount: 800.0,
        totalPaidAmount: 1200.0,
        lastUpdated: lastUpdated,
      );

      expect(stats1, equals(stats2));
      expect(stats1.hashCode, equals(stats2.hashCode));
    });
  });
}
