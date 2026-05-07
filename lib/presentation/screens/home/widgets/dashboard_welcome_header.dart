import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/auth_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class DashboardWelcomeHeader extends StatelessWidget {
  const DashboardWelcomeHeader({super.key});

  String _getGreetingMessage(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return AppLocalizations.of(context)!.goodMorning;
    }
    if (hour < 17) {
      return AppLocalizations.of(context)!.goodAfternoon;
    }
    return AppLocalizations.of(context)!.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AuthProvider, String?>(
      selector: (context, provider) => provider.currentUser?.fullName,
      builder: (context, fullName, child) {
        final avatarLetter =
            fullName?.isNotEmpty == true ? fullName![0].toUpperCase() : 'U';
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border(
                bottom: BorderSide(color: AppColors.border(context), width: 1)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              child: Text(
                avatarLetter,
                style: AppTextStyles.h3.copyWith(color: Colors.white),
              ),
            ),
            title: Text(
              _getGreetingMessage(context),
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary(context)),
            ),
            subtitle: Text(
              fullName ?? AppLocalizations.of(context)!.user,
              style: AppTextStyles.h3
                  .copyWith(color: AppColors.textPrimary(context)),
            ),
          ),
        );
      },
    );
  }
}
