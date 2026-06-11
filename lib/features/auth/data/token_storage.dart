import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/auth_tokens.dart';

/// Secure storage for authentication tokens
///
/// Uses flutter_secure_storage for encrypted storage on device.
/// Abstracts storage details for easier testing and potential migration.
abstract class TokenStorage {
  /// Save tokens to secure storage
  Future<void> saveTokens(AuthTokens tokens);

  /// Retrieve stored tokens (null if not stored or invalid)
  Future<AuthTokens?> getTokens();

  /// Clear all stored tokens
  Future<void> clearTokens();

  /// Check if tokens are stored
  Future<bool> hasTokens();

  /// Get just the access token (for API calls)
  Future<String?> getAccessToken();
}

/// Implementation using flutter_secure_storage
class SecureTokenStorage implements TokenStorage {
  final FlutterSecureStorage _storage;

  // Storage keys
  static const String _tokensKey = 'auth_tokens';

  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    final json = jsonEncode(tokens.toJson());
    await _storage.write(key: _tokensKey, value: json);
  }

  @override
  Future<AuthTokens?> getTokens() async {
    try {
      final json = await _storage.read(key: _tokensKey);
      if (json == null || json.isEmpty) {
        return null;
      }
      final map = jsonDecode(json) as Map<String, dynamic>;
      return AuthTokens.fromJson(map);
    } catch (e) {
      // Invalid JSON or corrupted data - clear it
      await clearTokens();
      return null;
    }
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _tokensKey);
  }

  @override
  Future<bool> hasTokens() async {
    final json = await _storage.read(key: _tokensKey);
    return json != null && json.isNotEmpty;
  }

  @override
  Future<String?> getAccessToken() async {
    final tokens = await getTokens();
    return tokens?.accessToken;
  }
}
