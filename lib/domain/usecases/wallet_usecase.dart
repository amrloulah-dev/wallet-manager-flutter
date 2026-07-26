import '../../data/models/user_model.dart';
import '../../data/models/user_permissions.dart';
import '../../data/models/wallet_model.dart';
import '../../core/errors/app_exceptions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';

/// UseCase for wallet-related business logic.
class WalletUseCase {
  final AuthProvider _authProvider;

  WalletUseCase({
    required AuthProvider authProvider,
  }) : _authProvider = authProvider;

  /// Validates user permissions before performing an action.
  Future<UserModel> validatePermission(
      bool Function(UserPermissions) selector) async {
    UserModel? user;
    try {
      user = await _authProvider.ensureUserLoaded();
    } on PermissionDeniedException {
      throw PermissionException();
    }
    if (user == null) {
      throw AuthException('auth_error_session_expired');
    }
    if (user.isOwner) return user;
    if (!user.hasPermission(selector)) {
      throw PermissionException();
    }
    return user;
  }

  /// Calculates which wallets should be frozen based on subscription limits.
  Set<String> calculateFrozenWallets({
    required List<WalletModel> wallets,
    required SubscriptionProvider? subscriptionProvider,
    required String? storeId,
  }) {
    final frozenIds = <String>{};
    if (subscriptionProvider == null || storeId == null) return frozenIds;

    final maxWallets = subscriptionProvider.maxWallets;
    if (wallets.length <= maxWallets) return frozenIds;

    final sortedWallets = List<WalletModel>.from(wallets);
    // Use epoch as sentinel for wallets with null createdAt to ensure stable sort
    sortedWallets.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return aDate.compareTo(bDate);
    });

    for (int i = maxWallets; i < sortedWallets.length; i++) {
      frozenIds.add(sortedWallets[i].walletId);
    }
    return frozenIds;
  }
}
