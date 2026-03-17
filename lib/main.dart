import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:walletmanager/presentation/overlays/transaction_overlay_screen.dart';
import 'app.dart';
import 'data/services/firebase_service.dart';
import 'data/services/local_storage_service.dart';
import 'core/services/sms_service.dart';
import 'core/services/background_service.dart';

void main() async {
  // Ensure all bindings are initialized before async operations.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Step 1: Initialize Firebase.
    await FirebaseService().initialize();

    // Step 2: Initialize Local Storage.
    await LocalStorageService().initialize();

    // Step 3: Check and initialize SMS automation if enabled
    if (LocalStorageService.instance.isSmsAutomationEnabled) {
      await SmsService().init(); // Permissions only
    }

    // Step 4: Configure the Guardian Isolate (background service).
    // This registers the onStart handler. The service auto-starts
    // based on the `autoStart: true` configuration and persists
    // across app kills.
    await initializeBackgroundService();

    // Add global error catcher
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    // Step 5: Run the application.
    runApp(const MyApp());
  } catch (e, stackTrace) {
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

  // 1. Initialize Firebase (Crucial for Overlay Provider/Repo)
  try {
    await Firebase.initializeApp();
  } catch (e) {
  }

  // 2. Initialize Storage (Crucial for reading wallet data)
  await LocalStorageService.instance.initialize();

  runApp(const TransactionOverlayApp());
}

class TransactionOverlayApp extends StatelessWidget {
  const TransactionOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Read cached values from LocalStorage. Fallback to light and 'ar' if not found.
    final bool isDark = LocalStorageService.instance.isDarkMode;
    final String lang = LocalStorageService.instance.languageCode;
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
