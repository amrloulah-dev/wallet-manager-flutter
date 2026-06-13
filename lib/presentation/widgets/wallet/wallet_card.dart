import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/wallet_model.dart';
import '../../utils/wallet_extensions.dart';
import '../../../l10n/arb/app_localizations.dart';
import '../../../core/enums/wallet_enums.dart';

class WalletCard extends StatelessWidget {
  final WalletModel wallet;
  final bool isFrozen;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WalletCard({
    super.key,
    required this.wallet,
    required this.isFrozen,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final providerColor =
        isFrozen ? Colors.grey : _getProviderColor(wallet.walletType);

    return Transform.scale(
      scale: 0.90,
      child: InkWell(
        onTap: isFrozen
            ? () => Navigator.pushNamed(context, RouteConstants.upgradeScreen)
            : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: wallet.walletStatus == WalletStatus.suspended
                              ? Colors.red.shade900.withOpacity(0.3)
                              : Colors.green.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: wallet.walletStatus == WalletStatus.suspended
                                ? Colors.red.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          l10n.getWalletStatusName(wallet.walletStatus),
                          style: TextStyle(
                            color: wallet.walletStatus == WalletStatus.suspended
                                ? Colors.red.shade400
                                : Colors.green.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Phone Number (enforced LTR format directionally)
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          NumberFormatter.formatPhoneNumber(wallet.phoneNumber),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Provider Type
                      Text(
                        l10n.getWalletTypeName(wallet.walletType),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Provider Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: providerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: providerColor.withOpacity(0.1)),
                  ),
                  child: Icon(
                    wallet.walletTypeIcon,
                    color: providerColor,
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            const SizedBox(height: 20),

            // Limits Section
            _buildLimitBar(
              context: context,
              label: l10n.sendDaily,
              used: wallet.getLimits().dailyUsed,
              limit: wallet.getLimits().dailyLimit,
              percentage: wallet.getLimits().dailyPercentage,
              warningLevel: isFrozen ? 'grey' : wallet.sendDailyWarningLevel,
            ),
            const SizedBox(height: 16),
            _buildLimitBar(
              context: context,
              label: l10n.receiveDaily,
              used: wallet.getReceiveLimits().dailyUsed,
              limit: wallet.getReceiveLimits().dailyLimit,
              percentage: wallet.getReceiveLimits().dailyPercentage,
              warningLevel: isFrozen ? 'grey' : 'green',
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            const SizedBox(height: 20),

            // Balance Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.credit_card,
                          color: Colors.blue.shade400,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.currentBalance,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    NumberFormatter.formatAmount(wallet.balance,
                        showCurrency: true),
                    style: TextStyle(
                      color: isFrozen ? Colors.grey : Colors.blue.shade400,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  if (onDelete != null)
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: isFrozen ? null : onDelete,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                l10n.delete,
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (onDelete != null && onEdit != null)
                    const SizedBox(width: 16),
                  if (onEdit != null)
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: isFrozen ? null : onEdit,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isFrozen
                                ? Colors.grey.withOpacity(0.2)
                                : Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isFrozen
                                ? null
                                : [
                                    BoxShadow(
                                      color:
                                          Colors.blue.shade600.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.edit_outlined,
                                  size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                l10n.edit,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLimitBar({
    required BuildContext context,
    required String label,
    required double used,
    required double limit,
    required double percentage,
    required String warningLevel,
  }) {
    final int displayPercentage = percentage.clamp(0.0, 100.0).toInt();
    final double progressValue = (percentage / 100).clamp(0.0, 1.0);
    final Color barColor = _getColorForWarningLevel(warningLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$displayPercentage%',
              style: TextStyle(
                color: barColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${NumberFormatter.formatAmount(used, showCurrency: false)} / ${NumberFormatter.formatAmount(limit)} EGP',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getColorForWarningLevel(String level) {
    switch (level) {
      case 'grey':
        return Colors.grey;
      case 'green':
        return AppColors.success;
      case 'yellow':
        return AppColors.warning;
      case 'red':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  Color _getProviderColor(WalletType type) {
    switch (type) {
      case WalletType.vodafoneCash:
        return Colors.red;
      case WalletType.instaPay:
        return Colors.blue;
      case WalletType.orangeCash:
        return Colors.orange;
      case WalletType.etisalatCash:
        return Colors.green;
      case WalletType.wePay:
        return Colors.purple;
      case WalletType.other:
        return AppColors.primary;
    }
  }
}
