import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart' as local_auth;
import 'package:benefitflutter/features/security/data/security_preferences.dart';
import 'package:benefitflutter/core/config/security_config.dart';

/// Available biometric authentication types
enum AppBiometricType { fingerprint, faceId, iris, none }

/// Result of a biometric authentication attempt
class BiometricAuthResult {
  final bool success;
  final String? error;
  final bool userCancelled;
  final bool permanentlyLocked;

  const BiometricAuthResult({
    required this.success,
    this.error,
    this.userCancelled = false,
    this.permanentlyLocked = false,
  });

  factory BiometricAuthResult.success() =>
      const BiometricAuthResult(success: true);

  factory BiometricAuthResult.failed(String error) =>
      BiometricAuthResult(success: false, error: error);

  factory BiometricAuthResult.cancelled() =>
      const BiometricAuthResult(success: false, userCancelled: true);

  factory BiometricAuthResult.locked() =>
      const BiometricAuthResult(success: false, permanentlyLocked: true);
}

/// Service for biometric authentication
///
/// Provides a clean wrapper around the local_auth package.
/// Handles device capability checks, authentication prompts,
/// and preference management.
class BiometricService {
  final local_auth.LocalAuthentication _localAuth;
  final SecurityPreferences _preferences;

  BiometricService({
    local_auth.LocalAuthentication? localAuth,
    SecurityPreferences? preferences,
  }) : _localAuth = localAuth ?? local_auth.LocalAuthentication(),
       _preferences = preferences ?? SecurityPreferences();

  // ===== CAPABILITY CHECKS =====

  /// Check if device supports any biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('BiometricService: Error checking device support - $e');
      return false;
    }
  }

  /// Check if biometrics are enrolled on the device
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('BiometricService: Error checking biometrics - $e');
      return false;
    }
  }

  /// Check if biometric authentication is available
  ///
  /// Returns true if device supports biometrics AND user has enrolled biometrics.
  Future<bool> isBiometricAvailable() async {
    if (!SecurityConfig.enableBiometricAuth) return false;

    final isSupported = await isDeviceSupported();
    if (!isSupported) return false;

    final canCheck = await canCheckBiometrics();
    if (!canCheck) return false;

    final biometrics = await getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }

  /// Get list of available biometric types on this device
  Future<List<AppBiometricType>> getAvailableBiometrics() async {
    try {
      final available = await _localAuth.getAvailableBiometrics();
      return available
          .map((type) {
            switch (type) {
              case local_auth.BiometricType.fingerprint:
                return AppBiometricType.fingerprint;
              case local_auth.BiometricType.face:
                return AppBiometricType.faceId;
              case local_auth.BiometricType.iris:
                return AppBiometricType.iris;
              default:
                return AppBiometricType.none;
            }
          })
          .where((type) => type != AppBiometricType.none)
          .toList();
    } catch (e) {
      debugPrint('BiometricService: Error getting available biometrics - $e');
      return [];
    }
  }

  /// Get primary biometric type (for UI display)
  Future<AppBiometricType> getPrimaryBiometricType() async {
    final types = await getAvailableBiometrics();
    if (types.isEmpty) return AppBiometricType.none;

    // Prefer Face ID on iOS, fingerprint on Android
    if (types.contains(AppBiometricType.faceId)) {
      return AppBiometricType.faceId;
    }
    if (types.contains(AppBiometricType.fingerprint)) {
      return AppBiometricType.fingerprint;
    }
    return types.first;
  }

  /// Get human-readable name for biometric type
  String getBiometricName(AppBiometricType type) {
    switch (type) {
      case AppBiometricType.fingerprint:
        return 'Fingerprint';
      case AppBiometricType.faceId:
        return 'Face ID';
      case AppBiometricType.iris:
        return 'Iris';
      case AppBiometricType.none:
        return 'None';
    }
  }

  // ===== AUTHENTICATION =====

  /// Authenticate using biometrics
  ///
  /// Shows system biometric prompt with the given reason.
  /// Returns [BiometricAuthResult] indicating success or failure.
  Future<BiometricAuthResult> authenticate({
    String reason = 'Please authenticate to unlock BeneFit',
  }) async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
      );

      if (didAuthenticate) {
        // Record successful unlock
        await _preferences.recordUnlock();
        return BiometricAuthResult.success();
      } else {
        return BiometricAuthResult.failed('Authentication failed');
      }
    } on PlatformException catch (e) {
      debugPrint(
        'BiometricService: Platform exception - ${e.code}: ${e.message}',
      );

      switch (e.code) {
        case 'NotAvailable':
          return BiometricAuthResult.failed('Biometrics not available');
        case 'NotEnrolled':
          return BiometricAuthResult.failed('No biometrics enrolled');
        case 'LockedOut':
          return BiometricAuthResult.failed(
            'Too many attempts. Try again later.',
          );
        case 'PermanentlyLockedOut':
          return BiometricAuthResult.locked();
        case 'PasscodeNotSet':
          return BiometricAuthResult.failed('Device passcode not set');
        default:
          if (e.message?.contains('cancel') == true ||
              e.code == 'auth_in_progress') {
            return BiometricAuthResult.cancelled();
          }
          return BiometricAuthResult.failed(e.message ?? 'Unknown error');
      }
    } catch (e) {
      debugPrint('BiometricService: Authentication error - $e');
      return BiometricAuthResult.failed('Authentication error');
    }
  }

  // ===== PREFERENCE MANAGEMENT =====

  /// Check if user has enabled biometric authentication
  Future<bool> isBiometricEnabled() async {
    return await _preferences.isBiometricEnabled();
  }

  /// Enable biometric authentication for this user
  Future<bool> enableBiometric() async {
    // Verify biometrics are available
    final available = await isBiometricAvailable();
    if (!available) {
      return false;
    }

    // Authenticate to confirm enrollment
    final result = await authenticate(
      reason: 'Authenticate to enable biometric unlock',
    );

    if (result.success) {
      await _preferences.setBiometricEnabled(true);
      await _preferences.setAppLockEnabled(true);
      return true;
    }

    return false;
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    await _preferences.setBiometricEnabled(false);
  }

  /// Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    return await _preferences.isAppLockEnabled();
  }

  /// Set app lock enabled/disabled
  Future<void> setAppLockEnabled(bool enabled) async {
    await _preferences.setAppLockEnabled(enabled);
    // If disabling app lock, also disable biometric
    if (!enabled) {
      await _preferences.setBiometricEnabled(false);
    }
  }

  /// Get last successful unlock time
  Future<DateTime?> getLastUnlockTime() async {
    return await _preferences.getLastUnlockTime();
  }

  /// Clear all biometric preferences (on logout)
  Future<void> clearPreferences() async {
    await _preferences.clearAll();
  }
}
