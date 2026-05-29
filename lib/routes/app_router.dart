import 'package:flutter/material.dart';
import 'package:walletmanager/core/utils/permission_helper.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../core/constants/route_constants.dart';
import '../app.dart';
import '../presentation/screens/auth/login_landing_screen.dart';
import '../presentation/screens/auth/store_registration_screen.dart';
import '../presentation/screens/auth/employee_login_screen.dart';
import '../presentation/screens/home/main_dashboard_screen.dart';
import '../presentation/screens/wallets/wallets_list_screen.dart';
import '../presentation/screens/wallets/wallet_form_screen.dart';
import '../presentation/screens/wallets/wallet_details_screen.dart';
import '../presentation/screens/wallets/add_balance_screen.dart';
import '../presentation/screens/transactions/create_transaction_screen.dart';
import '../presentation/screens/transactions/today_transactions_screen.dart';
import '../presentation/screens/transactions/transaction_details_screen.dart';
import '../presentation/screens/debts/add_debt_screen.dart';
import '../presentation/screens/debts/debts_list_screen.dart';
import '../presentation/screens/statistics/general_statistics_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/subscription/paywall_screen.dart';
import '../presentation/screens/employees/add_employee_screen.dart';
import '../presentation/screens/employees/manage_employees_screen.dart';
import '../presentation/screens/subscription/subscription_details_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteConstants.loginLanding:
        return _buildRoute(const AuthCheckWrapper(), settings);

      case RouteConstants.storeRegistration:
        return _buildRoute(const StoreRegistrationScreen(), settings);

      case RouteConstants.employeeLogin:
        final store = settings.arguments as StoreModel;
        return _buildRoute(EmployeeLoginScreen(store: store), settings);

      case RouteConstants.ownerDashboard:
        return _buildRoute(const MainDashboardScreen(), settings);

      case RouteConstants.walletsList:
      case RouteConstants.walletForm:
      case RouteConstants.walletDetails:
      case RouteConstants.addBalance:
        return _buildRoute(_getPageForWalletRoute(settings), settings);

      case RouteConstants.createTransaction:
        return _buildRoute(const CreateTransactionScreen(), settings);

      case RouteConstants.todayTransactions:
      case RouteConstants.transactionDetails:
        return _buildRoute(_getPageForTransactionRoute(settings), settings);

      case RouteConstants.debtsList:
      case RouteConstants.addDebt:
        return _buildRoute(_getPageForDebtRoute(settings), settings);

      case RouteConstants.generalStatistics:
        return _buildRoute(const GeneralStatisticsScreen(), settings);

      case RouteConstants.settings:
        return _buildRoute(const SettingsScreen(), settings);

      case RouteConstants.upgradeScreen:
        // H005: Route to new PaywallScreen instead of legacy UpgradeScreen
        return _buildRoute(const PaywallScreen(), settings);

      case RouteConstants.subscriptionDetails:
        return _buildRoute(const SubscriptionDetailsScreen(), settings);

      case RouteConstants.addEmployee:
      case RouteConstants.manageEmployees:
        return _buildRoute(_getPageForEmployeeRoute(settings), settings);

      default:
        return MaterialPageRoute(
          builder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            return Scaffold(
              appBar: AppBar(
                title: Text(l10n.error),
                centerTitle: true,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      l10n.pageNotFound,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: Text(l10n.back),
                    ),
                  ],
                ),
              ),
            );
          },
        );
    }
  }

  static Widget _getPageForWalletRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteConstants.walletsList:
        return const WalletsListScreen();
      case RouteConstants.walletForm:
        return const WalletFormScreen();
      case RouteConstants.walletDetails:
        return const WalletDetailsScreen();
      case RouteConstants.addBalance:
        return const AddBalanceScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  static Widget _getPageForTransactionRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteConstants.todayTransactions:
        return const TodayTransactionsScreen();
      case RouteConstants.transactionDetails:
        return const TransactionDetailsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  static Widget _getPageForDebtRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteConstants.debtsList:
        return const DebtsListScreen();
      case RouteConstants.addDebt:
        return const AddDebtScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  static Widget _getPageForEmployeeRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteConstants.addEmployee:
        return const AddEmployeeScreen();
      case RouteConstants.manageEmployees:
        return const ManageEmployeesScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  static Route<dynamic> _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) {
        // Enforce Security Guard at the UI level (Axis 2/Phase 6)
        if (!PermissionHelper.canAccessScreen(context, settings.name ?? '')) {
          // If denied, redirect to Dashboard on next frame and show message
          final msg = AppLocalizations.of(context)!.accessDenied;
          Future.microtask(() {
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              RouteConstants.ownerDashboard,
              (route) => false,
            );
            ToastUtils.showInfo(msg);
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return page;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        var fadeAnimation = animation;

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
