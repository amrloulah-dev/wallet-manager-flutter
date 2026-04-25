import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/widgets/wallet/wallet_limit_bar.dart';
import 'package:walletmanager/presentation/widgets/common/animated_hover_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/wallet_model.dart';
import '../../utils/wallet_extensions.dart';
import '../../../providers/wallet_provider.dart';
import '../../../l10n/arb/app_localizations.dart';

class WalletCard extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WalletCard({
    super.key,
    required this.wallet,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<WalletProvider, ({WalletModel wallet, bool isFrozen})>(
      selector: (_, provider) => (
        wallet: provider.wallets.firstWhere(
            (w) => w.walletId == wallet.walletId,
            orElse: () => wallet),
        isFrozen: provider.isWalletFrozenSync(wallet.walletId)
      ),
      builder: (context, data, child) {
        final reactiveWallet = data.wallet;
        final isFrozen = data.isFrozen;

        return AnimatedHoverCard(
          onTap: isFrozen
              ? () => Navigator.pushNamed(context, RouteConstants.upgradeScreen)
              : onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: isFrozen ? 0.5 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, reactiveWallet, isFrozen),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildLimits(context, reactiveWallet),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildStats(context, reactiveWallet),
                      if (onEdit != null || onDelete != null) ...[
                        const SizedBox(height: 12),
                        _buildActions(context, isFrozen),
                      ]
                    ],
                  ),
                ),
              ),
              if (isFrozen)
                const Positioned(
                  child: Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WalletModel wallet, bool isFrozen) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Icon(wallet.walletTypeIcon,
            size: 32, color: isFrozen ? Colors.grey : AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                NumberFormatter.formatPhoneNumber(wallet.phoneNumber),
                style: AppTextStyles.h3.copyWith(
                  color: isFrozen ? Colors.grey : null,
                  decoration: isFrozen ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                wallet.walletTypeDisplayName,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isFrozen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  l10n.frozen,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (wallet.walletStatus == 'new'
                      ? AppColors.warning
                      : AppColors.success)
                  .withAlpha((0.15 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              wallet.walletStatusDisplayName,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: wallet.walletStatus == 'new'
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLimits(BuildContext context, WalletModel wallet) {
    final l10n = AppLocalizations.of(context)!;
    final sendLimits = wallet.getLimits();
    final receiveLimits = wallet.getReceiveLimits();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WalletLimitBar(
          label: l10n.sendDaily,
          used: sendLimits.dailyUsed,
          limit: sendLimits.dailyLimit,
          percentage: sendLimits.dailyPercentage,
          warningLevel: wallet.sendDailyWarningLevel,
        ),
        const SizedBox(height: 8),
        WalletLimitBar(
          label: l10n.receiveDaily,
          used: receiveLimits.dailyUsed,
          limit: receiveLimits.dailyLimit,
          percentage: receiveLimits.dailyPercentage,
          warningLevel:
              'green', // This should be calculated in the model ideally
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context, WalletModel wallet) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(l10n.currentBalance, style: AppTextStyles.bodySmall),
              ],
            ),
            Text(
              NumberFormatter.formatAmount(wallet.balance),
              style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz,
                    size: 16, color: AppColors.textSecondary(context)),
                const SizedBox(width: 4),
                Text(
                  '${l10n.transactions}: ${NumberFormatter.formatNumber(wallet.stats.totalTransactions)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.attach_money,
                    size: 16, color: AppColors.textSecondary(context)),
                const SizedBox(width: 4),
                Text(
                  '${l10n.commission}: ${NumberFormatter.formatAmount(wallet.stats.totalCommission)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.success),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, bool isFrozen) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (onEdit != null)
          ElevatedButton.icon(
            onPressed: isFrozen ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
            label: Text(
              l10n.edit,
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFrozen ? Colors.grey : AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        const SizedBox(
          width: 15,
        ),
        if (onDelete != null)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isFrozen ? Colors.grey : AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: isFrozen ? null : onDelete,
            icon:
                const Icon(Icons.delete_outline, size: 18, color: Colors.white),
            label: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
