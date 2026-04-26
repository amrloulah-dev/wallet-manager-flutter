import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/wallet_model.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/debt_provider.dart';
import '../../../../providers/auth_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../widgets/common/skeleton_card.dart';
import '../../../widgets/dashboard/alert_card.dart';
import '../../../widgets/dashboard/section_header.dart';
import '../../../../core/enums/user_enums.dart';

class DashboardAlerts extends StatelessWidget {
  const DashboardAlerts({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<WalletProvider,
        ({bool isLoading, List<WalletModel> alertWallets})>(
      selector: (context, wp) => (
        isLoading: wp.isLoading,
        alertWallets: wp.wallets
            .where((w) => w.getLimits().dailyPercentage >= 90)
            .toList(),
      ),
      shouldRebuild: (prev, next) =>
          prev.isLoading != next.isLoading ||
          !listEquals(
            prev.alertWallets.map((w) => w.walletId).toList(),
            next.alertWallets.map((w) => w.walletId).toList(),
          ),
      builder: (context, walletData, child) {
        if (walletData.isLoading) {
          return const SkeletonCard(height: 80);
        }

        return Selector<DebtProvider, int>(
          selector: (context, dp) => dp.summary['openDebtsCount'] ?? 0,
          builder: (context, openDebtsCount, child) {
            final List<Widget> alerts = [];

            for (var wallet in walletData.alertWallets) {
              alerts.add(AlertCard(
                message: AppLocalizations.of(context)!
                    .walletAlertMessage(wallet.phoneNumber),
                type: AlertType.warning,
                onActionTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  final canAccess = user?.role == UserRole.owner || // ENUM refactor
                      (user?.permissions?.viewWallets ?? false);

                  if (canAccess) {
                    Navigator.pushNamed(
                      context,
                      RouteConstants.walletDetails,
                      arguments: wallet.walletId,
                    );
                  } else {
                    ToastUtils.showError(
                        AppLocalizations.of(context)!.accessDenied);
                  }
                },
                actionText: AppLocalizations.of(context)!.viewDetails,
              ));
            }

            if (openDebtsCount > 0) {
              alerts.add(AlertCard(
                message:
                    AppLocalizations.of(context)!.openDebtsAlert(openDebtsCount),
                type: AlertType.error,
                onActionTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  final canAccess = user?.role == UserRole.owner || // ENUM refactor
                      (user?.permissions?.viewDebts ?? false);

                  if (canAccess) {
                    Navigator.pushNamed(context, RouteConstants.debtsList);
                  } else {
                    ToastUtils.showError(
                        AppLocalizations.of(context)!.accessDenied);
                  }
                },
                actionText: AppLocalizations.of(context)!.viewDebts,
              ));
            }

            if (alerts.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  SectionHeader(title: AppLocalizations.of(context)!.alerts),
                  const SizedBox(height: 12),
                  ...alerts.map((alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: alert,
                      )),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
