import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/main.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OverlayErrorApp', () {
    testWidgets('should render correctly with Arabic error text', (tester) async {
      await tester.pumpWidget(const OverlayErrorApp());

      expect(find.text('❌ خطأ في الاتصال'), findsOneWidget);
      expect(find.text('يرجى إتمام المعاملة من التطبيق الأساسي.'), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('close button should trigger FlutterOverlayWindow.closeOverlay', (tester) async {
      int closeOverlayCount = 0;
      const channel = MethodChannel('x-slayer/overlay_channel');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'closeOverlay') {
          closeOverlayCount++;
          return true;
        }
        return null;
      });

      await tester.pumpWidget(const OverlayErrorApp());

      await tester.tap(find.text('إغلاق'));
      await tester.pump();

      expect(closeOverlayCount, 1);
    });
  });
}
