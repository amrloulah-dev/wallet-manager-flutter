import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';

class DebtSummaryCard extends StatelessWidget {
  const DebtSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DebtProvider>(
      builder: (context, provider, child) {
        final summary = provider.summary;
        final openDebtsCount = summary['openDebtsCount'] ?? 0;
        final paidDebtsCount = summary['paidDebtsCount'] ?? 0;
        final totalOpenAmount = summary['totalOpenAmount'] ?? 0.0;
        final totalPaidAmount = summary['totalPaidAmount'] ?? 0.0;

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1️⃣ Header
                Row(
                  children: [
                    const Icon(Icons.credit_card,
                        color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text('ملخص الديون', style: AppTextStyles.h3),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),

                // 2️⃣ Stats Row
                Row(
                  children: [
                    // 🔹 Open Debts
                    _buildSummaryBox(
                      context: context,
                      title: 'ديون مفتوحة',
                      count: openDebtsCount,
                      amount: totalOpenAmount,
                      color: AppColors.error,
                      icon: Icons.circle,
                    ),

                    const SizedBox(width: 12),

                    // 🔸 Paid Debts
                    _buildSummaryBox(
                      context: context,
                      title: 'ديون مسددة',
                      count: paidDebtsCount,
                      amount: totalPaidAmount,
                      color: AppColors.success,
                      icon: Icons.check_circle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryBox({
    required BuildContext context,
    required String title,
    required int count,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha((0.05 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withAlpha((0.2 * 255).round()),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: AppTextStyles.h2.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              NumberFormatter.formatAmount(amount),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
