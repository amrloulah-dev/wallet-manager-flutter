// T053-T054: Notification Batching Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/providers/auth_provider.dart';

void main() {
  group('T053-T054 Notification Batching', () {
    // ── AuthProvider disposal safety ──────────────────────────────────────────

    group('AuthProvider._safeNotify disposal guard', () {
      test('_safeNotify does not fire after dispose()', () async {
        final authProvider = AuthProvider();
        
        int callCount = 0;
        authProvider.addListener(() {
          callCount++;
        });

        // Normally we can't call _safeNotify directly as it's private,
        // but we know that calling a public method like `updateUser`
        // post-dispose would trigger it if it wasn't guarded.
        // Or we can just inspect that the contract holds.
        authProvider.dispose();
        
        // This will attempt to notifyListeners internally.
        // It shouldn't crash with a FlutterError because we added _isDisposed checks.
        expect(() => authProvider.logout(), returnsNormally);
        
        expect(callCount, 0, reason: 'Must not emit notification after dispose');
      });
    });
  });
}
