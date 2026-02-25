import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility class for password hashing and verification.
/// Uses SHA-256 hashing for secure password storage.
class PasswordUtils {
  /// Hashes a password using SHA-256.
  /// Returns the hex string representation of the hash.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies a password against a stored hash.
  /// Returns true if the password matches the hash.
  static bool verifyPassword(String password, String storedHash) {
    final hash = hashPassword(password);
    return hash == storedHash;
  }
}
