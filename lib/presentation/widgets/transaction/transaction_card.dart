import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/transaction_model.dart';

class TransactionCard extends StatefulWidget {
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
  State<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<TransactionCard> {
  bool _isHighlighted = false;

  @override
  Widget build(BuildContext context) {
    final elevation = _isHighlighted ? 4.0 : 1.0;
    final scale = _isHighlighted ? 0.98 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..scale(scale, scale),
      child: Card(
        elevation: elevation,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (isHighlighted) {
            setState(() {
              _isHighlighted = isHighlighted;
            });
          },
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
        ),
      ),
    );
  }

  Widget _buildTransactionIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: widget.transaction.transactionTypeColor
            .withAlpha((0.1 * 255).round()),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.transaction.transactionTypeIcon,
        color: widget.transaction.transactionTypeColor,
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
          if (widget.transaction.customerName != null &&
              widget.transaction.customerName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              widget.transaction.customerName!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Payment Status Badge (if debt)
          if (widget.transaction.isDebt) ...[
            const SizedBox(height: 4),
            _buildDebtBadge(),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeAndTimeRow(BuildContext context) {
    return Row(
      children: [
        Text(
          widget.transaction.transactionTypeDisplay,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: widget.transaction.transactionTypeColor,
          ),
        ),
        Text(
          ' • ',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        Text(
          widget.transaction.formattedTime, // e.g. '10:30 AM'
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
          NumberFormatter.formatPhoneNumber(widget.transaction.customerPhone),
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildDebtBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'دين',
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
          NumberFormatter.formatAmount(widget.transaction.amount),
          style: AppTextStyles.h3.copyWith(
            color: widget.transaction.transactionTypeColor,
          ),
        ),

        const SizedBox(height: 4),

        // Commission
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_money, size: 14, color: AppColors.success),
            Text(
              NumberFormatter.formatAmount(widget.transaction.commission,
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
