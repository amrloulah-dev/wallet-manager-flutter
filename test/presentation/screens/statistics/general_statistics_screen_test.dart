import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/presentation/screens/statistics/general_statistics_screen.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockStatsRepository extends Mock implements StatsRepository {}

void main() {
  late MockStatsRepository mockStatsRepo;
  late StatisticsProvider statisticsProvider;

  setUp(() {
    mockStatsRepo = MockStatsRepository();
    when(() => mockStatsRepo.getStatsSummary(any()))
        .thenAnswer((_) async => StatsSummaryModel.empty());
    when(() => mockStatsRepo.fetchTodayStats(any()))
        .thenAnswer((_) async => DailyStatsModel.empty('2026-08-20'));

    statisticsProvider = StatisticsProvider(statsRepository: mockStatsRepo);
    statisticsProvider.setStoreId('test_store');
  });

  tearDown(() {
    statisticsProvider.dispose();
  });

  Widget createTestWidget() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      locale: const Locale('en'),
      home: ChangeNotifierProvider<StatisticsProvider>.value(
        value: statisticsProvider,
        child: const GeneralStatisticsScreen(),
      ),
    );
  }

  testWidgets(
      'GeneralStatisticsScreen reactively updates totalBalance when provider updates in RAM',
      (WidgetTester tester) async {
    // 1. Initial State: totalBalance = 5000.0
    final initialSummary = StatsSummaryModel.empty().copyWith(
      totalBalance: 5000.0,
      totalWallets: 3,
      totalTransactions: 10,
      totalSentAmount: 2000.0,
      totalReceivedAmount: 7000.0,
    );
    final initialToday = DailyStatsModel.empty('2026-08-20');

    when(() => mockStatsRepo.getStatsSummary('test_store'))
        .thenAnswer((_) async => initialSummary);
    when(() => mockStatsRepo.fetchTodayStats('test_store'))
        .thenAnswer((_) async => initialToday);

    await statisticsProvider.fetchDashboardStats(forceRefresh: true);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify initial balance is rendered
    expect(find.text(NumberFormatter.formatAmount(5000.0)), findsOneWidget);

    // 2. Perform optimistic credit transaction (+1500)
    statisticsProvider.addTransactionOptimistically({
      'amount': 1500.0,
      'commission': 30.0,
      'serviceFee': 0.0,
      'type': 'credit',
    });

    await tester.pumpAndSettle();

    // Verify balance is reactively updated to 6,500.00 without page reload
    expect(find.text(NumberFormatter.formatAmount(6500.0)), findsOneWidget);

    // 3. Perform optimistic debit transaction (-2000 with 10 fee = -2010)
    statisticsProvider.addTransactionOptimistically({
      'amount': 2000.0,
      'commission': 20.0,
      'serviceFee': 10.0,
      'type': 'debit',
    });

    await tester.pumpAndSettle();

    // Verify balance is reactively updated to 4,490.00 (6500 - 2010)
    expect(find.text(NumberFormatter.formatAmount(4490.0)), findsOneWidget);

    // Advance time to clear fetch shield timer
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets(
      'GeneralStatisticsScreen pull-to-refresh triggers fetchDashboardStats with forceRefresh',
      (WidgetTester tester) async {
    final initialSummary = StatsSummaryModel.empty().copyWith(
      totalBalance: 1000.0,
    );
    final initialToday = DailyStatsModel.empty('2026-08-20');

    when(() => mockStatsRepo.getStatsSummary('test_store'))
        .thenAnswer((_) async => initialSummary);
    when(() => mockStatsRepo.fetchTodayStats('test_store'))
        .thenAnswer((_) async => initialToday);

    await statisticsProvider.fetchDashboardStats(forceRefresh: true);

    when(() => mockStatsRepo.getStatsSummary('test_store'))
        .thenAnswer((_) async => initialSummary.copyWith(totalBalance: 8888.0));

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(NumberFormatter.formatAmount(1000.0)), findsOneWidget);

    // Pull to refresh
    await tester.fling(
        find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    verify(() => mockStatsRepo.getStatsSummary('test_store')).called(3);
    expect(find.text(NumberFormatter.formatAmount(8888.0)), findsOneWidget);

    // Advance time to clear fetch shield timer
    await tester.pump(const Duration(seconds: 6));
  });
}
