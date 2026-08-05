import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
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

    test('missing lastMonthlyReset deserializes to lastMonthlyReset == null',
        () {
      final map = Map<String, dynamic>.from(validMap);
      // lastMonthlyReset is absent
      final model = WalletModel.fromMap(map, 'w1');
      expect(model.lastMonthlyReset, isNull);
    });
  });

  group('Legacy document deserialization', () {
    final baseLegacyMap = <String, dynamic>{
      'storeId': 's1',
      'phoneNumber': '01012345678',
      'walletType': 'vodafoneCash',
      'balance': 500.0,
      'createdBy': 'u1',
    };

    test('completely missing walletStatus defaults to WalletStatus.inactive',
        () {
      final map = Map<String, dynamic>.from(baseLegacyMap);
      map['dailyLimit'] = 50000.0;
      map['monthlyLimit'] = 150000.0;
      final model = WalletModel.fromMap(map, 'w1');
      expect(model.walletStatus, equals(WalletStatus.inactive));
    });

    test('missing sendLimits map reconstructs from legacy root-level fields',
        () {
      final map = Map<String, dynamic>.from(baseLegacyMap);
      map['dailyLimit'] = 50000.0;
      map['monthlyLimit'] = 150000.0;
      map['receiveLimits'] = {
        'dailyLimit': 1000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 5000.0,
        'monthlyUsed': 0.0,
      };

      final model = WalletModel.fromMap(map, 'w1');
      expect(model.sendLimits.dailyLimit, equals(50000.0));
      expect(model.sendLimits.dailyUsed, equals(0.0));
      expect(model.sendLimits.monthlyLimit, equals(150000.0));
      expect(model.sendLimits.monthlyUsed, equals(0.0));
    });

    test(
        'missing sendLimits AND missing root fields falls back to networkOldLimits',
        () {
      final map = Map<String, dynamic>.from(baseLegacyMap);
      map['receiveLimits'] = {
        'dailyLimit': 1000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 5000.0,
        'monthlyUsed': 0.0,
      };

      final model = WalletModel.fromMap(map, 'w1');
      const defaults = PlatformSettingsModel.defaults();
      expect(model.sendLimits.dailyLimit,
          equals(defaults.networkOldLimits.dailySend));
      expect(model.sendLimits.dailyUsed, equals(0.0));
      expect(model.sendLimits.monthlyLimit,
          equals(defaults.networkOldLimits.monthlySend));
      expect(model.sendLimits.monthlyUsed, equals(0.0));
    });

    test(
        'missing receiveLimits map reconstructs from legacy root fields or networkOldLimits',
        () {
      final map = Map<String, dynamic>.from(baseLegacyMap);
      map['sendLimits'] = {
        'dailyLimit': 1000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 5000.0,
        'monthlyUsed': 0.0,
      };

      final model = WalletModel.fromMap(map, 'w1');
      const defaults = PlatformSettingsModel.defaults();
      expect(model.receiveLimits.dailyLimit,
          equals(defaults.networkOldLimits.dailyReceive));
      expect(model.receiveLimits.dailyUsed, equals(0.0));
      expect(model.receiveLimits.monthlyLimit,
          equals(defaults.networkOldLimits.monthlyReceive));
      expect(model.receiveLimits.monthlyUsed, equals(0.0));
    });

    test(
        'missing lastDailyReset and lastMonthlyReset remain null (auto-heal trigger)',
        () {
      final map = Map<String, dynamic>.from(baseLegacyMap);
      map['dailyLimit'] = 50000.0;
      map['monthlyLimit'] = 150000.0;

      final model = WalletModel.fromMap(map, 'w1');
      expect(model.lastDailyReset, isNull);
      expect(model.lastMonthlyReset, isNull);
    });

    test('complete new-format document deserializes with zero regressions', () {
      final newFormatMap = <String, dynamic>{
        'storeId': 's1',
        'phoneNumber': '01012345678',
        'walletType': 'vodafoneCash',
        'walletStatus': 'active',
        'balance': 1000.0,
        'createdBy': 'u1',
        'sendLimits': {
          'dailyLimit': 10000.0,
          'dailyUsed': 500.0,
          'monthlyLimit': 600000.0,
          'monthlyUsed': 2000.0,
        },
        'receiveLimits': {
          'dailyLimit': 10000.0,
          'dailyUsed': 100.0,
          'monthlyLimit': 600000.0,
          'monthlyUsed': 300.0,
        },
      };

      final model = WalletModel.fromMap(newFormatMap, 'w1');
      expect(model.walletStatus, equals(WalletStatus.active));
      expect(model.sendLimits.dailyLimit, equals(10000.0));
      expect(model.sendLimits.dailyUsed, equals(500.0));
      expect(model.receiveLimits.dailyLimit, equals(10000.0));
      expect(model.receiveLimits.dailyUsed, equals(100.0));
    });
  });
}
