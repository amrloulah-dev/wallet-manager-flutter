import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../data/models/store_model.dart';
import '../../../../l10n/arb/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/subscription_provider.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/enums/subscription_enums.dart';
import 'section_title.dart';

class AccountInfoSection extends StatelessWidget {
  const AccountInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
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
            SectionTitle(title: AppLocalizations.of(context)!.accountInfo),
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
                      backgroundColor: AppColors.primary.withAlpha(26),
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
                          value: DateHelper.formatDateTime(
                              store.createdAt ?? DateTime.now())),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // License Card (Owner only)
            if (user?.isOwner == true && store != null)
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                    context, RouteConstants.subscriptionDetails),
                child: _buildLicenseCard(context, store.subscription),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLicenseCard(
      BuildContext context, StoreSubscription subscription) {
    return Consumer2<AuthProvider, SubscriptionProvider>(
        builder: (context, authProvider, subProvider, _) {
      final isTrial = authProvider.isTrial;
      final isExpired = subProvider.isExpired;
      final isLifetime = subscription.planId == SubscriptionPlan.lifetime ||
          subscription.endDate == null;
      final daysRemaining =
          isTrial ? authProvider.trialDaysRemaining : subProvider.daysRemaining;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final cardColor = AppColors.licenseCardBg(context,
          isTrial: isTrial, isExpired: isExpired);
      final borderColor = AppColors.licenseCardBorder(context,
          isTrial: isTrial, isExpired: isExpired);

      Color statusColor;
      String statusText;

      if (isTrial) {
        statusColor = isDark ? Colors.amber.shade200 : Colors.amber.shade800;
        statusText = AppLocalizations.of(context)!.trialPeriod;
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
                  value: isTrial ? 'TRIAL' : 'PREMIUM'),
              const SizedBox(height: 12),
              _buildInfoRow(
                  context: context,
                  label: AppLocalizations.of(context)!.expiryDate,
                  value: subscription.endDate != null
                      ? DateHelper.formatDateTime(subscription.endDate!)
                      : 'Lifetime'),
              if (!isExpired) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        isTrial
                            ? AppLocalizations.of(context)!.trialDaysRemaining
                            : AppLocalizations.of(context)!.daysRemaining,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary(context),
                        )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: !isLifetime && (daysRemaining ?? 0) <= 7
                            ? AppColors.warning
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isLifetime
                            ? '∞'
                            : '${daysRemaining ?? 0} ${AppLocalizations.of(context)!.day}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
              if (isExpired || (!isLifetime && (daysRemaining ?? 0) <= 7) || isTrial) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.new_releases_outlined),
                    label: Text(isTrial
                        ? AppLocalizations.of(context)!.upgradeFullVersion
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
                              .withAlpha(26),
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
}
