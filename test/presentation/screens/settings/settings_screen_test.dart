import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/sim_wallet_config.dart';
import 'package:collection/collection.dart';

void main() {
  group('SIM Mapping Logic (Standalone)', () {
    test('firstWhere throws StateError when not found (Current behavior)', () {
      final mappings = <SimWalletConfig>[];
      expect(
        () => mappings.firstWhere((m) => m.simSlotIndex == 0),
        throwsA(isA<StateError>()),
      );
    });

    test('firstOrNull returns null when not found (Proposed behavior)', () {
      final mappings = <SimWalletConfig>[];
      final sim1 = mappings.where((m) => m.simSlotIndex == 0).firstOrNull;
      expect(sim1, isNull);
    });
  });
}
