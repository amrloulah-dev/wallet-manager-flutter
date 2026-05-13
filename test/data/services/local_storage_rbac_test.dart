import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('LocalStorageService RBAC Tests', () {
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

      storage = LocalStorageService.instance;
      await storage.initialize(secureStorage: mockSecureStorage);
    });

    tearDown(() {
      LocalStorageService.reset();
    });

    test('saveSession should store role name and get userRole should return Enum', () async {
      await storage.saveSession(
        userId: 'u1',
        storeId: 's1',
        userRole: UserRole.owner,
        userName: 'Owner Name',
        storeName: 'Store Name',
      );

      expect(storage.userRole, UserRole.owner);
    });

    test('userRole should return unknown for invalid legacy strings (Lazy Migration Support)', () async {
      // Simulate legacy data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', 'admin'); // Not a valid Enum value

      expect(storage.userRole, UserRole.unknown);
    });

    test('userRole should return unknown if no role is stored', () {
      expect(storage.userRole, UserRole.unknown);
    });
  });
}
