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
      sendLimits: WalletLimits(dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
      receiveLimits: WalletLimits(dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
      stats: WalletStats(totalTransactions: 0, totalCommission: 0, totalSentAmount: 0, totalReceivedAmount: 0),
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
}
