import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/widgets/common/animated_hover_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/debt_model.dart';
import '../../utils/model_ui_extensions.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/statistics_provider.dart';
import '../../../l10n/arb/app_localizations.dart';

class DebtCard extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback? onTap;
  final VoidCallback? onMarkPaid;

  const DebtCard({
    super.key,
    required this.debt,
    this.onTap,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedHoverCard(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1️⃣ Header Row (Status + Date)
            _buildHeader(context),

            const SizedBox(height: 12),
            const Divider(),

            // 2️⃣ Customer Info
            _buildCustomerInfo(context),

            const SizedBox(height: 12),
            const Divider(),

            // 3️⃣ Amount Row
            _buildAmountSection(context),

            // 4️⃣ Debt Type (if applicable)
            _buildDebtType(context),

            // 5️⃣ Notes (if exists)
            if (debt.notes != null && debt.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildNotesSection(context),
            ],

            // 6️⃣ Mark as Paid Button
            if (onMarkPaid != null && debt.isOpen) ...[
              const SizedBox(height: 16),
              _buildMarkAsPaidButton(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayStatus = debt.getDebtStatusDisplay(l10n);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: debt.statusColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                debt.isOpen ? Icons.circle : Icons.check_circle,
                size: 14,
                color: debt.statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                displayStatus,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: debt.statusColor,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Text(
              debt.getRelativeDebtDate(l10n),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                final confirm = await DialogUtils.showConfirmDialog(
                  context,
                  title: l10n.deleteDebt,
                  message: l10n.deleteDebtConfirmation,
                  confirmText: l10n.delete,
                  type: DialogType.danger,
                );

                if (confirm == true) {
                  if (context.mounted) {
                    final success = await context
                        .read<DebtProvider>()
                        .deleteDebt(debt.debtId);

                    if (success && context.mounted) {
                      context
                          .read<StatisticsProvider>()
                          .refreshDashboardStats();
                    }
                  }
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerInfo(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.person, size: 20, color: AppColors.textSecondary(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                debt.customerName,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 2),
              Text(
                NumberFormatter.formatPhoneNumber(debt.customerPhone),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: debt.isOpen
            ? AppColors.error.withAlpha(13)
            : AppColors.success.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.amountDue,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          Text(
            NumberFormatter.formatAmount(debt.amountDue),
            style: AppTextStyles.h2.copyWith(color: debt.statusColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtType(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayType =
        debt.isTransactionDebt ? l10n.walletTransaction : l10n.storeSale;

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        children: [
          Icon(
            debt.debtTypeIcon,
            size: 16,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(width: 6),
          Text(
            displayType,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note, size: 16, color: AppColors.textSecondary(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              debt.notes!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkAsPaidButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onMarkPaid,
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: Text(l10n.payDebt),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
