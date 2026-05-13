import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';

class PasswordHasher {
  static const int _kIterations = 1000;
  static const int _kKeyLength = 32; // 256 bits

  // ===========================
  // Hash Password
  // ===========================
  /// Hashes a password using PBKDF2 with a random salt.
  /// Returns a string in format "salt:hash" (hex encoded).
  static Future<String> hashPassword(String password) async {
    final salt = _generateSalt();
    final hash = await _deriveKey(password, salt);
    
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

  static Future<Uint8List> _deriveKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kIterations,
      bits: _kKeyLength * 8,
    );
    
    final secretKey = SecretKey(utf8.encode(password));
    final secretKeyData = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    
    return Uint8List.fromList(await secretKeyData.extractBytes());
  }

  // ===========================
  // Verify Password
  // ===========================
  /// Verifies an input password against a stored "salt:hash" string.
  static Future<bool> verifyPassword(String inputPassword, String storedHash) async {
    try {
      final parts = storedHash.split(':');
      if (parts.length != 2) {
        // Fallback for legacy unsalted hashes if needed, but spec says remove them.
        // For now, let's strictly enforce the new format.
        return false;
      }
      
      final salt = hex.decode(parts[0]);
      final expectedHash = parts[1];
      
      final hash = await _deriveKey(inputPassword, Uint8List.fromList(salt));
      final actualHash = hex.encode(hash);
      
      return actualHash == expectedHash;
    } catch (_) {
      return false;
    }
  }
}


