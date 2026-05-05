import 'package:walletmanager/data/services/local_storage_service.dart';

/// Thin adapter that routes overlay persistence through the unified vault.
///
/// All overlay data is stored under the single `pending_overlay_data` key
/// managed by [LocalStorageService.saveToVault], eliminating the orphan
/// `pending_overlay_tx` key that previously caused data fragmentation.
class OverlayRepository {
  final LocalStorageService _storage;

  OverlayRepository({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService.instance;

  Future<void> savePendingTransaction(Map<String, dynamic> txData) async {
    await _storage.saveToVault(txData);
  }
}
