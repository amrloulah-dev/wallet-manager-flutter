import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';

class WalletLimitBar extends StatelessWidget {
  final String label; // e.g. 'إرسال يومي'
  final double used; // current used amount
  final double limit; // maximum limit
  final double percentage; // 0-100
  final String warningLevel; // 'green' | 'yellow' | 'red'

  const WalletLimitBar({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    required this.percentage,
    required this.warningLevel,
  });

  @override
  Widget build(BuildContext context) {
    // Cap visual percentage at 100%
    final int displayPercentage = percentage.clamp(0.0, 100.0).toInt();
    // Cap progress bar value at 1.0 (full)
    final double progressValue = (percentage / 100).clamp(0.0, 1.0);
    final Color barColor = _getColorForWarningLevel(warningLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
            Text(
              '$displayPercentage%',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Progress Bar
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.divider(context),
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

        const SizedBox(height: 4),

        // Amount Text
        Text(
          '${NumberFormatter.formatAmount(used, showCurrency: false)} / ${NumberFormatter.formatAmount(limit)}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary(context),
          ),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }

  Color _getColorForWarningLevel(String level) {
    switch (level) {
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
}
