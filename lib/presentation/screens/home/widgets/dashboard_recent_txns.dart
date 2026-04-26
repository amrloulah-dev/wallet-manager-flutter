import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../providers/transaction_provider.dart';
import '../../../../providers/auth_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../widgets/common/skeleton_list.dart';
import '../../../widgets/transaction/transaction_card.dart';
import '../../../widgets/dashboard/section_header.dart';
import '../../../../core/enums/user_enums.dart';

class DashboardRecentTxns extends StatelessWidget {
  const DashboardRecentTxns({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Selector<TransactionProvider,
        ({bool isLoading, List<TransactionModel> recentFive})>(
      selector: (context, provider) => (
        isLoading: provider.isLoading,
        recentFive: provider.transactions.take(5).toList(),
      ),
      shouldRebuild: (prev, next) =>
          prev.isLoading != next.isLoading ||
          !listEquals(
            prev.recentFive.map((t) => t.transactionId).toList(),
            next.recentFive.map((t) => t.transactionId).toList(),
          ),
      builder: (context, data, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              SectionHeader(
                title: l10n.recentTransactions,
                actionText: l10n.viewAll,
                onActionTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null &&
                      (user.role == UserRole.owner || // ENUM refactor
                          user.hasPermission((p) => p.createTransaction) ||
                          user.hasPermission((p) => p.viewAllTransactions))) {
                    Navigator.pushNamed(
                        context, RouteConstants.todayTransactions);
                  } else {
                    ToastUtils.showError(
                        l10n.accessDenied);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (data.isLoading)
                const SkeletonList(itemCount: 2, itemHeight: 80)
              else if (data.recentFive.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    l10n.noTransactionsToday,
                    style: AppTextStyles.bodyMedium,
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.recentFive.length,
                  itemBuilder: (context, index) {
                    final transaction = data.recentFive[index];
                    return TransactionCard(
                      key: ValueKey('recent_tx_${transaction.transactionId}'),
                      transaction: transaction,
                      onTap: () {
                        final user = context.read<AuthProvider>().currentUser;
                        if (user != null &&
                            user.hasPermission((p) => p.viewAllTransactions)) {
                          Navigator.pushNamed(
                            context,
                            RouteConstants.transactionDetails,
                            arguments: transaction.transactionId,
                          );
                        } else {
                          ToastUtils.showError(
                              l10n.noPermissionViewTransactionDetails);
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
