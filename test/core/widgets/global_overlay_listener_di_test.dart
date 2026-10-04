import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/widgets/global_overlay_listener.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  group('GlobalOverlayListener DI Tests', () {
    late MockLocalStorageService mockStorage;

    setUp(() {
      mockStorage = MockLocalStorageService();
    });

    testWidgets('should use injected LocalStorageService', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalOverlayListener(
            localStorage: mockStorage,
            child: Container(),
          ),
        ),
      );
    });
  });
}
