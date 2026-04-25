import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class AdminBlockScreen extends StatelessWidget {
  const AdminBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.block,
                  size: 100,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 32),
                Text(
                  loc.accountSuspended,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  loc.accountSuspendedMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () {
                    // Could launch whatsapp or call
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.contactingSupportTeam)),
                    );
                  },
                  icon: const Icon(Icons.support_agent),
                  label: Text(loc.contactSupport),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    context.read<AuthProvider>().logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(loc.logoutButton),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
