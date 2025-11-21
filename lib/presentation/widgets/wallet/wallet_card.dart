import 'package:flutter/material.dart';
import 'package:walletmanager/presentation/widgets/wallet/wallet_limit_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/wallet_model.dart';

class WalletCard extends StatefulWidget {
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
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  bool _isHighlighted = false;

  @override
  Widget build(BuildContext context) {
    final elevation = _isHighlighted ? 8.0 : 2.0;
    final scale = _isHighlighted ? 0.98 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..scale(scale, scale),
      child: Card(
        elevation: elevation,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (isHighlighted) {
            setState(() {
              _isHighlighted = isHighlighted;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _buildLimits(),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _buildStats(context),
                if (widget.onEdit != null || widget.onDelete != null) ...[
                  const SizedBox(height: 12),
                  _buildActions(),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(widget.wallet.walletTypeIcon, size: 32, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                NumberFormatter.formatPhoneNumber(widget.wallet.phoneNumber),
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 4),
              Text(
                widget.wallet.walletTypeDisplayName,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (widget.wallet.walletStatus == 'new'
                    ? AppColors.warning
                    : AppColors.success)
                .withAlpha((0.15 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.wallet.walletStatusDisplayName,
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.wallet.walletStatus == 'new'
                  ? AppColors.warning
                  : AppColors.success,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLimits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WalletLimitBar(
          label: 'إرسال يومي',
          used: widget.wallet.sendLimits.dailyUsed,
          limit: widget.wallet.sendLimits.dailyLimit,
          percentage: widget.wallet.sendLimits.dailyPercentage,
          warningLevel: widget.wallet.sendDailyWarningLevel,
        ),
        const SizedBox(height: 8),
        WalletLimitBar(
          label: 'استقبال يومي',
          used: widget.wallet.receiveLimits.dailyUsed,
          limit: widget.wallet.receiveLimits.dailyLimit,
          percentage: widget.wallet.receiveLimits.dailyPercentage,
          warningLevel:
              'green', // This should be calculated in the model ideally
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('الرصيد الحالي', style: AppTextStyles.bodySmall),
              ],
            ),
            Text(
              NumberFormatter.formatAmount(widget.wallet.balance),
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                  'معاملات: ${NumberFormatter.formatNumber(widget.wallet.stats.totalTransactions)}',
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
                  'عمولة: ${NumberFormatter.formatAmount(widget.wallet.stats.totalCommission)}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (widget.onEdit != null)
          ElevatedButton.icon(
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: Colors.white),
            label: const Text(
              'تعديل',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          SizedBox(width: 15,),
        if (widget.onDelete != null)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Colors.white),
            label: const Text(
              'حذف',
              style: TextStyle(color: Colors.white),
            ),
            ),
      ],
    );
  }
}