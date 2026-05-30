import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import 'paywall_screen.dart';
import '../../../data/models/store_model.dart';
import '../../../providers/employee_provider.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/enums/subscription_enums.dart';

class SubscriptionDetailsScreen extends StatelessWidget {
  const SubscriptionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final subscription = context.select<AuthProvider, StoreSubscription?>(
      (p) => p.currentStore?.subscription,
    );
    final stats = context.select<AuthProvider, StoreStats?>(
      (p) => p.currentStore?.stats,
    );

    if (subscription == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPro = subscription.planId == SubscriptionPlan.proYearly;
    final isLifetime = subscription.planId == SubscriptionPlan.lifetime;
    final isTrial = subscription.planId == SubscriptionPlan.trial;

    String planName = loc.freePlan;
    if (isPro) planName = loc.proYearlyPlan;
    if (isLifetime) planName = loc.lifetimeVipPlan;
    if (isTrial) planName = loc.trialPlan;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.subscriptionDetails),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(context, loc, planName, subscription, isLifetime),
            const SizedBox(height: 24),
            Text(
              loc.currentUsage,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildLimitItem(
              context,
              title: loc.activeWallets,
              current: stats?.totalWallets ?? 0,
              max: subscription.maxWallets,
              icon: Icons.account_balance_wallet,
            ),
            const SizedBox(height: 12),
            _buildLimitItem(
              context,
              title: loc.employeeAccounts,
              current: context.select<EmployeeProvider, int>(
                  (p) => p.employeesCount), // dynamic employee count
              max: subscription.maxEmployees,
              icon: Icons.people,
            ),
            const SizedBox(height: 32),
            if (!isLifetime) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                  },
                  icon: const Icon(Icons.upgrade),
                  label: Text(loc.upgradeSubscription),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, AppLocalizations loc,
      String planName, StoreSubscription subscription, bool isLifetime) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.currentPlan,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subscription.status == SubscriptionStatus.active
                      ? loc.active
                      : loc.suspended,
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            planName,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (!isLifetime && subscription.endDate != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  loc.expiryDateValue(DateHelper.formatDateTime(
                      subscription.endDate!,
                      locale: Localizations.localeOf(context).languageCode)),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitItem(BuildContext context,
      {required String title,
      required int current,
      required int max,
      required IconData icon}) {
    final double percent = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    final isMax = max == 999;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                isMax ? '$current / ∞' : '$current / $max',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isMax)
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.9 ? Colors.red : Theme.of(context).primaryColor,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
        ],
      ),
    );
  }
}
