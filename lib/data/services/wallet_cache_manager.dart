import '../../core/errors/app_error_handler.dart';
import '../../core/errors/error_severity.dart';
import '../models/wallet_model.dart';
import 'local_storage_service.dart';

/// A dedicated manager for handling wallet-related caching logic.
class WalletCacheManager {
  final LocalStorageService _storage;

  WalletCacheManager({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService.instance;

  /// Caches the given list of wallets for offline use (e.g., SMS Automation).
  Future<void> cacheWallets(List<WalletModel> wallets) async {
    try {
      await _storage.cacheWalletLiteList(wallets);
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        severity: ErrorSeverity.low,
        operation: 'wallet_cache_write',
        stackTrace: stack,
      );
    }
  }

  /// Retrieves the cached lite wallet list.
  List<Map<String, dynamic>> getCachedWallets() {
    return _storage.getCachedWalletLiteList();
  }
}
