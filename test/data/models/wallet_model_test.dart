import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';

void main() {
  group('WalletModel (Phase 3)', () {
    final wallet1 = WalletModel(
      walletId: 'w1',
      storeId: 's1',
      phoneNumber: '012',
      walletType: WalletType.vodafoneCash,
      walletStatus: WalletStatus.active,
      balance: 100.0,
      isActive: true,
      createdBy: 'u1',
      sendLimits: WalletLimits(
          dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
      receiveLimits: WalletLimits(
          dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
      stats: WalletStats(
          totalTransactions: 0,
          totalCommission: 0,
          totalSentAmount: 0,
          totalReceivedAmount: 0),
    );

    test('equality should consider all relevant fields (including limits)', () {
      final wallet2 = wallet1.copyWith(
        sendLimits: wallet1.sendLimits.copyWith(dailyUsed: 10.0),
      );

      // Should fail currently because == only checks walletId, balance, and isActive
      expect(wallet1 == wallet2, isFalse);
    });

    test('hashCode should change when limits change', () {
      final wallet2 = wallet1.copyWith(
        sendLimits: wallet1.sendLimits.copyWith(dailyUsed: 10.0),
      );

      expect(wallet1.hashCode == wallet2.hashCode, isFalse);
    });
  });

  group('WalletModel.fromMap Nullable Timestamps (Phase 3)', () {
    final validMap = {
      'storeId': 's1',
      'phoneNumber': '01012345678',
      'walletType': 'vodafoneCash',
      'walletStatus': 'active',
      'balance': 100.0,
      'createdBy': 'u1',
      'sendLimits': {
        'dailyLimit': 1000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 5000.0,
        'monthlyUsed': 0.0,
      },
      'receiveLimits': {
        'dailyLimit': 1000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 5000.0,
        'monthlyUsed': 0.0,
      },
    };

    test('missing createdAt deserializes to createdAt == null', () {
      final map = Map<String, dynamic>.from(validMap);
      // createdAt is absent
      final model = WalletModel.fromMap(map, 'w1');
      expect(model.createdAt, isNull);
    });

    test('missing lastDailyReset deserializes to lastDailyReset == null', () {
      final map = Map<String, dynamic>.from(validMap);
      // lastDailyReset is absent
      final model = WalletModel.fromMap(map, 'w1');
      expect(model.lastDailyReset, isNull);
    });

    test('missing lastMonthlyReset deserializes to lastMonthlyReset == null', () {
      final map = Map<String, dynamic>.from(validMap);
      // lastMonthlyReset is absent
      final model = WalletModel.fromMap(map, 'w1');
      expect(model.lastMonthlyReset, isNull);
    });
  });
}
