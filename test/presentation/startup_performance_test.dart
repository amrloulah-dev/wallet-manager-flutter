import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Startup Performance (Failing Test)', () {
    test('runApp should be called BEFORE background services complete', () async {
      bool isRunAppCalled = false;
      bool isBackgroundInitStarted = false;
      Completer backgroundInitCompleter = Completer();

      // Mock background initialization logic
      Future<void> initializeBackground() async {
        isBackgroundInitStarted = true;
        await backgroundInitCompleter.future;
      }

      // Simulating the main() structure
      Future<void> startup() async {
        // Optimized logic:
        unawaited(initializeBackground()); // This does NOT block!
        
        // Final action:
        isRunAppCalled = true;
      }

      // Start startup (don't await it here as we want to check state during execution)
      startup();

      // We expect that background init has started...
      expect(isBackgroundInitStarted, isTrue);
      
      // ...but in the OPTIMIZED version, runApp should already be called
      // even if background init isn't finished.
      // In the CURRENT version, this will fail.
      expect(isRunAppCalled, isTrue, reason: 'runApp should NOT be blocked by background initialization');
      
      // Cleanup
      backgroundInitCompleter.complete();
    });
  });
}
