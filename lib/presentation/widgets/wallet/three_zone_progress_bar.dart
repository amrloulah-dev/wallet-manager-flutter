import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class ThreeZoneProgressBar extends StatelessWidget {
  final String label;
  final double monthlyLimit;
  final double monthlyUsed;
  final double maxAvailable;
  final double enteredAmount;
  final bool isThreeZone;

  const ThreeZoneProgressBar({
    super.key,
    required this.label,
    required this.monthlyLimit,
    required this.monthlyUsed,
    required this.maxAvailable,
    required this.enteredAmount,
    required this.isThreeZone,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Normalization & clamping to prevent division by zero or negative bounds
    final limit = monthlyLimit > 0 ? monthlyLimit : 1.0;
    final used = monthlyUsed.clamp(0.0, limit);
    final available = maxAvailable.clamp(0.0, limit - used);
    final blocked = (limit - used - available).clamp(0.0, limit);

    final double usedPercentage = (used / limit) * 100;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label & Overall Progress Text
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
              '${usedPercentage.toStringAsFixed(0)}%',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Progress Bar
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.divider(context).withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                
                if (!isThreeZone) {
                  // Standard 2-zone rendering
                  final wUsed = (used / limit) * totalWidth;
                  final wRemaining = totalWidth - wUsed;

                  return Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: wUsed,
                        height: 12,
                        color: AppColors.primary,
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: wRemaining,
                        height: 12,
                        color: AppColors.divider(context),
                      ),
                    ],
                  );
                }

                // 3-Zone rendering with dynamic pending chunk
                final wUsed = (used / limit) * totalWidth;
                
                // Segment Zone 2 (Available) into Pending and Remaining
                final pendingVal = enteredAmount.clamp(0.0, available);
                final remainingVal = (available - pendingVal).clamp(0.0, available);

                final wPending = (pendingVal / limit) * totalWidth;
                final wRemaining = (remainingVal / limit) * totalWidth;
                final wBlocked = (blocked / limit) * totalWidth;

                return Row(
                  children: [
                    // Zone 1: Used (Red)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: wUsed,
                      height: 12,
                      color: AppColors.error,
                    ),
                    // Zone 2a: Pending/Entered (Light Green / Success with Opacity)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: wPending,
                      height: 12,
                      color: AppColors.success.withOpacity(0.4),
                    ),
                    // Zone 2b: Remaining Available (Solid Green)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: wRemaining,
                      height: 12,
                      color: AppColors.success,
                    ),
                    // Zone 3: Blocked by Balance (Grey Hatched/Striped)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: wBlocked,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: const Alignment(0.1, 0.1),
                          colors: [
                            Colors.grey.shade400,
                            Colors.grey.shade400,
                            Colors.grey.shade300,
                            Colors.grey.shade300,
                          ],
                          stops: const [0.0, 0.5, 0.5, 1.0],
                          tileMode: TileMode.repeated,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Textual indicators legend
        if (isThreeZone)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildLegendItem(
                  context,
                  color: AppColors.error,
                  label: '${l10n.zoneUsedLabel}: ${NumberFormatter.formatAmount(used, showCurrency: false)}',
                ),
                _buildLegendItem(
                  context,
                  color: AppColors.success,
                  label: '${l10n.zoneAvailableLabel}: ${NumberFormatter.formatAmount(available, showCurrency: false)}',
                ),
                _buildLegendItem(
                  context,
                  color: Colors.grey,
                  label: '${l10n.zoneBlockedLabel}: ${NumberFormatter.formatAmount(blocked, showCurrency: false)}',
                ),
              ],
            ),
          )
        else
          Text(
            '${NumberFormatter.formatAmount(used, showCurrency: false)} / ${NumberFormatter.formatAmount(limit)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, {required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary(context),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
