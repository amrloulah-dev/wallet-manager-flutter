import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/state/safe_change_notifier.dart';

void main() {
  group('SafeChangeNotifier', () {
    test('safeNotify calls notifyListeners if not disposed', () async {
      final notifier = TestSafeChangeNotifier();
      bool notified = false;
      notifier.addListener(() => notified = true);

      notifier.testSafeNotify();

      // safeNotify uses Future.microtask, so we need to wait
      await Future.microtask(() {});

      expect(notified, isTrue);
    });

    test('safeNotify does not call notifyListeners if disposed', () async {
      final notifier = TestSafeChangeNotifier();
      bool notified = false;
      notifier.addListener(() => notified = true);

      notifier.dispose();
      notifier.testSafeNotify();

      await Future.microtask(() {});

      expect(notified, isFalse);
    });

    test('isDisposed is true after dispose', () {
      final notifier = TestSafeChangeNotifier();
      expect(notifier.isDisposed, isFalse);
      notifier.dispose();
      expect(notifier.isDisposed, isTrue);
    });
  });
}

class TestSafeChangeNotifier extends SafeChangeNotifier {
  void testSafeNotify() => safeNotify();
}
