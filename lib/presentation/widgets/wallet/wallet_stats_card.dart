import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/wallet_model.dart';

class WalletStatsCard extends StatelessWidget {
  final WalletStats stats;

  const WalletStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bar_chart, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('الإحصائيات', style: AppTextStyles.h3),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Stats Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatItem(
                  icon: Icons.swap_horiz,
                  label: 'إجمالي المعاملات',
                  value: '${stats.totalTransactions}',
                  color: AppColors.primary,
                ),
                _StatItem(
                  icon: Icons.account_balance_wallet,
                  label: 'إجمالي المبلغ',
                  value: NumberFormatter.formatAmount(stats.totalAmount),
                  color: AppColors.primary,
                ),
                _StatItem(
                  icon: Icons.arrow_upward,
                  label: 'مبلغ الإرسال',
                  value: NumberFormatter.formatAmount(stats.totalSentAmount),
                  color: AppColors.send,
                ),
                _StatItem(
                  icon: Icons.arrow_downward,
                  label: 'مبلغ الاستقبال',
                  value:
                      NumberFormatter.formatAmount(stats.totalReceivedAmount),
                  color: AppColors.receive,
                ),
                _StatItem(
                  icon: Icons.attach_money,
                  label: 'إجمالي العمولة',
                  value: NumberFormatter.formatAmount(stats.totalCommission),
                  color: AppColors.success,
                ),
                if (stats.lastTransactionDate != null)
                  _StatItem(
                    icon: Icons.access_time,
                    label: 'آخر معاملة',
                    value: DateHelper.getRelativeTime(
                      stats.lastTransactionDate!.toDate(),
                    ),
                    color: AppColors.textSecondary(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Adjust width to account for padding and spacing in the Wrap
    final itemWidth = (screenWidth - (16 * 2) - 8) / 2.1;

    return Container(
      width: itemWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.scaffoldBg(context), // Use a slightly off-white color
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection:
                label == 'آخر معاملة' ? TextDirection.rtl : TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
