import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  // ===========================
  // Hash Password
  // ===========================
  /// Hashes a password using the SHA-256 algorithm.
  ///
  /// Steps:
  /// 1. Convert the password string to a list of bytes using UTF-8 encoding.
  /// 2. Generate a SHA-256 hash from the byte list.
  /// 3. Convert the hash digest to a hexadecimal string representation.
  ///
  /// Returns:
  ///   A 64-character hexadecimal string representing the hashed password.
  static String hashPassword(String password) {
    // 1. Convert the password to bytes.
    final bytes = utf8.encode(password);

    // 2. Generate a SHA-256 hash.
    final digest = sha256.convert(bytes);

    // 3. Convert the hash to a hexadecimal string and return it.
    return digest.toString();
  }

  // ===========================
  // Verify Password
  // ===========================
  /// Verifies an input password against a stored hashed password.
  ///
  /// Steps:
  /// 1. Hash the `inputPassword` using the same `hashPassword` method.
  /// 2. Compare the newly generated hash with the `hashedPassword`.
  ///
  /// Returns:
  ///   `true` if the passwords match, `false` otherwise.
  static bool verifyPassword(String inputPassword, String hashedPassword) {
    // 1. Hash the inputPassword.
    final hashedInput = hashPassword(inputPassword);

    // 2. Compare the result with the stored hashedPassword.
    return hashedInput == hashedPassword;
  }
}
