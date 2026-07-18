import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';

void main() {
  group('WalletModel Receive Getters', () {
    WalletModel createWallet({
      required WalletType walletType,
      required double balance,
      required double dailyLimit,
      required double dailyUsed,
      required double monthlyLimit,
      required double monthlyUsed,
    }) {
      return WalletModel(
        walletId: 'test_wallet',
        storeId: 'test_store',
        phoneNumber: '01234567890',
        walletType: walletType,
        walletStatus: WalletStatus.active,
        balance: balance,
        createdBy: 'test_user',
        sendLimits: WalletLimits(
          dailyLimit: 1000,
          dailyUsed: 0,
          monthlyLimit: 5000,
          monthlyUsed: 0,
        ),
        receiveLimits: WalletLimits(
          dailyLimit: dailyLimit,
          dailyUsed: dailyUsed,
          monthlyLimit: monthlyLimit,
          monthlyUsed: monthlyUsed,
        ),
        stats: WalletStats(
          totalTransactions: 0,
          totalCommission: 0,
          totalSentAmount: 0,
          totalReceivedAmount: 0,
        ),
      );
    }

    group('isInstaPay', () {
      test('returns true for WalletType.instaPay', () {
        final wallet = createWallet(
          walletType: WalletType.instaPay,
          balance: 0,
          dailyLimit: 1000,
          dailyUsed: 0,
          monthlyLimit: 5000,
          monthlyUsed: 0,
        );
        expect(wallet.isInstaPay, isTrue);
      });

      test('returns false for non-instaPay wallets', () {
        final wallet = createWallet(
          walletType: WalletType.vodafoneCash,
          balance: 0,
          dailyLimit: 1000,
          dailyUsed: 0,
          monthlyLimit: 5000,
          monthlyUsed: 0,
        );
        expect(wallet.isInstaPay, isFalse);
      });
    });

    group('availableToReceiveDaily', () {
      test('returns dailyRemaining for telecom wallet', () {
        final wallet = createWallet(
          walletType: WalletType.vodafoneCash,
          balance: 100.0,
          dailyLimit: 1000.0,
          dailyUsed: 300.0,
          monthlyLimit: 5000.0,
          monthlyUsed: 300.0,
        );
        // dailyLimit - dailyUsed = 700.0
        expect(wallet.availableToReceiveDaily, 700.0);
      });

      test('returns dailyRemaining for InstaPay wallet', () {
        final wallet = createWallet(
          walletType: WalletType.instaPay,
          balance: 100.0,
          dailyLimit: 1000.0,
          dailyUsed: 400.0,
          monthlyLimit: 5000.0,
          monthlyUsed: 400.0,
        );
        // dailyLimit - dailyUsed = 600.0
        expect(wallet.availableToReceiveDaily, 600.0);
      });
    });

    group('availableToReceiveMonthly', () {
      test(
          'for telecom wallets, returns min(monthlyRemaining, monthlyLimit - balance)',
          () {
        // Here monthlyLimit = 5000.0, monthlyUsed = 1000.0 -> monthlyRemaining = 4000.0
        // balance is 2000.0 -> monthlyLimit - balance = 3000.0
        // min(4000.0, 3000.0) is 3000.0 (constrained by balance)
        final wallet = createWallet(
          walletType: WalletType.vodafoneCash,
          balance: 2000.0,
          dailyLimit: 1000.0,
          dailyUsed: 0,
          monthlyLimit: 5000.0,
          monthlyUsed: 1000.0,
        );
        expect(wallet.availableToReceiveMonthly, 3000.0);
      });

      test(
          'for telecom wallets, returns monthlyRemaining if flow limit is lower than capacity',
          () {
        // monthlyLimit = 5000.0, monthlyUsed = 4500.0 -> monthlyRemaining = 500.0
        // balance is 1000.0 -> monthlyLimit - balance = 4000.0
        // min(500.0, 4000.0) is 500.0 (constrained by flow remaining)
        final wallet = createWallet(
          walletType: WalletType.vodafoneCash,
          balance: 1000.0,
          dailyLimit: 1000.0,
          dailyUsed: 0,
          monthlyLimit: 5000.0,
          monthlyUsed: 4500.0,
        );
        expect(wallet.availableToReceiveMonthly, 500.0);
      });

      test(
          'for InstaPay wallets, returns monthlyRemaining without balance capacity constraint',
          () {
        // monthlyLimit = 5000.0, monthlyUsed = 1000.0 -> monthlyRemaining = 4000.0
        // balance is 2000.0
        // Since InstaPay is not constraint by balance capacity, it returns monthlyRemaining = 4000.0
        final wallet = createWallet(
          walletType: WalletType.instaPay,
          balance: 2000.0,
          dailyLimit: 1000.0,
          dailyUsed: 0,
          monthlyLimit: 5000.0,
          monthlyUsed: 1000.0,
        );
        expect(wallet.availableToReceiveMonthly, 4000.0);
      });
    });
  });
}
