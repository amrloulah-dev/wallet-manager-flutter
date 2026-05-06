import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/route_constants.dart';
import 'core/services/analytics_service.dart';
import 'core/widgets/global_overlay_listener.dart';

import 'data/services/local_storage_service.dart';
import 'data/services/transaction_validator_service.dart';
import 'data/repositories/system_config_repository.dart';
import 'data/repositories/employee_repository.dart';
import 'data/repositories/wallet_repository.dart';
import 'data/repositories/debt_repository.dart';
import 'data/repositories/stats_repository.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/localization_provider.dart';
import 'providers/employee_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/statistics_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/system_config_provider.dart';

import 'presentation/screens/auth/login_landing_screen.dart';
import 'presentation/screens/subscription/paywall_screen.dart';
import 'presentation/screens/subscription/admin_block_screen.dart';

import 'l10n/arb/app_localizations.dart';
import 'routes/navigation_service.dart';
import 'routes/app_router.dart';

import 'core/enums/subscription_enums.dart';
import 'core/enums/user_enums.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider(
          localStorage: sl<LocalStorageService>(),
        )),
        ChangeNotifierProvider(
          create: (_) => SystemConfigProvider(
              repository: sl<SystemConfigRepository>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SubscriptionProvider>(
          create: (context) => SubscriptionProvider(
              authProvider: Provider.of<AuthProvider>(context, listen: false)),
          update: (_, auth, previous) => (previous ?? SubscriptionProvider(authProvider: auth))
            ..updateAuthProvider(auth),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, SubscriptionProvider, EmployeeProvider>(
            create: (_) =>
                EmployeeProvider(employeeRepository: sl<EmployeeRepository>()),
            update: (_, auth, subscription, previous) => (previous ??
                EmployeeProvider(employeeRepository: sl<EmployeeRepository>()))
              ..updateSubscriptionProvider(subscription)
              ..setStoreId(auth.currentStoreId),
        ),
        Provider(create: (_) => TransactionValidatorService()),
        ChangeNotifierProxyProvider2<AuthProvider, SubscriptionProvider, WalletProvider>(
          lazy: false,
          create: (context) => WalletProvider(
              authProvider: Provider.of<AuthProvider>(context, listen: false),
              subscriptionProvider: Provider.of<SubscriptionProvider>(context, listen: false),
              walletRepository: sl<WalletRepository>()),
          update: (_, auth, subscription, previous) => (previous ??
              WalletProvider(
                  authProvider: auth, 
                  subscriptionProvider: subscription,
                  walletRepository: sl<WalletRepository>()))
            ..updateAuthState(auth)
            ..updateSubscriptionProvider(subscription),
        ),
        ChangeNotifierProxyProvider<AuthProvider, DebtProvider>(
          create: (context) => DebtProvider(
              authProvider: Provider.of<AuthProvider>(context, listen: false),
              debtRepository: sl<DebtRepository>()),
          update: (_, auth, previous) => (previous ??
              DebtProvider(
                  authProvider: auth, debtRepository: sl<DebtRepository>()))
            ..updateAuthState(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, auth, prev) => prev!..updateAuthState(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, StatisticsProvider>(
          create: (_) => StatisticsProvider(
            statsRepository: sl<StatsRepository>(),
          ),
          update: (_, auth, previous) =>
              previous!..setStoreId(auth.currentStoreId),
        ),
      ],
      child: GlobalOverlayListener(
        localStorage: sl<LocalStorageService>(),
        child: Consumer2<ThemeProvider, LocalizationProvider>(
          builder: (context, themeProvider, localizationProvider, child) {
            return MaterialApp(
              navigatorKey:
                  NavigationService.navigatorKey, // Set the navigatorKey
              title: 'Wallet Manager',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              locale: localizationProvider.locale,
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: BotToastInit(), //1. call BotToastInit
              navigatorObservers: [
                BotToastNavigatorObserver(),
                AnalyticsService.observer,
              ], //2. registered route observer
              onGenerateRoute: AppRouter.generateRoute,
              home: const AuthCheckWrapper(),
            );
          },
        ),
      ),
    );
  }
}
class AuthCheckWrapper extends StatefulWidget {
  const AuthCheckWrapper({super.key});

  @override
  State<AuthCheckWrapper> createState() => _AuthCheckWrapperState();
}

class _AuthCheckWrapperState extends State<AuthCheckWrapper> {
  bool _isNavigating = false; // 🔴 هذا هو مفتاح الحل

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.status == AuthStatus.idle) {
        auth.tryAutoLogin();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        
        // 1. Guard against Admin Block
        if (auth.currentStore?.subscription.status == SubscriptionStatus.suspended) {
          return const AdminBlockScreen();
        }

        // 2. Guard against Expired License
        if (auth.isSubscriptionExpired && auth.currentStore?.subscription.planId != SubscriptionPlan.lifetime) {
          return const PaywallScreen();
        }

        // 3. Check Authentication & Navigate Mapped
        if (auth.isAuthenticated && !_isNavigating) {
          _isNavigating = true; // نمنع أي محاولة انتقال أخرى
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final role = auth.currentUser?.role;
            if (role == UserRole.owner || role == UserRole.employee) {
               // استخدمنا pushReplacementNamed كما كانت في كودك الأصلي
               Navigator.of(context).pushReplacementNamed(RouteConstants.ownerDashboard);
            } else {
               auth.logout();
            }
          });
          
          // نرجع شاشة فاضية أو تحميل أثناء الانتقال
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 4. Loading State
        if (auth.status == AuthStatus.loading || auth.status == AuthStatus.idle) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 5. Default Fallback (Not Authenticated)
        return const LoginLandingScreen();
      },
    );
  }
}
