import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';

/// Internal data class for background isolate communication
class _HashRequest {
  final String password;
  final Uint8List salt;
  final int iterations;
  final int bits;

  _HashRequest({
    required this.password,
    required this.salt,
    required this.iterations,
    required this.bits,
  });
}

class PasswordHasher {
  static int get _kIterations => kDebugMode ? 10 : 600000;
  static const int _kKeyLength = 32; // 256 bits

  // ===========================
  // Hash Password
  // ===========================
  /// Hashes a password using PBKDF2 with a random salt.
  /// Returns a string in format "salt:hash" (hex encoded).
  static Future<String> hashPassword(String password) async {
    final salt = _generateSalt();
    final hash = await _deriveKeyInBackground(password, salt);

    return '${hex.encode(salt)}:${hex.encode(hash)}';
  }

  static Uint8List _generateSalt() {
    final random = Random.secure();
    final salt = Uint8List(16);
    for (int i = 0; i < salt.length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Executes PBKDF2 in a background isolate to prevent UI thread blocking.
  static Future<Uint8List> _deriveKeyInBackground(
      String password, Uint8List salt) async {
    return compute(
      _deriveKeyStatic,
      _HashRequest(
        password: password,
        salt: salt,
        iterations: _kIterations,
        bits: _kKeyLength * 8,
      ),
    );
  }

  /// Static top-level or static function required for compute()
  static Future<Uint8List> _deriveKeyStatic(_HashRequest request) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: request.iterations,
      bits: request.bits,
    );

    final secretKey = SecretKey(utf8.encode(request.password));
    final secretKeyData = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: request.salt,
    );

    return Uint8List.fromList(await secretKeyData.extractBytes());
  }

  // ===========================
  // Verify Password
  // ===========================
  /// Verifies an input password against a stored "salt:hash" string.
  static Future<bool> verifyPassword(
      String inputPassword, String storedHash) async {
    try {
      final parts = storedHash.split(':');
      if (parts.length != 2) {
        return false;
      }

      final salt = hex.decode(parts[0]);
      final expectedHashHex = parts[1];

      final hash = await _deriveKeyInBackground(
        inputPassword,
        Uint8List.fromList(salt),
      );
      final actualHashHex = hex.encode(hash);

      return _fixedTimeEquals(actualHashHex, expectedHashHex);
    } catch (_) {
      return false;
    }
  }

  /// Constant-time comparison to prevent timing side-channel attacks.
  static bool _fixedTimeEquals(String a, String b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
