import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';

void main() {
  group('PasswordHasher Security Upgrade (Phase 11)', () {
    test('hashPassword should return a salted hash in salt:hash format', () async {
      final pin = '1234';
      final hashed = await PasswordHasher.hashPassword(pin);
      
      expect(hashed, contains(':'), reason: 'Hash should contain a delimiter for the salt');
      final parts = hashed.split(':');
      expect(parts.length, 2);
      expect(parts[0].length, greaterThan(10), reason: 'Salt should be sufficiently long');
      expect(parts[1].length, greaterThan(10), reason: 'Hash should be sufficiently long');
    });

    test('hashPassword should produce different hashes for the same input (Unique Salt)', () async {
      final pin = '1234';
      final hashed1 = await PasswordHasher.hashPassword(pin);
      final hashed2 = await PasswordHasher.hashPassword(pin);
      
      expect(hashed1, isNot(hashed2), reason: 'Each hash should have a unique random salt');
    });

    test('verifyPassword should correctly verify a salted hash', () async {
      final pin = '1234';
      final hashed = await PasswordHasher.hashPassword(pin);
      
      expect(await PasswordHasher.verifyPassword(pin, hashed), isTrue);
      expect(await PasswordHasher.verifyPassword('5678', hashed), isFalse);
    });

    test('hashPassword should NOT be a plain SHA-256 of the input', () async {
      // This is what the old implementation did
      // final oldHashed = sha256.convert(utf8.encode('1234')).toString();
      const oldHashed = '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4';
      
      final newHashed = await PasswordHasher.hashPassword('1234');
      expect(newHashed, isNot(contains(oldHashed)));
    });
  });
}
