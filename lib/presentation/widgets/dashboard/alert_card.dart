import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum AlertType {
  info,
  warning,
  error,
  success,
}

class AlertCard extends StatelessWidget {
  final String message;
  final AlertType type;
  final String? actionText;
  final VoidCallback? onActionTap;
  final VoidCallback? onDismiss;

  const AlertCard({
    super.key,
    required this.message,
    required this.type,
    this.actionText,
    this.onActionTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12), // Spacing between alerts
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getBorderColor(type),
          width: 1,
        ),
      ),
      color: _getBackgroundColor(type),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading Icon
            Icon(
              _getIcon(type),
              color: _getIconColor(type),
              size: 24,
            ),

            const SizedBox(width: 12),

            // Message and optional action
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary(context),
                      height: 1.4, // Improve line spacing
                    ),
                  ),
                  if (actionText != null && onActionTap != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onActionTap,
                      child: Text(
                        actionText!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: _getIconColor(type),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Optional dismiss button
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textSecondary(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(AlertType type) {
    switch (type) {
      case AlertType.info:
        return AppColors.info.withAlpha((0.1 * 255).round());
      case AlertType.warning:
        return AppColors.warning.withAlpha((0.1 * 255).round());
      case AlertType.error:
        return AppColors.error.withAlpha((0.1 * 255).round());
      case AlertType.success:
        return AppColors.success.withAlpha((0.1 * 255).round());
    }
  }

  Color _getBorderColor(AlertType type) {
    switch (type) {
      case AlertType.info:
        return AppColors.info.withAlpha((0.3 * 255).round());
      case AlertType.warning:
        return AppColors.warning.withAlpha((0.3 * 255).round());
      case AlertType.error:
        return AppColors.error.withAlpha((0.3 * 255).round());
      case AlertType.success:
        return AppColors.success.withAlpha((0.3 * 255).round());
    }
  }

  Color _getIconColor(AlertType type) {
    switch (type) {
      case AlertType.info:
        return AppColors.info;
      case AlertType.warning:
        return AppColors.warning;
      case AlertType.error:
        return AppColors.error;
      case AlertType.success:
        return AppColors.success;
    }
  }

  IconData _getIcon(AlertType type) {
    switch (type) {
      case AlertType.info:
        return Icons.info_outline;
      case AlertType.warning:
        return Icons.warning_amber;
      case AlertType.error:
        return Icons.error_outline;
      case AlertType.success:
        return Icons.check_circle_outline;
    }
  }
}
