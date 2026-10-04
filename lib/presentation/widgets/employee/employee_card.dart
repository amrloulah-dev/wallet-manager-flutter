import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class EmployeeCard extends StatelessWidget {
  final UserModel employee;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = employee.isActive;
    final l10n = AppLocalizations.of(context)!;

    return Selector<EmployeeProvider, bool>(
      selector: (_, provider) => provider.isEmployeeFrozen(employee),
      builder: (context, isFrozen, child) {
        final double alphaScale = isFrozen ? 0.5 : 1.0;

        Widget cardContent = Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.surface(context)
                : AppColors.surface(context)
                    .withAlpha((128 * alphaScale).round()),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withAlpha((26 * alphaScale).round()),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha((13 * alphaScale).round()),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isFrozen
                  ? () =>
                      Navigator.pushNamed(context, RouteConstants.upgradeScreen)
                  : onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Leading: Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary
                          .withAlpha((26 * alphaScale).round()),
                      child: Text(
                        employee.fullName.isNotEmpty
                            ? employee.fullName[0].toUpperCase()
                            : 'E',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.primary
                              .withAlpha((255 * alphaScale).round()),
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Center: Employee Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.fullName,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color
                                  ?.withAlpha((255 * alphaScale).round()),
                              decoration:
                                  isActive ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            employee.phone ??
                                employee.email ??
                                l10n.notAvailable,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary(context)
                                  .withAlpha((255 * alphaScale).round()),
                              decoration:
                                  isActive ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge for Frozen state
                    if (isFrozen)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock,
                                  size: 12, color: Colors.red),
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
                        ),
                      ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: AppColors.error
                                .withAlpha((255 * alphaScale).round()),
                            size: 20),
                        onPressed: onDelete,
                        tooltip: l10n.deactivate,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: AppColors.primary
                            .withAlpha((128 * alphaScale).round()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            cardContent,
            if (isFrozen)
              const PositionedDirectional(
                top: 0,
                bottom: 0,
                start: 0,
                end: 0,
                child: Center(
                  child: Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                ),
              ),
          ],
        );
      },
    );
  }
}
