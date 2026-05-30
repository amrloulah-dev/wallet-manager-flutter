import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_utils.dart';
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

  void _showLogoutDialog(BuildContext context) {
    final currentContext = context;

    DialogUtils.showConfirmDialog(
      currentContext,
      title: AppLocalizations.of(currentContext)!.logout,
      message: AppLocalizations.of(currentContext)!.logoutConfirmation,
      confirmText: AppLocalizations.of(currentContext)!.exit,
      type: DialogType.danger,
      onConfirm: () async {
        // 1. Capture the provider before any state changes
        final auth = currentContext.read<AuthProvider>();

        // 2. Navigate immediately — unmounts the Dashboard and all its consumers
        Navigator.of(currentContext).pushNamedAndRemoveUntil(
          RouteConstants.loginLanding,
          (route) => false,
        );

        // 3. Clear auth state AFTER the route animation starts.
        // The 300ms delay ensures the widget tree has fully transitioned
        // before Provider notifies listeners, preventing Provider panics
        // and unauthenticated Firestore fetches on mounted widgets.
        Future.delayed(const Duration(milliseconds: 300), () {
          auth.logout(currentContext);
        });
      },
    );
  }
}
