import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/presentation/overlays/transaction_overlay_screen.dart';
import 'app.dart';
import 'data/services/firebase_service.dart';
import 'data/services/local_storage_service.dart';
import 'core/di/service_locator.dart';
import 'core/services/sms_service.dart';
import 'core/services/background_service.dart';
import 'core/errors/app_error_handler.dart';
import 'core/errors/error_severity.dart';

void main() async {
  // Ensure all bindings are initialized before async operations.
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 [APP START] WidgetsFlutterBinding initialized.');

  // Initialize Error Handler early
  AppErrorHandler.init();

  try {
    // Step 1: Initialize Firebase.
    debugPrint('⏳ [INIT DATA] Initializing Firebase...');
    await FirebaseService().initialize();
    debugPrint('✅ [INIT SUCCESS] Firebase initialized.');

    // Step 2: Setup Dependency Injection.
    debugPrint('⏳ [INIT DATA] Setting up Service Locator...');
    await setupServiceLocator();
    debugPrint('✅ [INIT SUCCESS] Service Locator ready.');

    // Step 3: Check and initialize SMS automation if enabled
    if (sl<LocalStorageService>().isSmsAutomationEnabled) {
      debugPrint('⏳ [INIT DATA] Initializing SMS Service...');
      unawaited(SmsService().init());
    }

    // Step 4: Run the application IMMEDIATELY (Do not wait for heavy background services)
    debugPrint('🚀 [INIT SUCCESS] Running MyApp.');
    runApp(const MyApp());

    // Step 5: Configure the Guardian Isolate (background service).
    // التشغيل المتأخر: ننتظر 3 ثواني حتى يستقر التطبيق وتفتح الشاشة للمستخدم
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        debugPrint('⏳ [BACKGROUND] Starting Background Service silently...');
        await initializeBackgroundService();
        debugPrint('✅ [BACKGROUND] Service is now active and monitoring SMS.');
      } catch (e) {
        debugPrint('❌ [BACKGROUND] Failed to start Background Service: $e');
      }
    });

  } catch (e, stackTrace) {
    debugPrint('❌ [INIT FATAL] App initialization failed: $e');
    debugPrint('🔍 [STACK TRACE]: $stackTrace');
    AppErrorHandler.handle(e,
        severity: ErrorSeverity.critical,
        operation: 'app_initialization',
        stackTrace: stackTrace);
    debugPrint("🚨 INIT ERROR: $e");
    debugPrint("🚨 STACKTRACE: $stackTrace");
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚨 Initialization Error',
                      style: TextStyle(
                          fontSize: 22,
                          color: Colors.red,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Error:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(e.toString(),
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black)),
                  const SizedBox(height: 16),
                  const Text('Stack Trace:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(stackTrace.toString(),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
//  OVERLAY ENTRY POINT
// ==========================================
@pragma("vm:entry-point")
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  // 1. Initialize Firebase (Crucial for Overlay Provider/Repo)
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Firebase init error in overlay: $e");
    }
  }

  if (firebaseInitialized) {
    // 2. Initialize Dependency Injection (Includes Storage init)
    await setupServiceLocator();
    runApp(const TransactionOverlayApp());
  } else {
    // 3. Failsafe: Show elegant Error UI if Firebase fails
    runApp(const OverlayFirebaseFailsafeApp());
  }
}

@visibleForTesting
class OverlayFirebaseFailsafeApp extends StatelessWidget {
  const OverlayFirebaseFailsafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "❌ Connection Error",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Please use the main app to record your transaction.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => FlutterOverlayWindow.closeOverlay(),
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
        ),
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