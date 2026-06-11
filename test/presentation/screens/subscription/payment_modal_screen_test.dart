import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/subscription/payment_modal_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionProvider mockSubscriptionProvider;

  setUpAll(() {
    registerFallbackValue(SubscriptionPlan.proYearly);
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockSubscriptionProvider = MockSubscriptionProvider();
    when(() => mockSubscriptionProvider.submitSubscriptionRequest(
          planId: any(named: 'planId'),
          paymentMethod: any(named: 'paymentMethod'),
          receiptNumber: any(named: 'receiptNumber'),
        )).thenAnswer((_) async {});
  });

  Widget buildTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(
            value: mockSubscriptionProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const Scaffold(
          body: PaymentModalScreen(planId: SubscriptionPlan.proYearly),
        ),
      ),
    );
  }

  group('PaymentModalScreen Widget Tests', () {
    testWidgets('Shows phone number field instead of receipt', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final phoneField = find.byType(TextFormField);
      expect(phoneField, findsOneWidget);

      final iconFinder = find.byIcon(Icons.phone);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('Validates phone number', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final confirmButton = find.byType(ElevatedButton);

      // Tap without entering anything
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      expect(find.text('This field is required'), findsOneWidget);

      // Enter invalid phone
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      expect(find.text('رقم الموبايل غير صحيح'), findsOneWidget);

      // Enter valid phone
      await tester.enterText(find.byType(TextFormField), '01091264053');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('رقم الموبايل غير صحيح'), findsNothing);
    });
  });
}
