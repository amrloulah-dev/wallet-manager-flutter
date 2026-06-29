import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../l10n/arb/app_localizations.dart';
import '../../../../providers/localization_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/platform_settings_provider.dart';
import 'section_title.dart';

class AppSettingsSection extends StatefulWidget {
  const AppSettingsSection({super.key});

  @override
  State<AppSettingsSection> createState() => _AppSettingsSectionState();
}

class _AppSettingsSectionState extends State<AppSettingsSection> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: localizations.appSettings),
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
                title: Text(localizations.theme,
                    style: AppTextStyles.bodyLarge),
                subtitle: Text(
                    _getThemeModeName(context, themeProvider.themeMode),
                    style: AppTextStyles.bodyMedium),
                trailing: Icon(
                    IconData(Icons.arrow_forward_ios.codePoint,
                        fontFamily: Icons.arrow_forward_ios.fontFamily,
                        matchTextDirection: true),
                    size: 16),
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
                title: Text(localizations.language,
                    style: AppTextStyles.bodyLarge),
                subtitle: Text(
                    localizationProvider.isArabic
                        ? localizations.arabic
                        : localizations.english,
                    style: AppTextStyles.bodyMedium),
                trailing: Icon(
                    IconData(Icons.arrow_forward_ios.codePoint,
                        fontFamily: Icons.arrow_forward_ios.fontFamily,
                        matchTextDirection: true),
                    size: 16),
                onTap: () => _showLanguageDialog(context),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: _isRefreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, color: AppColors.primary),
            title: Text(localizations.refreshPlatformSettings,
                style: AppTextStyles.bodyLarge),
            trailing: Icon(
                IconData(Icons.arrow_forward_ios.codePoint,
                    fontFamily: Icons.arrow_forward_ios.fontFamily,
                    matchTextDirection: true),
                size: 16),
            onTap: _isRefreshing
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() {
                      _isRefreshing = true;
                    });
                    try {
                      await context.read<PlatformSettingsProvider>().forceRefresh();
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(localizations.platformSettingsRefreshed),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(localizations.platformSettingsRefreshFailed),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isRefreshing = false;
                        });
                      }
                    }
                  },
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

  String _getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppLocalizations.of(context)!.light;
      case ThemeMode.dark:
        return AppLocalizations.of(context)!.dark;
      case ThemeMode.system:
        return AppLocalizations.of(context)!.system;
    }
  }

  Future<void> _showThemeDialog(BuildContext context) {
    return DialogUtils.showOptionsDialog(
      context,
      title: AppLocalizations.of(context)!.chooseTheme,
      options: ThemeMode.values.map((mode) {
        return RadioListTile<ThemeMode>(
          title: Text(_getThemeModeName(context, mode),
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
}
