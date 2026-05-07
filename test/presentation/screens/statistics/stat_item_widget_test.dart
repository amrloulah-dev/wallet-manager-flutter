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
}
