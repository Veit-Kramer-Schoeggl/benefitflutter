import 'package:flutter/foundation.dart';

/// Centralized, deploy-time configuration.
///
/// Values come from `--dart-define`(`-from-file`) at build time and const-fold
/// (so release tree-shaking is preserved). Each falls back to a `kDebugMode`-based
/// default when its flag is absent — and those defaults are **release-safe**:
/// a forgotten flag in a release build resolves to the secure choice
/// (certificate pinning ON, seeding OFF, HTTP logging OFF).
///
/// Usage: `flutter run --dart-define-from-file=config/dev.json`
class AppConfig {
  AppConfig._();

  /// Environment label (e.g. dev/staging/prod).
  static String get environment =>
      const String.fromEnvironment('ENV', defaultValue: 'dev');

  /// API base URL. Falls back to dev (debug) / prod (release) when unset.
  static String get apiBaseUrl {
    const value = String.fromEnvironment('API_BASE_URL');
    if (value.isNotEmpty) return value;
    return kDebugMode
        ? 'https://dev-api.benefit.app'
        : 'https://api.benefit.app';
  }

  /// Certificate pinning. Default: enabled in release, disabled in debug.
  static bool get enableCertificatePinning =>
      const bool.hasEnvironment('CERT_PINNING')
      ? const bool.fromEnvironment('CERT_PINNING')
      : !kDebugMode;

  /// Database seeding. Default: enabled in debug, disabled in release.
  static bool get seedEnabled => const bool.hasEnvironment('SEED_ENABLED')
      ? const bool.fromEnvironment('SEED_ENABLED')
      : kDebugMode;

  /// HTTP request/response logging. Default: enabled in debug only.
  static bool get enableHttpLogging => const bool.hasEnvironment('HTTP_LOGGING')
      ? const bool.fromEnvironment('HTTP_LOGGING')
      : kDebugMode;

  /// Sentry DSN (empty = crash reporting disabled).
  static String get sentryDsn => const String.fromEnvironment('SENTRY_DSN');

  /// Sentry environment tag.
  static String get sentryEnv =>
      const String.fromEnvironment('SENTRY_ENV', defaultValue: 'dev');
}
