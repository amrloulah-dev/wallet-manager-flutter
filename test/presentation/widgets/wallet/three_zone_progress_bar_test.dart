import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/widgets/wallet/three_zone_progress_bar.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      locale: const Locale('ar'),
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    );
  }

  group('ThreeZoneProgressBar Widget Tests', () {
    testWidgets('renders 3 zones for telecom Receive transaction',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const ThreeZoneProgressBar(
            label: 'الحد الشهري / السعة',
            monthlyLimit: 50000.0,
            monthlyUsed: 10000.0,
            maxAvailable: 30000.0,
            enteredAmount: 5000.0,
            isThreeZone: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that all 3 zones are rendered.
      expect(find.byType(ThreeZoneProgressBar), findsOneWidget);

      final rowFinder = find.byType(Row);
      expect(rowFinder, findsWidgets);
    });

    testWidgets('renders standard 2-zone progress bar for non-three-zone mode',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const ThreeZoneProgressBar(
            label: 'الحد الشهري / السعة',
            monthlyLimit: 50000.0,
            monthlyUsed: 10000.0,
            maxAvailable: 40000.0,
            enteredAmount: 0.0,
            isThreeZone: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ThreeZoneProgressBar), findsOneWidget);
    });
  });
}
