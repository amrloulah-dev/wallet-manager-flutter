import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/subscription_provider.dart';
import '../../../../l10n/arb/app_localizations.dart';

class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final subscription = context.select<AuthProvider, dynamic>(
      (p) => p.currentStore?.subscription,
    );
    final isTrial = context.select<AuthProvider, bool>((p) => p.isTrial);
    final trialDaysRemaining = context.select<AuthProvider, int?>(
      (p) => p.trialDaysRemaining,
    );
    final latestRequest = context.select<SubscriptionProvider, dynamic>(
      (p) => p.latestRequest,
    );
    final isExpired = context.select<SubscriptionProvider, bool>(
      (p) => p.isExpired,
    );
    final hasDismissedRejection = context.select<SubscriptionProvider, bool>(
      (p) => p.hasDismissedRejection,
    );
    final l10n = AppLocalizations.of(context)!;

    if (subscription == null) return const SizedBox.shrink();

    // Prioritize showing latest request statuses first
    if (latestRequest != null) {
      if (latestRequest.status == 'pending') {
        return _buildBanner(
          context,
          icon: Icons.access_time_filled,
          color: Colors.orange,
          message: l10n.pendingSubscriptionReview,
        );
      } else if (latestRequest.status == 'approved' && !isExpired) {
        // Technically if it's approved, the cloud function updates the subscription.
        // But if we want to show a short banner, we can just optionally show it.
        // It mostly matters for rejection.
      } else if (latestRequest.status == 'rejected') {
        // H009: Dismissible rejection banner
        if (hasDismissedRejection) {
          // User dismissed this rejection banner — don't show it
        } else {
          return _buildBanner(
            context,
            icon: Icons.error,
            color: Colors.red,
            message: l10n.rejectedSubscriptionRequest,
            onDismiss: () =>
                context.read<SubscriptionProvider>().dismissRejectionBanner(),
          );
        }
      }
    } else if (subscription.pendingRequestDate != null) {
      // Fallback if latestRequest isn't available yet or something
      return _buildBanner(
        context,
        icon: Icons.access_time_filled,
        color: Colors.orange,
        message: l10n.pendingSubscriptionReview,
      );
    }

    // Check if expired
    if (isExpired) {
      return _buildBanner(
        context,
        icon: Icons.warning_rounded,
        color: Colors.redAccent,
        message: l10n.subscriptionExpiredRenew,
      );
    }

    // Check if trial with <= 3 days left
    if (isTrial) {
      final daysLeft = trialDaysRemaining ?? 0;
      if (daysLeft <= 3 && daysLeft > 0) {
        return _buildBanner(
          context,
          icon: Icons.info_outline,
          color: Colors.blueAccent,
          message: l10n.trialEndingSoon(daysLeft),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner(BuildContext context,
      {required IconData icon,
      required Color color,
      required String message,
      VoidCallback? onDismiss}) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          // H009: Dismiss button for rejection banner
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, color: color, size: 20),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: l10n.hide,
            ),
        ],
      ),
    );
  }
}
