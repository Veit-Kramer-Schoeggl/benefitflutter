import 'package:benefitflutter/core/config/app_config.dart';

/// Security configuration for the BeneFit app
///
/// Centralizes all security-related settings including:
/// - API endpoints (environment-based)
/// - Rate limiting parameters
/// - Biometric authentication settings
/// - Certificate pinning toggles
///
/// See AUTH.md for the full authentication architecture.
class SecurityConfig {
  // ===== Environment-Based API Configuration =====

  /// API base URL based on build mode
  ///
  /// Production builds use the live API.
  /// Debug builds use the development API.
  static String get apiBaseUrl => AppConfig.apiBaseUrl;

  // ===== Rate Limiting Configuration =====

  /// Maximum login attempts before lockout
  ///
  /// After this many failed attempts, the user must wait
  /// for the lockout duration before trying again.
  ///
  /// Default: 5 attempts
  static const int maxLoginAttempts = 5;

  /// Lockout duration after max attempts exceeded
  ///
  /// User cannot attempt login during this period.
  /// Persists across app restarts.
  ///
  /// Default: 15 minutes
  static const Duration lockoutDuration = Duration(minutes: 15);

  /// Rolling window for counting login attempts
  ///
  /// Attempts older than this are not counted.
  /// Prevents permanent lockout from old failed attempts.
  ///
  /// Default: 15 minutes (same as lockout)
  static const Duration attemptWindowDuration = Duration(minutes: 15);

  // ===== Biometric Authentication Configuration =====

  /// Whether biometric authentication is enabled system-wide
  ///
  /// User can still disable in settings even if this is true.
  /// Set to false to completely disable biometric features.
  static const bool enableBiometricAuth = true;

  /// Delay before requiring biometric after app background
  ///
  /// App must be backgrounded longer than this duration
  /// before biometric authentication is required on resume.
  ///
  /// Default: 2 minutes
  static const Duration biometricLockDelay = Duration(minutes: 2);

  /// Maximum failed biometric attempts before password required
  ///
  /// After this many failed biometric attempts,
  /// user must re-login with password.
  ///
  /// Default: 3 attempts
  static const int maxBiometricAttempts = 3;

  // ===== Certificate Pinning Configuration =====

  /// Whether to enable certificate pinning
  ///
  /// Disabled in debug mode for easier development/testing.
  /// Always enabled in release builds for security.
  static bool get enableCertificatePinning =>
      AppConfig.enableCertificatePinning;

  // ===== Session Timeout Configuration (TODO) =====

  /// Session inactivity timeout
  ///
  /// TODO: Implement for non-tracking sessions only
  /// Auto-logout after this period of inactivity.
  /// SKIP timeout when user is actively tracking an activity.
  ///
  /// Default: 30 minutes
  static const Duration sessionTimeout = Duration(minutes: 30);

  /// Warning before session timeout
  ///
  /// Show warning dialog this long before timeout.
  /// Allows user to extend session.
  ///
  /// Default: 5 minutes
  static const Duration sessionTimeoutWarning = Duration(minutes: 5);

  // ===== Feature Flags =====

  /// Check if rate limiting is enabled
  static const bool enableRateLimiting = true;

  /// Check if all security features are enabled (for testing)
  static bool get allSecurityFeaturesEnabled =>
      enableRateLimiting && enableBiometricAuth && enableCertificatePinning;
}
