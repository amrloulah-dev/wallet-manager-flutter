import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/dialog_utils.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/store_model.dart';
import '../../../l10n/arb/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import 'package:walletmanager/providers/localization_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _buildAccountInfoSection(context),
          const Divider(height: 32, indent: 16, endIndent: 16),
          _buildAppSettingsSection(context),
          const Divider(height: 32, indent: 16, endIndent: 16),
          _buildAppInfoSection(context),
          const Divider(height: 32, indent: 16, endIndent: 16),
          _buildLogoutSection(context),
        ],
      ),
    );
  }

  // ===========================
  // Sections
  // ===========================

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: AppTextStyles.h3.copyWith(color: AppColors.primary),
      ),
    );
  }

  Widget _buildAccountInfoSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        final store = authProvider.currentStore;
        final avatarLetter = user?.fullName.isNotEmpty == true
            ? user!.fullName[0].toUpperCase()
            : 'U';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
                context, AppLocalizations.of(context)!.accountInfo),
            // User Card
            Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          AppColors.primary.withAlpha((0.1 * 255).round()),
                      child: Text(avatarLetter,
                          style: AppTextStyles.h2
                              .copyWith(color: AppColors.primary)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              user?.fullName ??
                                  AppLocalizations.of(context)!.user,
                              style: AppTextStyles.h3),
                          const SizedBox(height: 4),
                          Text(
                              user?.email ??
                                  user?.phone ??
                                  AppLocalizations.of(context)!.noEmail,
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user?.isOwner ?? false
                            ? AppLocalizations.of(context)!.owner
                            : AppLocalizations.of(context)!.employee,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Store Card
            if (store != null)
              Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoRow(
                          context: context,
                          label: AppLocalizations.of(context)!.storeName,
                          value: store.storeName),
                      const Divider(height: 24),
                      _buildInfoRow(
                          context: context,
                          label: AppLocalizations.of(context)!.creationDate,
                          value: DateHelper.formatTimestamp(store.createdAt)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // License Card (Owner only)
            if (user?.isOwner == true && store != null)
              _buildLicenseCard(context, store.license),
          ],
        );
      },
    );
  }

  Widget _buildLicenseCard(BuildContext context, StoreLicense license) {
    return Consumer<AuthProvider>(builder: (context, authProvider, _) {
      final isTrial = authProvider.isTrial;
      final isExpired = license.isExpired;
      final daysRemaining =
          isTrial ? authProvider.trialDaysRemaining : license.daysRemaining;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final cardColor = AppColors.licenseCardBg(context,
          isTrial: isTrial, isExpired: isExpired);
      final borderColor = AppColors.licenseCardBorder(context,
          isTrial: isTrial, isExpired: isExpired);

      Color statusColor;
      String statusText;

      if (isTrial) {
        statusColor = isDark ? Colors.amber.shade200 : Colors.amber.shade800;
        statusText = 'فترة تجريبية';
      } else if (isExpired) {
        statusColor = AppColors.error;
        statusText = AppLocalizations.of(context)!.expired;
      } else {
        statusColor = AppColors.success;
        statusText = AppLocalizations.of(context)!.active;
      }

      return Card(
        elevation: 1,
        color: cardColor,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.licenseInfo,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary(context),
                      )),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusText,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isTrial && !isDark
                              ? Colors.white
                              : (isDark ? Colors.black87 : Colors.white),
                        )),
                  ),
                ],
              ),
              Divider(height: 24, color: isDark ? Colors.white12 : null),
              _buildInfoRow(
                  context: context,
                  label: AppLocalizations.of(context)!.licenseKey,
                  value: isTrial ? 'TRIAL' : license.licenseKey),
              const SizedBox(height: 12),
              _buildInfoRow(
                  context: context,
                  label: AppLocalizations.of(context)!.expiryDate,
                  value: DateHelper.formatTimestamp(license.expiryDate)),
              if (!isExpired) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        isTrial
                            ? 'الأيام المتبقية'
                            : AppLocalizations.of(context)!.daysRemaining,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary(context),
                        )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (daysRemaining ?? 0) <= 7
                            ? AppColors.warning
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$daysRemaining ${AppLocalizations.of(context)!.day}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
              if (isExpired || (daysRemaining ?? 0) <= 7 || isTrial) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.new_releases_outlined),
                    label: Text(isTrial
                        ? 'ترقية النسخة الكاملة'
                        : AppLocalizations.of(context)!.contactToRenew),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        RouteConstants.upgradeScreen,
                        arguments: isTrial,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.amber.shade200 : AppColors.primary,
                      backgroundColor:
                          (isDark ? Colors.amber.shade900 : AppColors.primary)
                              .withAlpha((0.1 * 255).round()),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAppSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, AppLocalizations.of(context)!.appSettings),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(_getThemeIcon(themeProvider.themeMode),
                    color: AppColors.primary),
                title: Text(AppLocalizations.of(context)!.theme,
                    style: AppTextStyles.bodyLarge),
                subtitle: Text(
                    getThemeModeName(context, themeProvider.themeMode),
                    style: AppTextStyles.bodyMedium),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showThemeDialog(context),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Consumer<LocalizationProvider>(
          builder: (context, localizationProvider, child) {
            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.language, color: AppColors.primary),
                title: Text(AppLocalizations.of(context)!.language,
                    style: AppTextStyles.bodyLarge),
                subtitle: Text(
                    localizationProvider.isArabic
                        ? AppLocalizations.of(context)!.arabic
                        : AppLocalizations.of(context)!.english,
                    style: AppTextStyles.bodyMedium),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showLanguageDialog(context),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, AppLocalizations.of(context)!.license),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.vpn_key_outlined,
                    color: AppColors.textSecondary(context)),
                title: Text(
                    context.read<AuthProvider>().isTrial
                        ? 'ترقية'
                        : 'عرض الترخيص', // "Upgrade" or "View License"
                    style: AppTextStyles.bodyLarge),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  final isTrial = context.read<AuthProvider>().isTrial;
                  Navigator.pushNamed(
                    context,
                    RouteConstants.upgradeScreen,
                    arguments: isTrial,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutSection(BuildContext context) {
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

  // ===========================
  // Helper Methods
  // ===========================

  Widget _buildInfoRow({
    required BuildContext context,
    required String label,
    required String value,
    TextStyle? style,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary(context),
            )),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: style ??
                AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  IconData _getThemeIcon(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  Future<void> _showThemeDialog(BuildContext context) {
    return DialogUtils.showOptionsDialog(
      context,
      title: AppLocalizations.of(context)!.chooseTheme,
      options: ThemeMode.values.map((mode) {
        return RadioListTile<ThemeMode>(
          title: Text(getThemeModeName(context, mode),
              style: AppTextStyles.bodyLarge.copyWith(color: Colors.black)),
          value: mode,
          groupValue: context.read<ThemeProvider>().themeMode,
          activeColor: AppColors.primary,
          onChanged: (ThemeMode? value) {
            if (value != null) {
              context.read<ThemeProvider>().setThemeMode(value);
            }
            Navigator.of(context).pop();
          },
        );
      }).toList(),
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) {
    return DialogUtils.showOptionsDialog(
      context,
      title: AppLocalizations.of(context)!.chooseLanguage,
      options: [
        RadioListTile<String>(
          title: Text(AppLocalizations.of(context)!.arabic,
              style: AppTextStyles.bodyLarge.copyWith(color: Colors.black)),
          value: 'ar',
          groupValue: context.read<LocalizationProvider>().locale.languageCode,
          activeColor: AppColors.primary,
          onChanged: (String? value) {
            if (value != null) {
              context.read<LocalizationProvider>().setLocale(Locale(value));
            }
            Navigator.of(context).pop();
          },
        ),
        RadioListTile<String>(
          title: Text(AppLocalizations.of(context)!.english,
              style: AppTextStyles.bodyLarge.copyWith(color: Colors.black)),
          value: 'en',
          groupValue: context.read<LocalizationProvider>().locale.languageCode,
          activeColor: AppColors.primary,
          onChanged: (String? value) {
            if (value != null) {
              context.read<LocalizationProvider>().setLocale(Locale(value));
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  String getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppLocalizations.of(context)!.light;
      case ThemeMode.dark:
        return AppLocalizations.of(context)!.dark;
      case ThemeMode.system:
        return AppLocalizations.of(context)!.system;
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon:
          const Icon(Icons.wallet, size: 48, color: AppColors.primary),
      children: [
        Text(AppLocalizations.of(context)!.appDescription),
      ],
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
        try {
          await authProvider.logout();
          if (!currentContext.mounted) return;
          Navigator.of(currentContext).pushNamedAndRemoveUntil(
            RouteConstants.loginLanding,
            (route) => false,
          );
        } catch (e) {
          if (currentContext.mounted) {
            ToastUtils.showError(
                '${AppLocalizations.of(currentContext)!.logoutFailed}: $e');
          }
        }
      },
    );
  }
}
