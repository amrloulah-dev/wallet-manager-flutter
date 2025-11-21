import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';

class TransactionSummaryCard extends StatelessWidget {
  final int totalTransactions;
  final int sendCount;
  final int receiveCount;
  final double totalSendAmount;
  final double totalReceiveAmount;
  final double totalCommission;

  const TransactionSummaryCard({
    super.key,
    required this.totalTransactions,
    required this.sendCount,
    required this.receiveCount,
    required this.totalSendAmount,
    required this.totalReceiveAmount,
    required this.totalCommission,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1️⃣ Header
            Row(
              children: [
                const Icon(Icons.summarize, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ملخص اليوم',
                  style: AppTextStyles.h3,
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.divider(context)),

            const SizedBox(height: 12),

            // 2️⃣ Stats Grid (3 columns, wrapped)
            Wrap(
              spacing: 0,
              runSpacing: 8,
              children: [
                _SummaryItem(
                  icon: Icons.swap_horiz,
                  label: 'المعاملات',
                  value: '$totalTransactions',
                  color: AppColors.primary,
                ),
                _SummaryItem(
                  icon: Icons.arrow_upward,
                  label: 'إرسال',
                  value: '$sendCount',
                  color: AppColors.send,
                ),
                _SummaryItem(
                  icon: Icons.arrow_downward,
                  label: 'استقبال',
                  value: '$receiveCount',
                  color: AppColors.receive,
                ),
                _SummaryItem(
                  icon: Icons.arrow_upward,
                  label: 'مبلغ الإرسال',
                  value: NumberFormatter.formatAmount(totalSendAmount,
                      showCurrency: false),
                  color: AppColors.send,
                ),
                _SummaryItem(
                  icon: Icons.arrow_downward,
                  label: 'مبلغ الاستقبال',
                  value: NumberFormatter.formatAmount(totalReceiveAmount,
                      showCurrency: false),
                  color: AppColors.receive,
                ),
                _SummaryItem(
                  icon: Icons.attach_money,
                  label: 'العمولات',
                  value: NumberFormatter.formatAmount(totalCommission),
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 32 for card padding, 16 for item padding
    final itemWidth = (MediaQuery.of(context).size.width - 32 - 32) / 3;
    return Container(
      width: itemWidth,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
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
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
