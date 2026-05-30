import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('LocalStorageService Security Tests', () {
    late LocalStorageService storage;
    late MockFlutterSecureStorage mockSecureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockSecureStorage = MockFlutterSecureStorage();

      // Default mock behaviors
      when(() => mockSecureStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async => {});
      when(() => mockSecureStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async => {});

      storage = LocalStorageService.instance;
      await storage.initialize(secureStorage: mockSecureStorage);
    });

    tearDown(() {
      LocalStorageService.reset();
    });

    test('saveSession should use Secure Storage for sensitive data', () async {
      await storage.saveSession(
        userId: 'secure_user_123',
        storeId: 'secure_store_456',
        userRole: UserRole.owner,
        userName: 'Test User',
        storeName: 'Test Store',
      );

      verify(() =>
              mockSecureStorage.write(key: 'userId', value: 'secure_user_123'))
          .called(1);
      verify(() => mockSecureStorage.write(
          key: 'storeId', value: 'secure_store_456')).called(1);
      verify(() => mockSecureStorage.write(
          key: 'userRole', value: UserRole.owner.name)).called(1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('userId'), isFalse);
      expect(prefs.containsKey('storeId'), isFalse);
      expect(prefs.containsKey('userRole'), isFalse);

      expect(prefs.getString('userName'), 'Test User');
      expect(storage.userId, 'secure_user_123');
    });

    test(
        'initialize should migrate legacy data from SharedPreferences to Secure Storage',
        () async {
      LocalStorageService.reset();
      SharedPreferences.setMockInitialValues({
        'userId': 'legacy_u',
        'storeId': 'legacy_s',
        'userRole': 'owner',
      });

      storage = LocalStorageService.instance;
      await storage.initialize(secureStorage: mockSecureStorage);

      verify(() => mockSecureStorage.write(key: 'userId', value: 'legacy_u'))
          .called(1);
      verify(() => mockSecureStorage.write(key: 'storeId', value: 'legacy_s'))
          .called(1);
      verify(() => mockSecureStorage.write(key: 'userRole', value: 'owner'))
          .called(1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('userId'), isFalse);
      expect(prefs.containsKey('storeId'), isFalse);
      expect(prefs.containsKey('userRole'), isFalse);
    });

    test('Vault data should be cleared after consumption (Ephemeral Pattern)',
        () async {
      final testData = {'txId': '123', 'amount': 100.0};
      await storage.saveToVault(testData);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pending_overlay_data'), isTrue);

      final readData = storage.readFromVault();
      expect(readData?['txId'], '123');

      await storage.clearVault();
      expect(prefs.containsKey('pending_overlay_data'), isFalse);
    });
  });
}
