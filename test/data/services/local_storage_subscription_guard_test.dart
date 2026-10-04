import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockSecureStorage = MockFlutterSecureStorage();
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => {});

    LocalStorageService.reset();
    storage = LocalStorageService();
    await storage.initialize(secureStorage: mockSecureStorage);
  });

  group('M-4: LocalStorageService Subscription & SMS Eligibility Guards', () {
    test('isSubscriptionActive returns false if suspended', () async {
      await storage.saveSubscriptionLimits(
        endDateMs: DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        isLifetime: false,
        smsEnabled: true,
        isSuspended: true,
      );

      expect(storage.isSubscriptionActive, isFalse);
      expect(storage.isSmsEligible, isFalse);
    });

    test('isSubscriptionActive returns false if smsEnabled is false in subscription plan', () async {
      await storage.saveSubscriptionLimits(
        endDateMs: DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        isLifetime: false,
        smsEnabled: false,
        isSuspended: false,
      );

      expect(storage.isSubscriptionActive, isFalse);
      expect(storage.isSmsEligible, isFalse);
    });

    test('isSubscriptionActive returns false if subscription is expired', () async {
      await storage.saveSubscriptionLimits(
        endDateMs: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        isLifetime: false,
        smsEnabled: true,
        isSuspended: false,
      );

      expect(storage.isSubscriptionActive, isFalse);
      expect(storage.isSmsEligible, isFalse);
    });

    test('isSubscriptionActive returns true for lifetime subscription', () async {
      await storage.saveSubscriptionLimits(
        endDateMs: null,
        isLifetime: true,
        smsEnabled: true,
        isSuspended: false,
      );

      expect(storage.isSubscriptionActive, isTrue);

      // isSmsEligible requires both subscription active AND isSmsAutomationEnabled == true
      await storage.setSmsAutomationEnabled(false);
      expect(storage.isSmsEligible, isFalse);

      await storage.setSmsAutomationEnabled(true);
      expect(storage.isSmsEligible, isTrue);
    });

    test('isSubscriptionActive returns true for active non-expired subscription', () async {
      await storage.saveSubscriptionLimits(
        endDateMs: DateTime.now().add(const Duration(days: 15)).millisecondsSinceEpoch,
        isLifetime: false,
        smsEnabled: true,
        isSuspended: false,
      );

      expect(storage.isSubscriptionActive, isTrue);

      await storage.setSmsAutomationEnabled(true);
      expect(storage.isSmsEligible, isTrue);
    });
  });
}
