import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/main.dart';
import 'package:walletmanager/presentation/screens/subscription/payment_modal_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionProvider mockSubscriptionProvider;
  late MockLocalStorageService mockLocalStorageService;

  setUpAll(() {
    registerFallbackValue(SubscriptionPlan.lifetime);
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockSubscriptionProvider = MockSubscriptionProvider();
    mockLocalStorageService = MockLocalStorageService();

    // Setup GetIt container if not registered
    if (!sl.isRegistered<LocalStorageService>()) {
      sl.registerSingleton<LocalStorageService>(mockLocalStorageService);
    }
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
      'OverlayErrorApp displays localized Arabic error message by default',
      (WidgetTester tester) async {
    when(() => mockLocalStorageService.languageCode).thenReturn('ar');

    await tester.pumpWidget(const OverlayErrorApp());
    await tester.pumpAndSettle();

    // Verify Arabic strings are rendered
    expect(find.text('❌ خطأ في الاتصال'), findsOneWidget);
    expect(
        find.text('يرجى إتمام المعاملة من التطبيق الأساسي.'), findsOneWidget);
  });

  testWidgets('OverlayErrorApp displays localized English error message',
      (WidgetTester tester) async {
    when(() => mockLocalStorageService.languageCode).thenReturn('en');

    await tester.pumpWidget(const OverlayErrorApp());
    await tester.pumpAndSettle();

    // Verify English strings are rendered
    expect(find.text('❌ Connection Error'), findsOneWidget);
    expect(find.text('Please complete the transaction from the main app.'),
        findsOneWidget);
  });

  testWidgets('PaymentModalScreen renders localized EGP amount label',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SubscriptionProvider>.value(
              value: mockSubscriptionProvider),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ar'),
          home: Scaffold(
            body: PaymentModalScreen(planId: SubscriptionPlan.lifetime),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Confirm localized Paid Amount is rendered
    expect(find.text('المبلغ المدفوع (جنيه)'), findsOneWidget);
  });
}
