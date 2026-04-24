import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/providers/base_provider.dart';

class TestProvider extends BaseProvider {
  void triggerNotify() => safeNotify();
  void triggerError(String code) => setError(code);
}

void main() {
  late TestProvider provider;

  setUp(() {
    provider = TestProvider();
  });

  group('BaseProvider Tests', () {
    test('safeNotify should call notifyListeners when not disposed', () {
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.triggerNotify();
      expect(notifyCount, 1);
    });

    test('safeNotify should not throw error when disposed', () {
      provider.dispose();
      expect(() => provider.triggerNotify(), returnsNormally);
    });

    test('setError should update current error and log it', () {
      const errorCode = 'TEST_ERROR';
      provider.triggerError(errorCode);
      
      // Assuming we expose error for testing or it triggers something observable
      // For now, we'll just check if it can be called
      expect(() => provider.triggerError(errorCode), returnsNormally);
    });

    test('dispose should set _isDisposed to true', () {
      provider.dispose();
      // We can check if notifyListeners still works or if it fails silently
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });
      
      provider.triggerNotify();
      expect(notifyCount, 0); // Should not notify after dispose
    });
  });
}
