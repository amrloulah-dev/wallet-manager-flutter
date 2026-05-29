import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../l10n/arb/app_localizations.dart';
import '../../../../providers/auth_provider.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout, color: Colors.white),
        label: Text(AppLocalizations.of(context)!.logout,
            style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _showLogoutDialog(context),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final currentContext = context;
    final authProvider = currentContext.read<AuthProvider>();

    DialogUtils.showConfirmDialog(
      currentContext,
      title: AppLocalizations.of(currentContext)!.logout,
      message: AppLocalizations.of(currentContext)!.logoutConfirmation,
      confirmText: AppLocalizations.of(currentContext)!.exit,
      type: DialogType.danger,
      onConfirm: () async {
        await authProvider.logout();
      },
    );
  }
}
