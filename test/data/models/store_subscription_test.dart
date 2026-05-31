import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';

void main() {
  group('StoreSubscription.daysRemainingAt', () {
    test('returns null for lifetime plan', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.lifetime,
        status: SubscriptionStatus.active,
        endDate: null,
        trialConsumed: false,
        maxWallets: 999,
        maxEmployees: 999,
        smsEnabled: true,
      );

      expect(sub.daysRemainingAt(DateTime(2026, 5, 31)), isNull);
    });

    test('returns positive days for future endDate', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime(2026, 6, 10, 15, 0),
        trialConsumed: false,
        maxWallets: 50,
        maxEmployees: 20,
        smsEnabled: true,
      );

      // Same day = 10 days remaining
      expect(sub.daysRemainingAt(DateTime(2026, 5, 31, 10, 0)), equals(10));
    });

    test('returns exactly 0 for same day expiration', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.trial,
        status: SubscriptionStatus.active,
        endDate: DateTime(2026, 5, 31, 23, 59),
        trialConsumed: false,
        maxWallets: 3,
        maxEmployees: 1,
        smsEnabled: true,
      );

      // Evaluated on the same calendar day, but before expiry
      expect(sub.daysRemainingAt(DateTime(2026, 5, 31, 10, 0)), equals(0));
    });

    test('returns negative days for past endDate', () {
      final sub = StoreSubscription(
        planId: SubscriptionPlan.trial,
        status: SubscriptionStatus.expired,
        endDate: DateTime(2026, 5, 29, 23, 59),
        trialConsumed: true,
        maxWallets: 3,
        maxEmployees: 1,
        smsEnabled: false,
      );

      // Evaluated 2 days later
      expect(sub.daysRemainingAt(DateTime(2026, 5, 31, 10, 0)), equals(-2));
    });
  });
}
