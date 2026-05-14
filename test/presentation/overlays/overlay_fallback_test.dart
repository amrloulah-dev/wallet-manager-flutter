import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/main.dart';
import 'package:flutter/services.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final sl = GetIt.instance;
    final mockStorage = MockLocalStorageService();
    when(() => mockStorage.userId).thenReturn(null);
    when(() => mockStorage.storeId).thenReturn(null);
    when(() => mockStorage.languageCode).thenReturn('ar');
    sl.registerSingleton<LocalStorageService>(mockStorage);
  });

  group('OverlayErrorApp', () {
    testWidgets('should render correctly with Arabic error text',
        (tester) async {
      await tester.pumpWidget(const OverlayErrorApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);
    });

    testWidgets('close button should trigger FlutterOverlayWindow.closeOverlay',
        (tester) async {
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
