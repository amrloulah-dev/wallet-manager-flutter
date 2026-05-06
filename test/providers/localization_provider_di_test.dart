import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/providers/localization_provider.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  group('LocalizationProvider DI Tests', () {
    late MockLocalStorageService mockStorage;

    setUp(() {
      mockStorage = MockLocalStorageService();
    });

    test('should use injected LocalStorageService', () async {
      when(() => mockStorage.savedLocale).thenReturn('en');
      
      final provider = LocalizationProvider(localStorage: mockStorage);
      
      // Wait for microtask in constructor to finish
      await Future.microtask(() {});
      
      expect(provider.locale.languageCode, 'en');
    });
  });
}
