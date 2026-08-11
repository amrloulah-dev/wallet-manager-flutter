import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/widgets/debt/debt_card.dart';

import 'package:walletmanager/core/enums/debt_enums.dart';

void main() {
  final testDebt = DebtModel(
    debtId: 'debt_123',
    storeId: 'store_456',
    customerName: 'أحمد علي',
    customerPhone: '01012345678',
    amountDue: 500.0,
    totalAmount: 500.0,
    debtType: DebtType.storeSale,
    debtStatus: DebtStatus.open,
    createdBy: 'user_1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget createWidgetUnderTest({
    VoidCallback? onTap,
    VoidCallback? onMarkPaid,
    VoidCallback? onPartialPayment,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: Scaffold(
        body: DebtCard(
          debt: testDebt,
          onTap: onTap,
          onMarkPaid: onMarkPaid,
          onPartialPayment: onPartialPayment,
        ),
      ),
    );
  }

  group('DebtCard Widget Tests', () {
    testWidgets('renders both full settlement and partial payment buttons side-by-side',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        onMarkPaid: () {},
        onPartialPayment: () {},
      ));
      await tester.pumpAndSettle();

      final fullSettlementFinder = find.text('تسديد كامل');
      final partialPaymentFinder = find.text('دفع جزئي');

      expect(fullSettlementFinder, findsOneWidget);
      expect(partialPaymentFinder, findsOneWidget);

      // Verify buttons are inside Expanded widgets within a Row
      final rowFinder = find.ancestor(
        of: fullSettlementFinder,
        matching: find.byType(Row),
      );
      expect(rowFinder, findsWidgets);
    });

    testWidgets('neutralizes card body tap gesture', (tester) async {
      bool cardTapped = false;
      bool partialPaymentTapped = false;

      await tester.pumpWidget(createWidgetUnderTest(
        onTap: () {
          cardTapped = true;
        },
        onPartialPayment: () {
          partialPaymentTapped = true;
        },
      ));
      await tester.pumpAndSettle();

      // Tap customer name area (card body)
      await tester.tap(find.text('أحمد علي'));
      await tester.pumpAndSettle();

      // Card tap should NOT trigger
      expect(cardTapped, isFalse);

      // Tap partial payment button explicitly
      await tester.tap(find.text('دفع جزئي'));
      await tester.pumpAndSettle();

      // Partial payment callback should trigger
      expect(partialPaymentTapped, isTrue);
    });

    testWidgets('triggers onMarkPaid when full settlement button is clicked',
        (tester) async {
      bool markPaidTapped = false;

      await tester.pumpWidget(createWidgetUnderTest(
        onMarkPaid: () {
          markPaidTapped = true;
        },
        onPartialPayment: () {},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تسديد كامل'));
      await tester.pumpAndSettle();

      expect(markPaidTapped, isTrue);
    });
  });
}
