import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/domain/auth_result.dart';
import 'package:benefitflutter/features/auth/domain/auth_tokens.dart';

void main() {
  group('AuthResult', () {
    late AuthTokens validTokens;

    setUp(() {
      validTokens = AuthTokens(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    });

    group('success factory', () {
      test('creates successful result with tokens and userId', () {
        final result = AuthResult.success(
          tokens: validTokens,
          userId: 'user-123',
        );

        expect(result.success, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.tokens, equals(validTokens));
        expect(result.userId, equals('user-123'));
        expect(result.error, isNull);
        expect(result.hasError, isFalse);
      });

      test('toString shows success format', () {
        final result = AuthResult.success(
          tokens: validTokens,
          userId: 'user-123',
        );

        expect(result.toString(), contains('success'));
        expect(result.toString(), contains('user-123'));
      });
    });

    group('failure factory', () {
      test('creates failed result with error message', () {
        final result = AuthResult.failure(error: 'Invalid credentials');

        expect(result.success, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.tokens, isNull);
        expect(result.userId, isNull);
        expect(result.error, equals('Invalid credentials'));
        expect(result.hasError, isTrue);
      });

      test('creates failed result with empty error', () {
        final result = AuthResult.failure(error: '');

        expect(result.success, isFalse);
        expect(result.error, equals(''));
        expect(result.hasError, isFalse);
      });

      test('toString shows failure format', () {
        final result = AuthResult.failure(error: 'Network error');

        expect(result.toString(), contains('failure'));
        expect(result.toString(), contains('Network error'));
      });
    });

    group('isFailure', () {
      test('returns false for success result', () {
        final result = AuthResult.success(
          tokens: validTokens,
          userId: 'user-123',
        );

        expect(result.isFailure, isFalse);
      });

      test('returns true for failure result', () {
        final result = AuthResult.failure(error: 'Error');

        expect(result.isFailure, isTrue);
      });
    });

    group('hasError', () {
      test('returns false for success result', () {
        final result = AuthResult.success(
          tokens: validTokens,
          userId: 'user-123',
        );

        expect(result.hasError, isFalse);
      });

      test('returns true for failure with error message', () {
        final result = AuthResult.failure(error: 'Some error');

        expect(result.hasError, isTrue);
      });

      test('returns false for failure with empty error', () {
        final result = AuthResult.failure(error: '');

        expect(result.hasError, isFalse);
      });
    });

    group('equality', () {
      test('equal success results are equal', () {
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

        final result1 = AuthResult.success(tokens: tokens1, userId: 'user-1');
        final result2 = AuthResult.success(tokens: tokens2, userId: 'user-1');

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('equal failure results are equal', () {
        final result1 = AuthResult.failure(error: 'Error message');
        final result2 = AuthResult.failure(error: 'Error message');

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('success and failure are not equal', () {
        final success = AuthResult.success(
          tokens: validTokens,
          userId: 'user-1',
        );
        final failure = AuthResult.failure(error: 'Error');

        expect(success, isNot(equals(failure)));
      });

      test('different userIds means not equal', () {
        final result1 = AuthResult.success(
          tokens: validTokens,
          userId: 'user-1',
        );
        final result2 = AuthResult.success(
          tokens: validTokens,
          userId: 'user-2',
        );

        expect(result1, isNot(equals(result2)));
      });

      test('different errors means not equal', () {
        final result1 = AuthResult.failure(error: 'Error 1');
        final result2 = AuthResult.failure(error: 'Error 2');

        expect(result1, isNot(equals(result2)));
      });
    });
  });
}
