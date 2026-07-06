import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/presentation/overlays/transaction_overlay_screen.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'app.dart';
import 'data/services/firebase_service.dart';
import 'data/services/local_storage_service.dart';
import 'core/di/service_locator.dart';
import 'core/services/sms_service.dart';
import 'core/services/background_service.dart';
import 'core/errors/app_error_handler.dart';
import 'core/errors/error_severity.dart';
import 'l10n/arb/app_localizations.dart';

void main() async {
  runZonedGuarded(() async {
    // Ensure all bindings are initialized before async operations.
    WidgetsFlutterBinding.ensureInitialized();
    if (kDebugMode) {
      debugPrint('🚀 [APP START] WidgetsFlutterBinding initialized.');
    }

    // Initialize Error Handler early
    AppErrorHandler.init();

    try {
      // Step 1: Initialize Firebase.
      if (kDebugMode) debugPrint('⏳ [INIT DATA] Initializing Firebase...');
      await FirebaseService().initialize();
      if (kDebugMode) debugPrint('✅ [INIT SUCCESS] Firebase initialized.');

      // Step 2: Setup Dependency Injection.
      if (kDebugMode) debugPrint('⏳ [INIT DATA] Setting up Service Locator...');
      await setupServiceLocator();
      await sl<PlatformSettingsProvider>().initialize();
      if (kDebugMode) debugPrint('✅ [INIT SUCCESS] Service Locator & Settings ready.');

      // Step 3: Check and initialize SMS automation if enabled
      if (sl<LocalStorageService>().isSmsAutomationEnabled) {
        if (kDebugMode) debugPrint('⏳ [INIT DATA] Initializing SMS Service...');
        unawaited(SmsService().init());
      }

      // Step 4: Run the application IMMEDIATELY (Do not wait for heavy background services)
      if (kDebugMode) debugPrint('🚀 [INIT SUCCESS] Running MyApp.');
      runApp(const MyApp());

      // Step 5: Configure the Guardian Isolate (background service).
      // التشغيل المتأخر: ننتظر 3 ثواني حتى يستقر التطبيق وتفتح الشاشة للمستخدم
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          if (kDebugMode) {
            debugPrint(
                '⏳ [BACKGROUND] Starting Background Service silently...');
          }
          await initializeBackgroundService();
          if (kDebugMode) {
            debugPrint(
                '✅ [BACKGROUND] Service is now active and monitoring SMS.');
          }
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('❌ [BACKGROUND] Failed to start Background Service: $e');
          }
          AppErrorHandler.handle(e,
              severity: ErrorSeverity.medium,
              operation: 'background_service_init',
              stackTrace: stack);
        }
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [INIT FATAL] App initialization failed: $e');
      }
      if (kDebugMode) debugPrint('🔍 [STACK TRACE]: $stackTrace');

      AppErrorHandler.handle(e,
          severity: ErrorSeverity.critical,
          operation: 'app_initialization',
          stackTrace: stackTrace);

      if (kDebugMode) debugPrint("🚨 INIT ERROR: $e");
      if (kDebugMode) debugPrint("🚨 STACKTRACE: $stackTrace");

      runApp(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 64),
                      const SizedBox(height: 24),
                      const Text(
                        'App initialization failed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }, (error, stack) async {
    await AppErrorHandler.handle(
      error,
      stackTrace: stack,
      severity: ErrorSeverity.critical,
      operation: 'main_zoned_guarded',
    );
  });
}

// ==========================================
//  OVERLAY ENTRY POINT
// ==========================================
@pragma("vm:entry-point")
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Encapsulate and initialize through the explicit FirebaseService pipeline
    await FirebaseService().initialize();

    // Now dependency injection container can safely resolve repositories needing Firestore
    await setupServiceLocator();
    await sl<PlatformSettingsProvider>().initialize();

    runApp(const TransactionOverlayApp());
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint("❌ Overlay init error: $e");
    }
    AppErrorHandler.handle(
      e,
      stackTrace: stack,
      severity: ErrorSeverity.critical,
      operation: 'overlay_init',
    );
    runApp(const OverlayErrorApp());
  }
}

@visibleForTesting
class OverlayErrorApp extends StatelessWidget {
  const OverlayErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Read cached locale from LocalStorage via locator
    final storage = sl<LocalStorageService>();
    final String lang = storage.languageCode;
    final locale = Locale(lang);
    final TextDirection direction =
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        return Directionality(
          textDirection: direction,
          child: child!,
        );
      },
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.overlayConnectionError,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.overlayCompleteFromApp,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => FlutterOverlayWindow.closeOverlay(),
                      child: Text(l10n.close),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TransactionOverlayApp extends StatelessWidget {
  const TransactionOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Read cached values from LocalStorage via locator
    final storage = sl<LocalStorageService>();
    final bool isDark = storage.isDarkMode;
    final String lang = storage.languageCode;
    final TextDirection direction =
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        primaryColor: Colors
            .blue, // Using a generic blue as fallback, or use AppColors.primary if available
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        primaryColor: Colors.blueAccent,
        cardColor: const Color(0xFF1E1E1E),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: direction,
          child: child!,
        );
      },
      home: const TransactionOverlayScreen(),
    );
  }
}
