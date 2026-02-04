import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/debt_provider.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/data/models/store_model.dart';
import '../core/constants/route_constants.dart';
import '../presentation/screens/auth/login_landing_screen.dart';
import '../presentation/screens/auth/store_registration_screen.dart';
import '../presentation/screens/auth/employee_login_screen.dart';
import '../presentation/screens/home/owner_dashboard_screen.dart';
import '../presentation/screens/home/employee_dashboard_screen.dart';
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
import '../presentation/screens/settings/upgrade_screen.dart';
import '../presentation/screens/employees/add_employee_screen.dart';
import '../presentation/screens/employees/manage_employees_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteConstants.loginLanding:
        return _buildRoute(const LoginLandingScreen(), settings);

      case RouteConstants.storeRegistration:
        return _buildRoute(const StoreRegistrationScreen(), settings);

      case RouteConstants.employeeLogin:
        final store = settings.arguments as StoreModel;
        return _buildRoute(
          ChangeNotifierProxyProvider<AuthProvider, EmployeeProvider>(
            create: (_) =>
                EmployeeProvider(employeeRepository: EmployeeRepository()),
            update: (_, auth, previous) =>
                previous!..setStoreId(auth.currentStoreId),
            child: EmployeeLoginScreen(store: store),
          ),
          settings,
        );

      case RouteConstants.ownerDashboard:
        return _buildRoute(
          MultiProvider(
            providers: [
              ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
                create: (_) => WalletProvider(),
                update: (_, auth, prev) =>
                    prev!..setStoreId(auth.currentStoreId ?? ''),
              ),
              ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
                create: (_) => TransactionProvider(),
                update: (_, auth, prev) => prev!..updateAuthState(auth),
              ),
              ChangeNotifierProxyProvider<AuthProvider, DebtProvider>(
                create: (_) => DebtProvider(),
                update: (_, auth, prev) =>
                    prev!..setStoreId(auth.currentStoreId ?? ''),
              ),
              ChangeNotifierProxyProvider<AuthProvider, StatisticsProvider>(
                create: (_) => StatisticsProvider(
                  walletRepository: WalletRepository(),
                  transactionRepository: TransactionRepository(),
                  debtRepository: DebtRepository(),
                  statsRepository: StatsRepository(),
                ),
                update: (_, auth, previous) =>
                    previous!..setStoreId(auth.currentStoreId),
              ),
            ],
            child: const OwnerDashboardScreen(),
          ),
          settings,
        );

      case RouteConstants.employeeDashboard:
        return _buildRoute(
          MultiProvider(
            providers: [
              ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
                create: (_) => TransactionProvider(),
                update: (_, auth, prev) => prev!..updateAuthState(auth),
              ),
              ChangeNotifierProxyProvider<AuthProvider, DebtProvider>(
                create: (_) => DebtProvider(),
                update: (_, auth, prev) =>
                    prev!..setStoreId(auth.currentStoreId ?? ''),
              ),
            ],
            child: const EmployeeDashboardScreen(),
          ),
          settings,
        );

      case RouteConstants.walletsList:
      case RouteConstants.walletForm:
      case RouteConstants.walletDetails:
      case RouteConstants.addBalance:
        return _buildRoute(
          ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
            create: (_) => WalletProvider(),
            update: (_, auth, prev) =>
                prev!..setStoreId(auth.currentStoreId ?? ''),
            child: _getPageForWalletRoute(settings),
          ),
          settings,
        );

      case RouteConstants.createTransaction:
        return _buildRoute(
          MultiProvider(
            providers: [
              ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
                create: (_) => WalletProvider(),
                update: (_, auth, prev) =>
                    prev!..setStoreId(auth.currentStoreId ?? ''),
              ),
              ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
                create: (_) => TransactionProvider(),
                update: (_, auth, prev) => prev!..updateAuthState(auth),
              ),
            ],
            child: const CreateTransactionScreen(),
          ),
          settings,
        );

      case RouteConstants.todayTransactions:
      case RouteConstants.transactionDetails:
        return _buildRoute(
          MultiProvider(
            providers: [
              ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
                create: (_) => WalletProvider(),
                update: (_, auth, prev) =>
                    prev!..setStoreId(auth.currentStoreId ?? ''),
              ),
              ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
                create: (_) => TransactionProvider(),
                update: (_, auth, prev) => prev!..updateAuthState(auth),
              ),
              ChangeNotifierProxyProvider<AuthProvider, EmployeeProvider>(
                create: (_) =>
                    EmployeeProvider(employeeRepository: EmployeeRepository()),
                update: (_, auth, prev) =>
                    prev!..setStoreId(auth.currentStoreId),
              ),
            ],
            child: _getPageForTransactionRoute(settings),
          ),
          settings,
        );

      case RouteConstants.debtsList:
      case RouteConstants.addDebt:
        return _buildRoute(
          ChangeNotifierProxyProvider<AuthProvider, DebtProvider>(
            create: (_) => DebtProvider(),
            update: (_, auth, prev) =>
                prev!..setStoreId(auth.currentStoreId ?? ''),
            child: _getPageForDebtRoute(settings),
          ),
          settings,
        );

      case RouteConstants.generalStatistics:
        return _buildRoute(
          ChangeNotifierProxyProvider<AuthProvider, StatisticsProvider>(
            create: (_) => StatisticsProvider(
              walletRepository: WalletRepository(),
              transactionRepository: TransactionRepository(),
              debtRepository: DebtRepository(),
              statsRepository: StatsRepository(),
            ),
            update: (_, auth, previous) =>
                previous!..setStoreId(auth.currentStoreId),
            child: const GeneralStatisticsScreen(),
          ),
          settings,
        );

      case RouteConstants.settings:
        return _buildRoute(const SettingsScreen(), settings);

      case RouteConstants.upgradeScreen:
        final isTrial = settings.arguments as bool? ?? false;
        return _buildRoute(UpgradeScreen(isTrial: isTrial), settings);

      case RouteConstants.addEmployee:
      case RouteConstants.manageEmployees:
        return _buildRoute(
          ChangeNotifierProxyProvider<AuthProvider, EmployeeProvider>(
            create: (_) =>
                EmployeeProvider(employeeRepository: EmployeeRepository()),
            update: (_, auth, prev) => prev!..setStoreId(auth.currentStoreId),
            child: _getPageForEmployeeRoute(settings),
          ),
          settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: const Text('خطأ'),
              centerTitle: true,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'الصفحة المطلوبة غير موجودة.',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(_);
                    },
                    child: const Text('الرجوع'),
                  ),
                ],
              ),
            ),
          ),
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
      pageBuilder: (context, animation, secondaryAnimation) => page,
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
