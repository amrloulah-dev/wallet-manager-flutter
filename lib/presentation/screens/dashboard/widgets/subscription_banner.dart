import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/subscription_provider.dart';
import '../../../../l10n/arb/app_localizations.dart';
import '../../../../core/enums/subscription_enums.dart';

class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final subscription = authProvider.currentStore?.subscription;
    final latestRequest = subscriptionProvider.latestRequest;
    final hasDismissedRejection = subscriptionProvider.hasDismissedRejection;
    final daysRemaining = subscriptionProvider.daysRemaining;

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
      } else if (latestRequest.status == 'rejected' && !hasDismissedRejection) {
        return _buildBanner(
          context,
          icon: Icons.error,
          color: Colors.red,
          message: l10n.rejectedSubscriptionRequest,
          onDismiss: () => subscriptionProvider.dismissRejectionBanner(),
        );
      }
    } else if (subscription.pendingRequestDate != null) {
      return _buildBanner(
        context,
        icon: Icons.access_time_filled,
        color: Colors.orange,
        message: l10n.pendingSubscriptionReview,
      );
    }

    // Now evaluate plan and days
    final plan = subscription.planId;

    bool shouldShowBanner = false;
    if (plan == SubscriptionPlan.trial) {
      shouldShowBanner = true;
    } else if (plan == SubscriptionPlan.proYearly) {
      if (daysRemaining != null && daysRemaining <= 14) {
        shouldShowBanner = true;
      }
    }

    if (!shouldShowBanner) {
      return const SizedBox.shrink();
    }

    // Format the message
    String message = '';
    Color color = Colors.orange;
    IconData icon = Icons.info_outline;

    if (daysRemaining == null) {
      return const SizedBox.shrink();
    }

    if (daysRemaining < 0) {
      // negative days
      message = l10n.subscriptionExpired;
      color = Colors.redAccent;
      icon = Icons.warning_rounded;
    } else if (daysRemaining == 0) {
      message = l10n.subscriptionExpiresToday;
      color = Colors.redAccent;
      icon = Icons.warning_rounded;
    } else {
      if (plan == SubscriptionPlan.trial) {
        message = l10n.trialEndingSoonDays(daysRemaining);
        color = Colors.blueAccent;
      } else {
        message = l10n.proEndingSoonDays(daysRemaining);
        color = Colors.orange;
      }
    }

    return _buildBanner(
      context,
      icon: icon,
      color: color,
      message: message,
    );
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
