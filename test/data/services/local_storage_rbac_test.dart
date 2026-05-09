import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

void main() {
  group('LocalStorageService RBAC Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService.instance;
      await storage.initialize();
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
