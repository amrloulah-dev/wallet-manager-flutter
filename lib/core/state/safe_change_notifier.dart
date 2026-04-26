import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that provides safe notification and disposal lifecycle management.
///
/// It prevents "use after disposal" errors by tracking the disposal state
/// and wrapping [notifyListeners] in a safety guard.
abstract class SafeChangeNotifier extends ChangeNotifier {
  bool _isDisposed = false;

  /// Whether this notifier has been disposed.
  bool get isDisposed => _isDisposed;

  @override
  @mustCallSuper
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Notifies listeners safely, ensuring the notifier is not disposed
  /// and has active listeners. Notifications are scheduled in a microtask
  /// to avoid "rebuild during build" errors.
  @protected
  void safeNotify() {
    if (!_isDisposed && hasListeners) {
      Future.microtask(() {
        if (!_isDisposed && hasListeners) {
          notifyListeners();
        }
      });
    }
  }
}
