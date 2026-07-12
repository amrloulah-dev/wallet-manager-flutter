import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('StoreModel Tests', () {
    late MockDocumentSnapshot mockSnapshot;

    setUp(() {
      mockSnapshot = MockDocumentSnapshot();
    });

    test('StoreModel.fromFirestore parses correct fields and omits stats', () {
      final now = Timestamp.now();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('store_123');
      when(() => mockSnapshot.data()).thenReturn({
        'storeName': 'My Store',
        'storePassword': 'hashed_password',
        'ownerId': 'owner_123',
        'ownerName': 'John Doe',
        'ownerEmail': 'john@example.com',
        'ownerPhoto': 'https://photo.url',
        'isActive': true,
        'isSuspended': false,
        'createdAt': now,
        'updatedAt': now,
        'subscription': {
          'planId': 'pro_yearly',
          'status': 'active',
          'endDate': now,
          'trialConsumed': true,
          'maxWallets': 10,
          'maxEmployees': 5,
          'smsEnabled': true,
          'pendingRequestDate': null,
        },
        'settings': {
          'currency': 'EGP',
          'timezone': 'Africa/Cairo',
        },
      });

      final model = StoreModel.fromFirestore(mockSnapshot);

      expect(model.storeId, 'store_123');
      expect(model.storeName, 'My Store');
      expect(model.ownerEmail, 'john@example.com');
      expect(model.subscription.planId, SubscriptionPlan.proYearly);
      expect(model.settings.currency, 'EGP');
      // Verify no stats field is present on StoreModel anymore
    });

    test('StoreModel.toFirestore serializes fields and omits stats', () {
      final now = DateTime.now();
      final model = StoreModel(
        storeId: 'store_123',
        storeName: 'My Store',
        storePassword: 'password',
        ownerId: 'owner_123',
        ownerName: 'John Doe',
        ownerEmail: 'john@example.com',
        isActive: true,
        isSuspended: false,
        createdAt: now,
        updatedAt: now,
        subscription: StoreSubscription(
          planId: SubscriptionPlan.proYearly,
          status: SubscriptionStatus.active,
          endDate: now,
          trialConsumed: true,
        ),
        settings: StoreSettings(
          currency: 'EGP',
          timezone: 'Africa/Cairo',
        ),
      );

      final map = model.toFirestore();

      expect(map['storeName'], 'My Store');
      expect(map['ownerEmail'], 'john@example.com');
      expect(map.containsKey('stats'), isFalse);
    });
  });
}
