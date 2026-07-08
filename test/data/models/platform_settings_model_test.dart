import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/subscription_plan_model.dart';

void main() {
  group('PlatformSettingsModel', () {
    test('fromJson creates correct model with new format JSON', () {
      final json = {
        'isRegistrationOpen': true,
        'limits': {
          'instapay': {
            'dailyReceive': 100000.0,
            'dailySend': 100000.0,
            'maxPerTransaction': 50000.0,
            'monthlyReceive': 300000.0,
            'monthlySend': 300000.0,
          },
        },
        'feeLimits': {
          'networks': {
            'min': 2.0,
            'max': 20.0,
          },
          'instapay': {
            'min': 1.0,
            'max': 30.0,
          },
        },
        'serviceFees': {
          'sameNetwork': 1.5,
          'crossNetwork': 0.007,
          'instapay': 0.002,
        },
        'subscriptions': {
          'gracePeriodHours': 72,
          'trialDays': 30,
          'lifetimeCountLimit': 100,
          'plans': {
            'pro': {
              'name': 'Pro Plan',
              'description': 'Description',
              'isActive': true,
              'price': 150.0,
              'maxWallets': 10,
              'maxEmployees': 5,
              'smsEnabled': true,
            }
          }
        }
      };

      final model = PlatformSettingsModel.fromJson(json);

      expect(model.isRegistrationOpen, isTrue);
      expect(model.instapayLimits.maxPerTransaction, 50000.0);
      expect(model.minCrossNetworkFee, 2.0);
      expect(model.sameNetworkFee, 1.5);
      
      // New global subscription fields
      expect(model.gracePeriodHours, 72);
      expect(model.trialDays, 30);
      expect(model.lifetimeCountLimit, 100);
      
      // Plans map
      expect(model.plans.containsKey('pro'), isTrue);
      expect(model.plans['pro']!.name, equals('Pro Plan'));
      expect(model.plans['pro']!.price, equals(150.0));
      expect(model.plans['pro']!.maxWallets, equals(10));
    });

    test('fromJson handles old format JSON and falls back to defaults', () {
      final json = {
        'subscriptions': {
          // Old legacy fields
          'proPrice': 1200,
          'lifetimePrice': 2500,
          'lifetimeCountLimit': 50,
        }
      };

      final model = PlatformSettingsModel.fromJson(json);

      // Should default gracePeriodHours and trialDays safely
      expect(model.gracePeriodHours, equals(48));
      expect(model.trialDays, equals(14));
      expect(model.lifetimeCountLimit, equals(50));
      expect(model.plans, isEmpty);
    });

    test('defaults() constructor provides expected initial values', () {
      const model = PlatformSettingsModel.defaults();

      expect(model.isRegistrationOpen, isTrue);
      expect(model.gracePeriodHours, equals(48));
      expect(model.trialDays, equals(14));
      expect(model.lifetimeCountLimit, equals(50));
      expect(model.plans, isEmpty);
    });

    test('toJson serializes new fields correctly', () {
      final plan = SubscriptionPlanModel(
        name: 'Pro Plan',
        description: 'Description',
        isActive: true,
        price: 150.0,
        maxWallets: 10,
        maxEmployees: 5,
        smsEnabled: true,
      );

      final model = PlatformSettingsModel(
        isRegistrationOpen: true,
        instapayLimits: const NetworkLimits(dailyReceive: 120000, dailySend: 120000, maxPerTransaction: 70000, monthlyReceive: 400000, monthlySend: 400000),
        networkCommercialLimits: const NetworkLimits(dailyReceive: 200000, dailySend: 200000, maxPerTransaction: 200000, monthlyReceive: 500000, monthlySend: 500000),
        networkNewLimits: const NetworkLimits(dailyReceive: 10000, dailySend: 10000, maxPerTransaction: 30000, monthlyReceive: 600000, monthlySend: 600000),
        networkOldLimits: const NetworkLimits(dailyReceive: 60000, dailySend: 80000, maxPerTransaction: 70000, monthlyReceive: 200000, monthlySend: 200000),
        minCrossNetworkFee: 1.0,
        maxCrossNetworkFee: 15.0,
        minInstapayFee: 0.5,
        maxInstapayFee: 20.0,
        sameNetworkFee: 1.0,
        crossNetworkFeeRate: 0.005,
        instapayFeeRate: 0.001,
        lifetimeCountLimit: 50,
        gracePeriodHours: 48,
        trialDays: 14,
        plans: {'pro': plan},
      );

      final serialized = model.toJson();
      final subscriptions = serialized['subscriptions'] as Map<String, dynamic>;

      expect(subscriptions['gracePeriodHours'], equals(48));
      expect(subscriptions['trialDays'], equals(14));
      expect(subscriptions['lifetimeCountLimit'], equals(50));
      
      // Verify legacy fields proPrice and lifetimePrice are NOT present in serialized map
      expect(subscriptions.containsKey('proPrice'), isFalse);
      expect(subscriptions.containsKey('lifetimePrice'), isFalse);

      final serializedPlans = subscriptions['plans'] as Map<String, dynamic>;
      expect(serializedPlans.containsKey('pro'), isTrue);
      expect(serializedPlans['pro']['name'], equals('Pro Plan'));
    });
  });
}
