import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for security-related user preferences
///
/// Stores biometric and app lock preferences using flutter_secure_storage.
/// All preferences are encrypted at rest.
class SecurityPreferences {
  final FlutterSecureStorage _storage;

  // Storage keys
  static const String _biometricEnabledKey = 'security_biometric_enabled';
  static const String _appLockEnabledKey = 'security_app_lock_enabled';
  static const String _biometricEnrolledAtKey =
      'security_biometric_enrolled_at';
  static const String _lastUnlockTimeKey = 'security_last_unlock_time';

  SecurityPreferences({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  // ===== BIOMETRIC PREFERENCES =====

  /// Check if biometric authentication is enabled by user
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());

    // Record enrollment time when enabled
    if (enabled) {
      await _storage.write(
        key: _biometricEnrolledAtKey,
        value: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Get when biometric was enrolled
  Future<DateTime?> getBiometricEnrolledAt() async {
    final value = await _storage.read(key: _biometricEnrolledAtKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  // ===== APP LOCK PREFERENCES =====

  /// Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    final value = await _storage.read(key: _appLockEnabledKey);
    return value == 'true';
  }

  /// Enable or disable app lock
  Future<void> setAppLockEnabled(bool enabled) async {
    await _storage.write(key: _appLockEnabledKey, value: enabled.toString());
  }

  // ===== LAST UNLOCK TIME =====

  /// Get last successful unlock time
  Future<DateTime?> getLastUnlockTime() async {
    final value = await _storage.read(key: _lastUnlockTimeKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Record successful unlock
  Future<void> recordUnlock() async {
    await _storage.write(
      key: _lastUnlockTimeKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  // ===== CLEAR ALL =====

  /// Clear all security preferences (on logout)
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _biometricEnabledKey),
      _storage.delete(key: _appLockEnabledKey),
      _storage.delete(key: _biometricEnrolledAtKey),
      _storage.delete(key: _lastUnlockTimeKey),
    ]);
  }
}
