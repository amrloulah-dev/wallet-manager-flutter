import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../providers/system_config_provider.dart';
import '../../../data/models/system_configs_model.dart';
import 'package:provider/provider.dart';
import 'payment_modal_screen.dart';
import '../../../core/enums/subscription_enums.dart';
import '../../../core/constants/route_constants.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Selector<SystemConfigProvider, SystemConfigsModel>(
      selector: (_, provider) => provider.configs,
      builder: (context, systemConfigs, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(loc.upgradeAccount),
            centerTitle: true,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.workspace_premium,
                  size: 80,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                Text(
                  loc.unlockStoreCapabilities,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.paywallSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Pro Yearly Plan
                _buildPlanCard(
                  context,
                  loc: loc,
                  title: loc.proYearlyTitle,
                  price: loc.proYearlyPrice,
                  features: [
                    loc.proFeature1,
                    loc.proFeature2,
                    loc.proFeature3,
                    loc.proFeature4,
                  ],
                  isPopular: true,
                  onTap: () => PaymentModalScreen.show(
                      context, SubscriptionPlan.proYearly), // ENUM refactor
                ),
                const SizedBox(height: 24),

                // Lifetime VIP Plan
                if (systemConfigs.lifetimePlanEnabled)
                  _buildPlanCard(
                    context,
                    loc: loc,
                    title: loc.lifetimeTitle,
                    price: loc.lifetimePrice,
                    scarcityText: systemConfigs.remainingLifetimeSeats > 0
                        ? loc.remainingSeats(
                            systemConfigs.remainingLifetimeSeats)
                        : loc.soldOut,
                    isDisabled: systemConfigs.remainingLifetimeSeats <= 0,
                    features: [
                      loc.lifetimeFeature1,
                      loc.lifetimeFeature2,
                      loc.lifetimeFeature3,
                      loc.lifetimeFeature4,
                    ],
                    isPopular: false,
                    color: Colors.purple.shade700,
                    onTap: systemConfigs.remainingLifetimeSeats > 0
                        ? () => PaymentModalScreen.show(
                            context, SubscriptionPlan.lifetime) // ENUM refactor
                        : null,
                  ),
                if (systemConfigs.lifetimePlanEnabled)
                  const SizedBox(height: 32),

                Text(
                  loc.termsAgreement,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Safely dismiss the Paywall to reveal the Dashboard underneath
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(
                          context, RouteConstants.mainDashboard);
                    }
                  },
                  child: Text(
                    loc.continueWithFreePlan,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      decoration: TextDecoration.underline,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required AppLocalizations loc,
    required String title,
    required String price,
    required List<String> features,
    VoidCallback? onTap,
    bool isPopular = false,
    String? scarcityText,
    bool isDisabled = false,
    Color? color,
  }) {
    final themeColor = color ?? Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular
              ? Colors.amber
              : (isDisabled ? Colors.grey : themeColor.withValues(alpha: 0.3)),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDisabled
                ? Colors.transparent
                : themeColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Theme.of(context).cardColor,
            isDisabled
                ? Colors.grey.withValues(alpha: 0.05)
                : themeColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (isPopular)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadiusDirectional.only(
                      bottomStart: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    loc.mostPopular,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            if (scarcityText != null)
              PositionedDirectional(
                top: 0,
                start: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    borderRadius: const BorderRadiusDirectional.only(
                      bottomEnd: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    scarcityText,
                    style: TextStyle(
                      color: isDisabled
                          ? Colors.red.shade900
                          : Colors.deepOrange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDisabled ? Colors.grey : themeColor,
                      decoration:
                          isDisabled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: isDisabled ? Colors.grey : Colors.green,
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(f,
                                    style: TextStyle(
                                        fontSize: 16,
                                        color:
                                            isDisabled ? Colors.grey : null))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDisabled ? Colors.grey : themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                          isDisabled ? loc.unavailable : loc.subscribeNow,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold,color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
