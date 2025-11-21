import 'package:flutter/material.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/data/models/user_model.dart';

class EmployeeCard extends StatelessWidget {
  final UserModel employee;
  final VoidCallback? onDelete;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = employee.isActive;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isActive ? 2 : 0,
      color: isActive ? AppColors.surface(context) : AppColors.surface(context).withAlpha((0.5 * 255).round()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.transparent : AppColors.divider(context),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: (isActive ? AppColors.primary : Colors.grey).withAlpha((0.1 * 255).round()),
              child: Text(
                employee.fullName.isNotEmpty ? employee.fullName[0].toUpperCase() : 'E',
                style: AppTextStyles.h3.copyWith(color: isActive ? AppColors.primary : Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.fullName,
                    style: AppTextStyles.labelLarge.copyWith(
                      decoration: isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.phone ?? employee.email ?? 'No contact info',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary(context),
                      decoration: isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
                tooltip: 'Deactivate Employee',
              ),
          ],
        ),
      ),
    );
  }
}
