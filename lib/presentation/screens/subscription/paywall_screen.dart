import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../providers/system_config_provider.dart';
import '../../../providers/platform_settings_provider.dart';
import '../../../data/models/system_configs_model.dart';
import '../../../data/models/subscription_plan_model.dart';
import 'package:provider/provider.dart';
import 'payment_modal_screen.dart';
import '../../../core/enums/subscription_enums.dart';
import '../../../core/constants/route_constants.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  SubscriptionPlan? _mapPlanKeyToEnum(String key) {
    final lowerKey = key.toLowerCase().replaceAll('_', '');
    if (lowerKey == 'free') return SubscriptionPlan.free;
    if (lowerKey == 'trial') return SubscriptionPlan.trial;
    if (lowerKey == 'proyearly') return SubscriptionPlan.proYearly;
    if (lowerKey == 'lifetime') return SubscriptionPlan.lifetime;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final settingsProvider = Provider.of<PlatformSettingsProvider>(context);
    final plansMap = settingsProvider.settings.plans;

    // Filter active plans
    final activePlans =
        plansMap.entries.where((entry) => entry.value.isActive).toList();

    // Sorting order
    const order = ['free', 'trial', 'proyearly', 'lifetime'];

    int getSortOrder(String key) {
      final index = order.indexOf(key.toLowerCase().replaceAll('_', ''));
      return index == -1 ? 9999 : index;
    }

    activePlans.sort((a, b) {
      return getSortOrder(a.key).compareTo(getSortOrder(b.key));
    });

    String getPlanTitle(String key, SubscriptionPlanModel plan) {
      final id = key.toLowerCase().replaceAll('_', '');
      if (id == 'free') return loc.freePlan;
      if (id == 'trial') return loc.trialPlan;
      if (id == 'proyearly') return loc.proYearlyTitle;
      if (id == 'lifetime') return loc.lifetimeTitle;
      return plan.name;
    }

    String getPlanPrice(String key, SubscriptionPlanModel plan) {
      final id = key.toLowerCase().replaceAll('_', '');
      if (id == 'free') return loc.freePrice;
      if (id == 'trial') return loc.trialPrice;
      if (id == 'proyearly')
        return loc.proYearlyPriceTemplate(plan.price.toString());
      if (id == 'lifetime')
        return loc.lifetimePriceTemplate(plan.price.toString());
      return '${plan.price} EGP';
    }

    List<String> getPlanFeatures(String key, SubscriptionPlanModel plan) {
      final id = key.toLowerCase().replaceAll('_', '');
      if (id == 'free') {
        return [
          loc.freeFeature1,
          loc.freeFeature2(plan.maxWallets),
          loc.freeFeature3(plan.maxEmployees),
          loc.freeFeature4,
        ];
      }
      if (id == 'trial') {
        return [
          loc.trialFeature1,
          loc.trialFeature2(plan.maxWallets),
          loc.trialFeature3(plan.maxEmployees),
          loc.trialFeature4,
        ];
      }
      if (id == 'proyearly') {
        return [
          loc.proFeature1,
          loc.proFeature2,
          loc.proFeature3,
          loc.proFeature4,
        ];
      }
      if (id == 'lifetime') {
        return [
          loc.lifetimeFeature1,
          loc.lifetimeFeature2,
          loc.lifetimeFeature3,
          loc.lifetimeFeature4,
        ];
      }
      if (plan.description.isNotEmpty) {
        return [plan.description];
      }
      return [];
    }

    if (activePlans.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(loc.upgradeAccount),
          centerTitle: true,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No subscription plans available at the moment.',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(
                          context, RouteConstants.mainDashboard);
                    }
                  },
                  child: Text(loc.continueWithFreePlan),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

                // Dynamic plan cards
                ...activePlans.map((entry) {
                  final key = entry.key;
                  final plan = entry.value;
                  final planEnum = _mapPlanKeyToEnum(key);
                  final isLifetime = planEnum == SubscriptionPlan.lifetime;
                  final isPurchasable =
                      planEnum == SubscriptionPlan.proYearly || isLifetime;

                  // Business rule for lifetime plan visibility
                  if (isLifetime && !systemConfigs.lifetimePlanEnabled) {
                    return const SizedBox.shrink();
                  }

                  final String title = getPlanTitle(key, plan);
                  final String priceStr = getPlanPrice(key, plan);
                  final List<String> features = getPlanFeatures(key, plan);

                  String? scarcityText;
                  bool isPlanDisabled = !isPurchasable;

                  if (isLifetime) {
                    scarcityText = systemConfigs.remainingLifetimeSeats > 0
                        ? loc.remainingSeats(
                            systemConfigs.remainingLifetimeSeats)
                        : loc.soldOut;
                    isPlanDisabled = systemConfigs.remainingLifetimeSeats <= 0;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: _buildPlanCard(
                      context,
                      loc: loc,
                      title: title,
                      price: priceStr,
                      features: features,
                      isPopular: planEnum == SubscriptionPlan.proYearly,
                      scarcityText: scarcityText,
                      isDisabled: isPlanDisabled,
                      color: isLifetime ? Colors.purple.shade700 : null,
                      onTap: isPlanDisabled
                          ? null
                          : () => PaymentModalScreen.show(context, planEnum!),
                    ),
                  );
                }),

                const SizedBox(height: 8),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
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
