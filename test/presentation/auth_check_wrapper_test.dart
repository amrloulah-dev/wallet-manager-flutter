import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/app.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/routes/navigation_service.dart';

class MockAuthProvider extends Mock implements AuthProvider {
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void triggerNotify() {
    for (final listener in List.from(_listeners)) {
      listener();
    }
  }
}

void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    mockAuth = MockAuthProvider();
    // Default mocks for non-null/standard fields used in build/init
    when(() => mockAuth.status).thenReturn(AuthStatus.idle);
    when(() => mockAuth.isAuthenticated).thenReturn(false);
    when(() => mockAuth.isSubscriptionExpired).thenReturn(false);
    when(() => mockAuth.isLoading).thenReturn(false);
    when(() => mockAuth.currentStore).thenReturn(null);
    when(() => mockAuth.currentUser).thenReturn(null);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
      ],
      child: MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return child!;
        },
        routes: {
          RouteConstants.mainDashboard: (context) => const Scaffold(
                body: Text('Dashboard Screen'),
              ),
          RouteConstants.loginLanding: (context) => const AuthCheckWrapper(),
        },
        home: const AuthCheckWrapper(),
      ),
    );
  }

  group('AuthCheckWrapper Navigation Flow Tests', () {
    testWidgets(
        'should show login landing initially and navigate to dashboard on login',
        (tester) async {
      // 1. Initial State: Unauthenticated
      when(() => mockAuth.status).thenReturn(AuthStatus.unauthenticated);
      when(() => mockAuth.isAuthenticated).thenReturn(false);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Expect to see the login/landing screen (rendered by AuthCheckWrapper)
      expect(find.byType(AuthCheckWrapper), findsOneWidget);

      // 2. User Logs In
      when(() => mockAuth.status).thenReturn(AuthStatus.authenticated);
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      final mockUser = UserModel(
        userId: 'u1',
        storeId: 's1',
        role: UserRole.owner,
        fullName: 'Test Owner',
      );
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      // Trigger builder rebuild
      mockAuth.triggerNotify();
      await tester.pump(); // Allow post-frame callback to trigger navigation
      await tester.pumpAndSettle();

      // Check if we navigated to the dashboard
      expect(find.text('Dashboard Screen'), findsOneWidget);
    });
  });
}
