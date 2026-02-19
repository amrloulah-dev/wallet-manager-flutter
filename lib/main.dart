import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:walletmanager/presentation/overlays/transaction_overlay_screen.dart';
import 'app.dart';
import 'data/services/firebase_service.dart';
import 'data/services/local_storage_service.dart';

void main() async {
  // Ensure all bindings are initialized before async operations.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Step 1: Initialize Firebase.
    await FirebaseService().initialize();

    // Step 2: Initialize Local Storage.
    await LocalStorageService().initialize();

    // Step 3: Run the application.
    runApp(const MyApp());
  } catch (e) {
    // Step 4: Handle initialization errors gracefully.
    // In a real production app, you might want to log this to a remote service.
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'An error occurred while initializing the app.\nPlease try again later.',
              style: TextStyle(fontSize: 18, color: Colors.red),
              textAlign: TextAlign.center,
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
  debugPrint("🟢 OVERLAY ENTRY POINT STARTED!");
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase (Crucial for Overlay Provider/Repo)
  try {
    await Firebase.initializeApp();
    debugPrint("🟢 Firebase Initialized in Overlay");
  } catch (e) {
    debugPrint("⚠️ Firebase Init Error in Overlay: $e");
  }

  // 2. Initialize Storage (Crucial for reading wallet data)
  await LocalStorageService.instance.initialize();

  runApp(const TransactionOverlayApp());
}

class TransactionOverlayApp extends StatelessWidget {
  const TransactionOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TransactionOverlayScreen(),
    );
  }
}
