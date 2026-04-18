import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/home/main_dashboard_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/debt_provider.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockWalletProvider extends Mock implements WalletProvider {}
class MockTransactionProvider extends Mock implements TransactionProvider {}
class MockDebtProvider extends Mock implements DebtProvider {}
class MockStatisticsProvider extends Mock implements StatisticsProvider {}
class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

class AuthProviderFake extends Fake implements AuthProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProviderFake());
  });

  group('MainDashboardScreen Dependency Check', () {
    testWidgets('should attempt to read SubscriptionProvider during initialization', (tester) async {
      final mockAuth = MockAuthProvider();
      final mockWallet = MockWalletProvider();
      final mockTxn = MockTransactionProvider();
      final mockDebt = MockDebtProvider();
      final mockStats = MockStatisticsProvider();
      final mockSub = MockSubscriptionProvider();

      when(() => mockAuth.currentStoreId).thenReturn('test_store');
      when(() => mockAuth.currentStore).thenReturn(null);
      
      // Stub the fetch calls
      when(() => mockStats.fetchDashboardStats(forceRefresh: any(named: 'forceRefresh'))).thenAnswer((_) async {});
      when(() => mockWallet.fetchInitialWallets()).thenAnswer((_) async {});
      when(() => mockTxn.fetchInitialTransactions(forceRefresh: any(named: 'forceRefresh'))).thenAnswer((_) async {});
      when(() => mockDebt.fetchInitialDebts(forceRefresh: any(named: 'forceRefresh'))).thenAnswer((_) async {});
      
      // Minimal stubs for initialization (if they are called in initState/microtask)
      when(() => mockStats.setStoreId(any())).thenReturn(null);
      when(() => mockWallet.setStoreId(any())).thenReturn(null);
      when(() => mockTxn.updateAuthState(any())).thenReturn(null);
      when(() => mockDebt.setStoreId(any())).thenReturn(null);

      // Provider isLoading stubs to avoid _TypeError: type 'Null' is not a subtype of type 'bool'
      when(() => mockStats.isLoading).thenReturn(false);
      when(() => mockWallet.isLoading).thenReturn(false);
      when(() => mockTxn.isLoading).thenReturn(false);
      when(() => mockDebt.isLoading).thenReturn(false);

      // List and Map stubs to avoid _TypeError
      when(() => mockWallet.wallets).thenReturn([]);
      when(() => mockTxn.transactions).thenReturn([]);
      when(() => mockDebt.summary).thenReturn({});

      // Subscription stubs
      when(() => mockSub.hasSeenSuccessModal).thenReturn(true);
      when(() => mockSub.addListener(any())).thenReturn(null);
      when(() => mockSub.removeListener(any())).thenReturn(null);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<WalletProvider>.value(value: mockWallet),
            ChangeNotifierProvider<TransactionProvider>.value(value: mockTxn),
            ChangeNotifierProvider<DebtProvider>.value(value: mockDebt),
            ChangeNotifierProvider<StatisticsProvider>.value(value: mockStats),
            ChangeNotifierProvider<SubscriptionProvider>.value(value: mockSub),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MainDashboardScreen(),
          ),
        ),
      );

      // Trigger the microtask (_checkPaymentSuccessModal runs here)
      await tester.pump();
      
      expect(find.byType(MainDashboardScreen), findsOneWidget);
    });
  });
}
