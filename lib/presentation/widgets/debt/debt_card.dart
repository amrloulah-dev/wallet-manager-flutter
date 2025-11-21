import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/debt_model.dart';

class DebtCard extends StatefulWidget {
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
  State<DebtCard> createState() => _DebtCardState();
}

class _DebtCardState extends State<DebtCard> {
  bool _isHighlighted = false;

  @override
  Widget build(BuildContext context) {
    final elevation = _isHighlighted ? 8.0 : 2.0;
    final scale = _isHighlighted ? 0.98 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..scale(scale, scale),
      child: Card(
        elevation: elevation,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (isHighlighted) {
            setState(() {
              _isHighlighted = isHighlighted;
            });
          },
          borderRadius: BorderRadius.circular(12),
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
                if (widget.debt.debtTypeDisplay.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDebtType(context),
                ],

                // 5️⃣ Notes (if exists)
                if (widget.debt.notes != null && widget.debt.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildNotesSection(context),
                ],

                // 6️⃣ Mark as Paid Button
                if (widget.onMarkPaid != null && widget.debt.isOpen) ...[
                  const SizedBox(height: 16),
                  _buildMarkAsPaidButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.debt.statusColor.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.debt.isOpen ? Icons.circle : Icons.check_circle,
                size: 14,
                color: widget.debt.statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                widget.debt.debtStatusDisplay,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.debt.statusColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          widget.debt.relativeDebtDate, // Example: "منذ 3 أيام"
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
        Icon(Icons.person, size: 20, color: AppColors.textSecondary(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.debt.customerName,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 2),
              Text(
                NumberFormatter.formatPhoneNumber(widget.debt.customerPhone),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.debt.isOpen
            ? AppColors.error.withAlpha((0.05 * 255).round())
            : AppColors.success.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'المبلغ المستحق:',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          Text(
            NumberFormatter.formatAmount(widget.debt.amountDue),
            style: AppTextStyles.h2.copyWith(color: widget.debt.statusColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtType(BuildContext context) {
    return Row(
      children: [
        Icon(
          widget.debt.debtTypeIcon,
          size: 16,
          color: AppColors.textSecondary(context),
        ),
        const SizedBox(width: 6),
        Text(
          widget.debt.debtTypeDisplay,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
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
              widget.debt.notes!,
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

  Widget _buildMarkAsPaidButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.onMarkPaid,
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('تسديد الدين'),
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
