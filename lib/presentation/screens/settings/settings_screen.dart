import 'package:flutter/material.dart';
import '../../../l10n/arb/app_localizations.dart';
import 'widgets/account_info_section.dart';
import 'widgets/app_settings_section.dart';
import 'widgets/sms_automation_section.dart';
import 'widgets/app_info_section.dart';
import 'widgets/logout_button.dart';

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
        children: const [
          AccountInfoSection(),
          Divider(height: 32, indent: 16, endIndent: 16),
          AppSettingsSection(),
          Divider(height: 32, indent: 16, endIndent: 16),
          SmsAutomationSection(),
          Divider(height: 32, indent: 16, endIndent: 16),
          AppInfoSection(),
          Divider(height: 32, indent: 16, endIndent: 16),
          LogoutButton(),
        ],
      ),
    );
  }
}
