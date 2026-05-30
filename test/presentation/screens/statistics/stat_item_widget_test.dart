import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/presentation/screens/statistics/general_statistics_screen.dart';

void main() {
  testWidgets('StatItemWidget renders label, value and subtitle correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatItemWidget(
            label: 'Test Label',
            value: '100.00',
            subtitle: 'Test Subtitle',
            valueColor: Colors.green,
          ),
        ),
      ),
    );

    expect(find.text('Test Label'), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('Test Subtitle'), findsOneWidget);

    final textWidget = tester.widget<Text>(find.text('100.00'));
    expect(textWidget.style?.color, Colors.green);
  });

  testWidgets(
      'StatItemWidget does not overflow with long label in constrained width',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: StatItemWidget(
              label:
                  'This is an extremely long label that will definitely cause an overflow if not wrapped in Expanded',
              value: '100.00',
              subtitle:
                  'This is also an extremely long subtitle that would overflow',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
