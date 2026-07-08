import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';

void main() {
  group('StoreSubscription Tests', () {
    test('daysRemainingAt returns null for lifetime plan', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.lifetime,
        status: SubscriptionStatus.active,
        endDate: null,
        trialConsumed: false,
      );

      expect(sub.daysRemainingAt(DateTime(2026, 5, 31)), isNull);
    });

    test('daysRemainingAt returns positive days for future endDate', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime(2026, 6, 10, 15, 0),
        trialConsumed: false,
      );

      // Same day = 10 days remaining
      expect(sub.daysRemainingAt(DateTime(2026, 5, 31, 10, 0)), equals(10));
    });

    test('daysRemainingAt returns exactly 0 for same day expiration', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.trial,
        status: SubscriptionStatus.active,
        endDate: DateTime(2026, 5, 31, 23, 59),
        trialConsumed: false,
      );

      // Evaluated on the same calendar day, but before expiry
      expect(sub.daysRemainingAt(DateTime(2026, 5, 31, 10, 0)), equals(0));
    });

    test('daysRemainingAt returns negative days for past endDate', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.trial,
        status: SubscriptionStatus.expired,
        endDate: DateTime(2026, 5, 29, 23, 59),
        trialConsumed: true,
      );

      // Evaluated 2 days later
      expect(sub.daysRemainingAt(DateTime(2026, 5, 31, 10, 0)), equals(-2));
    });

    test('fromMap and toMap serialize state fields and omit limit fields', () {
      final now = Timestamp.now();
      final map = {
        'planId': 'pro_yearly',
        'status': 'active',
        'endDate': now,
        'trialConsumed': true,
        'pendingRequestDate': now,
        // limit fields that should be ignored
        'maxWallets': 100,
        'maxEmployees': 50,
        'smsEnabled': true,
      };

      final sub = StoreSubscription.fromMap(map);

      expect(sub.planId, SubscriptionPlan.proYearly);
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.trialConsumed, isTrue);
      expect(sub.endDate, now.toDate());
      expect(sub.pendingRequestDate, now.toDate());

      final serialized = sub.toMap();
      expect(serialized['planId'], 'proYearly');
      expect(serialized['status'], 'active');
      expect(serialized['trialConsumed'], isTrue);
      expect(serialized.containsKey('maxWallets'), isFalse);
      expect(serialized.containsKey('maxEmployees'), isFalse);
      expect(serialized.containsKey('smsEnabled'), isFalse);
    });

    test('migratedLifetime factory provides correct defaults and no limit fields', () {
      final sub = StoreSubscription.migratedLifetime();
      expect(sub.planId, SubscriptionPlan.lifetime);
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.endDate, isNull);
      expect(sub.trialConsumed, isTrue);
    });
  });
}
