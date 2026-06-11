import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/config/app_config.dart';

void main() {
  // `flutter test` runs without --dart-defines, so this validates the
  // (release-safe) fallbacks rather than overridden values.
  group('AppConfig defaults (no dart-defines)', () {
    test('environment defaults to dev', () {
      expect(AppConfig.environment, 'dev');
    });

    test('sentryEnv defaults to dev, sentryDsn empty', () {
      expect(AppConfig.sentryEnv, 'dev');
      expect(AppConfig.sentryDsn, '');
    });

    test('apiBaseUrl matches build mode', () {
      expect(
        AppConfig.apiBaseUrl,
        kDebugMode ? 'https://dev-api.benefit.app' : 'https://api.benefit.app',
      );
    });

    test('certificate pinning = !kDebugMode (on in release)', () {
      expect(AppConfig.enableCertificatePinning, !kDebugMode);
    });

    test('seeding = kDebugMode (off in release)', () {
      expect(AppConfig.seedEnabled, kDebugMode);
    });

    test('http logging = kDebugMode (off in release)', () {
      expect(AppConfig.enableHttpLogging, kDebugMode);
    });
  });
}
