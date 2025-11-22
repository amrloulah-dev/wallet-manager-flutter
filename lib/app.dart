import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/providers/theme_provider.dart';
import 'package:walletmanager/providers/localization_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/route_constants.dart';
import 'l10n/arb/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'package:walletmanager/routes/navigation_service.dart';
import 'routes/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),

        // Feature-specific providers will be moved to the router
      ],
      child: Consumer3<AuthProvider, ThemeProvider, LocalizationProvider>(
        builder: (context, authProvider, themeProvider, localizationProvider, child) {
          return MaterialApp(
            navigatorKey: NavigationService.navigatorKey, // Set the navigatorKey
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
            navigatorObservers: [BotToastNavigatorObserver()], //2. registered route observer
            onGenerateRoute: AppRouter.generateRoute,
            initialRoute: _getInitialRoute(authProvider),
          );
        },
      ),
    );
  }

  String _getInitialRoute(AuthProvider authProvider) {
    // ✅ Wait until authentication completes properly
    if (authProvider.status == AuthStatus.loading || authProvider.status == AuthStatus.idle) {
      return RouteConstants.storeRegistration;
    }

    if (authProvider.status == AuthStatus.authenticated) {
      // ✅ Prefer the most reliable role source
      final userRole = authProvider.currentUser?.role ?? '';

      if (userRole == 'employee') {
        return RouteConstants.employeeDashboard;
      } else if (userRole == 'owner') {
        return RouteConstants.ownerDashboard;
      } else {
        // Invalid or unknown role — force re-login
        return RouteConstants.storeRegistration;
      }
    }

    // Default fallback for unauthenticated/error states
    return RouteConstants.storeRegistration;
  }
}
