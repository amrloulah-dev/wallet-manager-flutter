import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';

class WalletLimitBar extends StatelessWidget {
  final String label;          // e.g. 'إرسال يومي'
  final double used;           // current used amount
  final double limit;          // maximum limit
  final double percentage;     // 0-100
  final String warningLevel;   // 'green' | 'yellow' | 'red'

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
              NumberFormatter.formatPercentage(percentage / 100),
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: _getColorForWarningLevel(warningLevel),
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
              value: percentage / 100,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                _getColorForWarningLevel(warningLevel),
              ),
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
