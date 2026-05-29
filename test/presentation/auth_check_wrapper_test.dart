import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/app.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/models/user_model.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    mockAuth = MockAuthProvider();
    // Default mocks for non-null/standard fields used in build/init
    when(() => mockAuth.status).thenReturn(AuthStatus.idle);
    when(() => mockAuth.isAuthenticated).thenReturn(false);
    when(() => mockAuth.isSubscriptionExpired).thenReturn(false);
    when(() => mockAuth.currentStore).thenReturn(null);
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockAuth.addListener(any())).thenReturn(null);
    when(() => mockAuth.removeListener(any())).thenReturn(null);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
      ],
      child: MaterialApp(
        routes: {
          RouteConstants.ownerDashboard: (context) => const Scaffold(
                body: Text('Dashboard Screen'),
              ),
          RouteConstants.loginLanding: (context) => const Scaffold(
                body: Text('Login Screen'),
              ),
        },
        home: const AuthCheckWrapper(),
      ),
    );
  }

  group('AuthCheckWrapper Navigation Flow Tests', () {
    testWidgets(
        'should allow navigating to dashboard, logging out, and logging back in without getting stuck',
        (tester) async {
      // 1. Initial State: Unauthenticated
      when(() => mockAuth.status).thenReturn(AuthStatus.unauthenticated);
      when(() => mockAuth.isAuthenticated).thenReturn(false);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Expect to see the login/landing screen (in our mockup home starts there)
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
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Allow post-frame callback to trigger navigation
      await tester.pumpAndSettle();

      // Check if we navigated to the dashboard
      expect(find.text('Dashboard Screen'), findsOneWidget);

      // 3. User Logs Out
      when(() => mockAuth.status).thenReturn(AuthStatus.unauthenticated);
      when(() => mockAuth.isAuthenticated).thenReturn(false);
      when(() => mockAuth.currentUser).thenReturn(null);

      // Pump to trigger rebuild with the new state
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 4. User Logs In Again
      when(() => mockAuth.status).thenReturn(AuthStatus.authenticated);
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Allow post-frame callback
      await tester.pumpAndSettle();

      // In the buggy implementation, it will NOT navigate to the dashboard again because _isNavigating is stuck at true.
      // We expect it to navigate successfully to 'Dashboard Screen'.
      expect(find.text('Dashboard Screen'), findsOneWidget);
    });
  });
}
