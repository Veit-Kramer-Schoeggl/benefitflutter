import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/domain/auth_tokens.dart';

void main() {
  group('AuthTokens', () {
    late AuthTokens tokens;

    setUp(() {
      tokens = AuthTokens(
        accessToken: 'test-access-token-12345',
        refreshToken: 'test-refresh-token-67890',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    });

    group('isExpired', () {
      test('returns false when token has not expired', () {
        final futureTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(futureTokens.isExpired, isFalse);
      });

      test('returns true when token has expired', () {
        final expiredTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );

        expect(expiredTokens.isExpired, isTrue);
      });

      test('returns true when token expired exactly now', () {
        final nowTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(milliseconds: 1)),
        );

        expect(nowTokens.isExpired, isTrue);
      });
    });

    group('needsRefresh', () {
      test('returns false when token has more than 5 minutes remaining', () {
        final freshTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        );

        expect(freshTokens.needsRefresh, isFalse);
      });

      test('returns true when token has less than 5 minutes remaining', () {
        final almostExpiredTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        );

        expect(almostExpiredTokens.needsRefresh, isTrue);
      });

      test('returns false when token has more than 5 minutes remaining (boundary)', () {
        // Add 1 second buffer to avoid timing issues
        final fiveMinPlusTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(minutes: 5, seconds: 1)),
        );

        // At > 5 minutes, needsRefresh should be false
        expect(fiveMinPlusTokens.needsRefresh, isFalse);
      });

      test('returns true when token is already expired', () {
        final expiredTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );

        expect(expiredTokens.needsRefresh, isTrue);
      });
    });

    group('timeUntilExpiry', () {
      test('returns positive duration for non-expired token', () {
        final futureTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(futureTokens.timeUntilExpiry.inMinutes, greaterThan(55));
      });

      test('returns negative duration for expired token', () {
        final expiredTokens = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(expiredTokens.timeUntilExpiry.isNegative, isTrue);
      });
    });

    group('copyWith', () {
      test('creates copy with same values when no arguments provided', () {
        final copy = tokens.copyWith();

        expect(copy.accessToken, equals(tokens.accessToken));
        expect(copy.refreshToken, equals(tokens.refreshToken));
        expect(copy.expiresAt, equals(tokens.expiresAt));
      });

      test('creates copy with updated accessToken', () {
        final copy = tokens.copyWith(accessToken: 'new-access-token');

        expect(copy.accessToken, equals('new-access-token'));
        expect(copy.refreshToken, equals(tokens.refreshToken));
        expect(copy.expiresAt, equals(tokens.expiresAt));
      });

      test('creates copy with updated refreshToken', () {
        final copy = tokens.copyWith(refreshToken: 'new-refresh-token');

        expect(copy.accessToken, equals(tokens.accessToken));
        expect(copy.refreshToken, equals('new-refresh-token'));
        expect(copy.expiresAt, equals(tokens.expiresAt));
      });

      test('creates copy with updated expiresAt', () {
        final newExpiry = DateTime.now().add(const Duration(days: 1));
        final copy = tokens.copyWith(expiresAt: newExpiry);

        expect(copy.accessToken, equals(tokens.accessToken));
        expect(copy.refreshToken, equals(tokens.refreshToken));
        expect(copy.expiresAt, equals(newExpiry));
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        final json = tokens.toJson();

        expect(json['accessToken'], equals(tokens.accessToken));
        expect(json['refreshToken'], equals(tokens.refreshToken));
        expect(json['expiresAt'], equals(tokens.expiresAt.toIso8601String()));
      });

      test('fromJson creates correct instance', () {
        final expiresAt = DateTime.now().add(const Duration(hours: 2));
        final json = {
          'accessToken': 'json-access-token',
          'refreshToken': 'json-refresh-token',
          'expiresAt': expiresAt.toIso8601String(),
        };

        final fromJson = AuthTokens.fromJson(json);

        expect(fromJson.accessToken, equals('json-access-token'));
        expect(fromJson.refreshToken, equals('json-refresh-token'));
        expect(fromJson.expiresAt, equals(expiresAt));
      });

      test('round-trip serialization preserves data', () {
        final json = tokens.toJson();
        final restored = AuthTokens.fromJson(json);

        expect(restored.accessToken, equals(tokens.accessToken));
        expect(restored.refreshToken, equals(tokens.refreshToken));
        // DateTime precision may differ slightly, compare to millisecond
        expect(
          restored.expiresAt.millisecondsSinceEpoch,
          equals(tokens.expiresAt.millisecondsSinceEpoch),
        );
      });
    });

    group('equality', () {
      test('equal tokens are equal', () {
        final expiresAt = DateTime(2025, 1, 1, 12, 0, 0);
        final tokens1 = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: expiresAt,
        );
        final tokens2 = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: expiresAt,
        );

        expect(tokens1, equals(tokens2));
        expect(tokens1.hashCode, equals(tokens2.hashCode));
      });

      test('different accessToken means not equal', () {
        final expiresAt = DateTime(2025, 1, 1, 12, 0, 0);
        final tokens1 = AuthTokens(
          accessToken: 'access1',
          refreshToken: 'refresh',
          expiresAt: expiresAt,
        );
        final tokens2 = AuthTokens(
          accessToken: 'access2',
          refreshToken: 'refresh',
          expiresAt: expiresAt,
        );

        expect(tokens1, isNot(equals(tokens2)));
      });

      test('different refreshToken means not equal', () {
        final expiresAt = DateTime(2025, 1, 1, 12, 0, 0);
        final tokens1 = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh1',
          expiresAt: expiresAt,
        );
        final tokens2 = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh2',
          expiresAt: expiresAt,
        );

        expect(tokens1, isNot(equals(tokens2)));
      });

      test('different expiresAt means not equal', () {
        final tokens1 = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime(2025, 1, 1, 12, 0, 0),
        );
        final tokens2 = AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime(2025, 1, 1, 13, 0, 0),
        );

        expect(tokens1, isNot(equals(tokens2)));
      });
    });

    test('toString returns readable format', () {
      final stringRepr = tokens.toString();

      expect(stringRepr, contains('AuthTokens'));
      expect(stringRepr, contains('accessToken:'));
      expect(stringRepr, contains('refreshToken:'));
      expect(stringRepr, contains('expiresAt:'));
    });
  });
}
