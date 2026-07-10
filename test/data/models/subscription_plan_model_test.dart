import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/subscription_plan_model.dart';

void main() {
  group('SubscriptionPlanModel', () {
    test('fromMap parses valid data with int price', () {
      final map = {
        'name': 'Pro Plan',
        'description': 'A premium plan',
        'isActive': true,
        'price': 100,
        'maxWallets': 10,
        'maxEmployees': 5,
        'smsEnabled': true,
      };

      final model = SubscriptionPlanModel.fromMap(map);

      expect(model.name, equals('Pro Plan'));
      expect(model.description, equals('A premium plan'));
      expect(model.isActive, isTrue);
      expect(model.price, equals(100));
      expect(model.maxWallets, equals(10));
      expect(model.maxEmployees, equals(5));
      expect(model.smsEnabled, isTrue);
    });

    test('fromMap parses valid data with double price', () {
      final map = {
        'name': 'Premium',
        'description': 'Lifetime access',
        'isActive': true,
        'price': 2500.50,
        'maxWallets': 999,
        'maxEmployees': 999,
        'smsEnabled': true,
      };

      final model = SubscriptionPlanModel.fromMap(map);

      expect(model.price, equals(2500.50));
    });

    test('fromMap uses defaults for null/missing fields', () {
      final map = <String, dynamic>{};
      final model = SubscriptionPlanModel.fromMap(map);

      expect(model.name, equals(''));
      expect(model.description, equals(''));
      expect(model.isActive, isFalse);
      expect(model.price, equals(0.0));
      expect(model.maxWallets, equals(0));
      expect(model.maxEmployees, equals(0));
      expect(model.smsEnabled, isFalse);
    });

    test('toMap converts model back to map', () {
      final model = SubscriptionPlanModel(
        name: 'Lite Plan',
        description: 'Basic features',
        isActive: true,
        price: 49.99,
        maxWallets: 3,
        maxEmployees: 1,
        smsEnabled: false,
      );

      final map = model.toMap();

      expect(map['name'], equals('Lite Plan'));
      expect(map['description'], equals('Basic features'));
      expect(map['isActive'], isTrue);
      expect(map['price'], equals(49.99));
      expect(map['maxWallets'], equals(3));
      expect(map['maxEmployees'], equals(1));
      expect(map['smsEnabled'], isFalse);
    });

    group('fallback constructor', () {
      test('returns instance with expected defaults', () {
        const fallback = SubscriptionPlanModel.fallback();
        expect(fallback.name, equals('Free'));
        expect(fallback.price, equals(0));
        expect(fallback.maxWallets, equals(1));
        expect(fallback.maxEmployees, equals(1));
        expect(fallback.smsEnabled, isFalse);
        expect(fallback.isActive, isTrue);
      });

      test('supports value equality', () {
        const f1 = SubscriptionPlanModel.fallback();
        const f2 = SubscriptionPlanModel.fallback();
        expect(identical(f1, f2),
            isTrue); // Should be a const constructor returning the same constant instance
      });
    });
  });
}
