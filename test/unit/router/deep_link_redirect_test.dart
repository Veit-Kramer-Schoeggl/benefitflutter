import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/router/app_router.dart';

void main() {
  group('customSchemeRedirect (F5)', () {
    test('benefit://reset-password?token=… → /reset-password?token=…', () {
      expect(
        customSchemeRedirect(Uri.parse('benefit://reset-password?token=ABC')),
        '/reset-password?token=ABC',
      );
    });

    test('reset-password without a token → /reset-password', () {
      expect(
        customSchemeRedirect(Uri.parse('benefit://reset-password')),
        '/reset-password',
      );
    });

    test('empty token is treated as no token', () {
      expect(
        customSchemeRedirect(Uri.parse('benefit://reset-password?token=')),
        '/reset-password',
      );
    });

    test('token with special characters is URL-encoded', () {
      final result = customSchemeRedirect(
        Uri(
          scheme: 'benefit',
          host: 'reset-password',
          queryParameters: {'token': 'a b+c/d=e'},
        ),
      );
      // The mapped location round-trips back to the original token.
      expect(Uri.parse(result!).queryParameters['token'], 'a b+c/d=e');
      expect(result.startsWith('/reset-password?token='), isTrue);
    });

    test('unknown custom-scheme host → /splash fallback', () {
      expect(
        customSchemeRedirect(Uri.parse('benefit://unknown-thing')),
        '/splash',
      );
    });

    test('https links are not intercepted', () {
      expect(
        customSchemeRedirect(Uri.parse('https://benefit4.us/reset-password')),
        isNull,
      );
    });

    test('in-app paths are not intercepted', () {
      expect(customSchemeRedirect(Uri.parse('/reset-password')), isNull);
      expect(customSchemeRedirect(Uri.parse('/home/activity')), isNull);
    });
  });
}
