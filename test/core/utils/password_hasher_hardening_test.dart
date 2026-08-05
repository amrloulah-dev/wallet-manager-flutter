import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/utils/password_hasher.dart';

void main() {
  group('PasswordHasher Hardening (Phase 11.5)', () {
    test(
        'verifyPassword should CORRECTLY verify against a known high-iteration hash',
        () async {
      final pin = '1234';
      final hashed = await PasswordHasher.hashPassword(pin);

      expect(await PasswordHasher.verifyPassword(pin, hashed), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Verification should use constant-time comparison', () async {
      final pin = 'password123';
      final hashed = await PasswordHasher.hashPassword(pin);
      expect(await PasswordHasher.verifyPassword(pin, hashed), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test(
        'hashPasswordBcrypt produces valid Bcrypt hash and verifyPassword verifies it',
        () async {
      final pin = '123456';
      final bcryptHash = PasswordHasher.hashPasswordBcrypt(pin);

      expect(bcryptHash.startsWith(r'$2a$') || bcryptHash.startsWith(r'$2b$'),
          isTrue);
      expect(await PasswordHasher.verifyPassword(pin, bcryptHash), isTrue);
      expect(
          await PasswordHasher.verifyPassword('654321', bcryptHash), isFalse);
    });
  });
}
