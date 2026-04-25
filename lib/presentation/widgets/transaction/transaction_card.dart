import 'package:flutter/material.dart';
import 'package:walletmanager/presentation/widgets/common/animated_hover_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../utils/model_ui_extensions.dart';
import '../../../l10n/arb/app_localizations.dart';

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;
  final bool showWalletInfo; // Not used in this implementation as per prompt

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
    this.showWalletInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedHoverCard(
      onTap: onTap,
      initialElevation: 1.0,
      highlightedElevation: 4.0,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1️⃣ Icon Circle (send/receive indicator)
            _buildTransactionIcon(),

            const SizedBox(width: 12),

            // 2️⃣ Transaction Details
            _buildTransactionDetails(context),

            const SizedBox(width: 8),

            // 3️⃣ Amount & Commission (Right-aligned)
            _buildAmountDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: transaction.transactionTypeColor
            .withAlpha((0.1 * 255).round()),
        shape: BoxShape.circle,
      ),
      child: Icon(
        transaction.transactionTypeIcon,
        color: transaction.transactionTypeColor,
        size: 24,
      ),
    );
  }

  Widget _buildTransactionDetails(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + Time Row
          _buildTypeAndTimeRow(context),

          const SizedBox(height: 4),

          // Customer Phone
          _buildCustomerInfo(context),

          // Customer Name (if exists)
          if (transaction.customerName != null &&
              transaction.customerName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              transaction.customerName!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Payment Status Badge (if debt)
          if (transaction.isDebt) ...[
            const SizedBox(height: 4),
            _buildDebtBadge(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeAndTimeRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          transaction.getTransactionTypeDisplay(l10n),
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: transaction.transactionTypeColor,
          ),
        ),
        Text(
          ' • ',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        Text(
          transaction.formattedTime, // e.g. '10:30 AM'
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.person_outline,
            size: 14, color: AppColors.textSecondary(context)),
        const SizedBox(width: 4),
        Text(
          NumberFormatter.formatPhoneNumber(transaction.customerPhone),
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildDebtBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.debt,
        style: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.warning,
        ),
      ),
    );
  }

  Widget _buildAmountDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Amount
        Text(
          NumberFormatter.formatAmount(transaction.amount),
          style: AppTextStyles.h3.copyWith(
            color: transaction.transactionTypeColor,
          ),
        ),

        const SizedBox(height: 4),

        // Commission
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_money, size: 14, color: AppColors.success),
            Text(
              NumberFormatter.formatAmount(transaction.commission,
                  showCurrency: false),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
