import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/auth/login_landing_screen.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    mockAuth = MockAuthProvider();
    when(() => mockAuth.isLoading).thenReturn(false);
    when(() => mockAuth.status).thenReturn(AuthStatus.idle);
    when(() => mockAuth.errorMessage).thenReturn(null);
    when(() => mockAuth.addListener(any())).thenReturn(null);
    when(() => mockAuth.removeListener(any())).thenReturn(null);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginLandingScreen(),
      ),
    );
  }

  group('LoginLandingScreen Forgot Password UI', () {
    testWidgets('should show Forgot Password button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      // The button text is l10n.forgotPassword.
      // We expect it to be present.
      expect(find.byType(TextButton), findsWidgets);
      // More specific check depends on the actual text in l10n
    });

    testWidgets('should open BottomSheet when Forgot Password is tapped',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final forgotPasswordButton = find
          .byWidgetPredicate(
              (widget) => widget is TextButton && widget.child is Text)
          .first;

      await tester.tap(forgotPasswordButton);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('BottomSheet should have email input and Send button',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final forgotPasswordButton = find
          .byWidgetPredicate(
              (widget) => widget is TextButton && widget.child is Text)
          .first;

      await tester.tap(forgotPasswordButton);
      await tester.pumpAndSettle();

      // Find TextField inside BottomSheet
      expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          ),
          findsOneWidget);

      // Find CustomButton inside BottomSheet (the 'Send' button)
      expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(CustomButton),
          ),
          findsOneWidget);
    });
  });
}
