import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/providers/theme_provider.dart';
import 'package:walletmanager/providers/localization_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/route_constants.dart';
import 'l10n/arb/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'package:walletmanager/routes/navigation_service.dart';
import 'routes/app_router.dart';
import 'presentation/screens/auth/login_landing_screen.dart';
import 'presentation/screens/auth/license_expired_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        ChangeNotifierProvider(
            create: (_) =>
                EmployeeProvider(employeeRepository: EmployeeRepository())),

        // Feature-specific providers will be moved to the router
      ],
      child: Consumer3<AuthProvider, ThemeProvider, LocalizationProvider>(
        builder: (context, authProvider, themeProvider, localizationProvider,
            child) {
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
              BotToastNavigatorObserver()
            ], //2. registered route observer
            onGenerateRoute: AppRouter.generateRoute,
            home: const AuthCheckWrapper(),
          );
        },
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
  @override
  void initState() {
    super.initState();
    // Check auth state immediately if not already doing so
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
        if (auth.status == AuthStatus.loading ||
            auth.status == AuthStatus.idle) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (auth.isSubscriptionExpired) {
          return const LicenseExpiredScreen();
        }

        if (auth.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final role = auth.currentUser?.role;
            if (role == 'owner') {
              Navigator.of(context)
                  .pushReplacementNamed(RouteConstants.ownerDashboard);
            } else if (role == 'employee') {
              Navigator.of(context)
                  .pushReplacementNamed(RouteConstants.employeeDashboard);
            } else {
              // Fallback for unknown role, show login
              // Note: If we are here, we probably shouldn't stay in infinite loop
              // But usually role is well defined.
              // Just let it fall through to login logic?
              // No, we should probably logout.
              auth.logout();
            }
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return const LoginLandingScreen();
      },
    );
  }
}
