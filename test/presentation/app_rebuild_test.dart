import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class MockAuthProvider extends ChangeNotifier {
  void triggerNotify() {
    notifyListeners();
  }
}

class MockThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
}

class MockLocalizationProvider extends ChangeNotifier {
  Locale locale = const Locale('en');
}

void main() {
  group('App Rebuild Behavior (Failing Test)', () {
    testWidgets('MaterialApp should NOT rebuild when AuthProvider changes', (tester) async {
      int buildCount = 0;

      final authProvider = MockAuthProvider();
      final themeProvider = MockThemeProvider();
      final localizationProvider = MockLocalizationProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MockAuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<MockThemeProvider>.value(value: themeProvider),
            ChangeNotifierProvider<MockLocalizationProvider>.value(value: localizationProvider),
          ],
          child: Consumer2<MockThemeProvider, MockLocalizationProvider>(
            builder: (context, theme, loc, child) {
              buildCount++;
              return MaterialApp(
                home: Container(),
              );
            },
          ),
        ),
      );

      expect(buildCount, 1);

      // Trigger change in AuthProvider
      authProvider.triggerNotify();
      await tester.pump();

      // In the CURRENT implementation, buildCount will be 2 (FAILURE)
      // We want it to be 1 after the fix.
      expect(buildCount, 1, reason: 'MaterialApp should not rebuild on Auth change');
    });
  });
}
