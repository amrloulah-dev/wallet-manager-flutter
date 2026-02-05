import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/routes/navigation_service.dart';

class ToastUtils {
  static void showSuccess(String message) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;
    BotToast.showCustomText(
      toastBuilder: (cancelFunc) => _buildToast(
        context: context,
        message: message,
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
      align: Alignment.bottomCenter,
      duration: const Duration(seconds: 3),
    );
  }

  static void showError(String message) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;
    BotToast.showCustomText(
      toastBuilder: (cancelFunc) => _buildToast(
        context: context,
        message: message,
        icon: Icons.error_outline,
        color: AppColors.error,
      ),
      align: Alignment.bottomCenter,
      duration: const Duration(seconds: 4),
    );
  }

  static void showInfo(String message) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;
    BotToast.showCustomText(
      toastBuilder: (cancelFunc) => _buildToast(
        context: context,
        message: message,
        icon: Icons.info_outline,
        color: AppColors.info,
      ),
      align: Alignment.bottomCenter,
      duration: const Duration(seconds: 3),
    );
  }

  static void showWarning(String message) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;
    BotToast.showCustomText(
      toastBuilder: (cancelFunc) => _buildToast(
        context: context,
        message: message,
        icon: Icons.warning_amber_outlined,
        color: AppColors.warning,
      ),
      align: Alignment.bottomCenter,
      duration: const Duration(seconds: 3),
    );
  }

  static Widget _buildToast({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isDarkMode) {
      return _buildDarkToast(context, message, icon, color);
    } else {
      return _buildLightToast(context, message, icon, color);
    }
  }

  static Widget _buildLightToast(
      BuildContext context, String message, IconData icon, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDarkToast(
      BuildContext context, String message, IconData icon, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.dark.surface, // Use dark surface color
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.dark.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
