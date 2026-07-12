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
    when(() => mockAuthProvider.tryAutoLogin()).thenAnswer((_) async => true);
    when(() => mockSubscriptionProvider.submitSubscriptionRequest(
          planId: any(named: 'planId'),
          paymentMethod: any(named: 'paymentMethod'),
          receiptNumber: any(named: 'receiptNumber'),
          amount: any(named: 'amount'),
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
    testWidgets('Shows amount and phone number fields', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));

      // Verify the phone number field exists
      expect(find.byKey(const Key('subscription_phone_field')), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsOneWidget);

      // Verify the amount field exists
      expect(
          find.byKey(const Key('subscription_amount_field')), findsOneWidget);
      expect(find.byIcon(Icons.payments), findsOneWidget);
    });

    testWidgets('Validates fields and submits', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final confirmButton = find.byType(ElevatedButton);

      // Tap without entering anything
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Both should show required messages
      expect(find.text('This field is required'), findsOneWidget); // For phone
      expect(find.text('يرجى إدخال المبلغ'), findsOneWidget); // For amount

      // Enter invalid amount and invalid phone
      final amountField = find.byKey(const Key('subscription_amount_field'));
      final phoneField = find.byKey(const Key('subscription_phone_field'));

      await tester.enterText(amountField, '-50');
      await tester.enterText(phoneField, '123');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('المبلغ يجب أن يكون أكبر من 0.0'), findsOneWidget);
      expect(find.text('رقم الموبايل غير صحيح'), findsOneWidget);

      // Enter valid values and submit
      await tester.enterText(amountField, '1200');
      await tester.enterText(phoneField, '01091264053');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('المبلغ يجب أن يكون أكبر من 0.0'), findsNothing);
      expect(find.text('رقم الموبايل غير صحيح'), findsNothing);

      verify(() => mockSubscriptionProvider.submitSubscriptionRequest(
            planId: SubscriptionPlan.proYearly,
            paymentMethod: 'vodafone_cash',
            receiptNumber: '01091264053',
            amount: 1200.0,
          )).called(1);
    });
  });
}
