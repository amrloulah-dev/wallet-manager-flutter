import 'dart:async';

/// A simple event bus for broadcasting data change events across the app.
class AppEvents {
  final _walletsChangedController = StreamController<void>.broadcast();
  final _transactionsChangedController = StreamController<void>.broadcast();
  final _debtsChangedController = StreamController<void>.broadcast();
  final _statsRefreshController = StreamController<void>.broadcast();

  Stream<void> get onWalletsChanged => _walletsChangedController.stream;
  Stream<void> get onTransactionsChanged =>
      _transactionsChangedController.stream;
  Stream<void> get onDebtsChanged => _debtsChangedController.stream;
  Stream<void> get onStatsRefresh => _statsRefreshController.stream;

  void fireWalletsChanged() => _walletsChangedController.add(null);
  void fireTransactionsChanged() => _transactionsChangedController.add(null);
  void fireDebtsChanged() => _debtsChangedController.add(null);
  void fireStatsRefresh() => _statsRefreshController.add(null);

  void dispose() {
    _walletsChangedController.close();
    _transactionsChangedController.close();
    _debtsChangedController.close();
    _statsRefreshController.close();
  }
}

/// Global instance of the AppEvents bus.
final appEvents = AppEvents();
