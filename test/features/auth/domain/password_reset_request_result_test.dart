import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/domain/password_reset_request_result.dart';

void main() {
  group('PasswordResetRequestResult', () {
    group('success factory', () {
      test('creates successful result with email and code', () {
        final result = PasswordResetRequestResult.success(
          email: 'test@example.com',
          resetCode: '123456',
        );

        expect(result.success, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.email, equals('test@example.com'));
        expect(result.resetCode, equals('123456'));
        expect(result.error, isNull);
        expect(result.hasError, isFalse);
      });

      test('creates result with different reset codes', () {
        final result = PasswordResetRequestResult.success(
          email: 'user@domain.com',
          resetCode: '999888',
        );

        expect(result.success, isTrue);
        expect(result.resetCode, equals('999888'));
      });
    });

    group('failure factory', () {
      test('creates failed result with error message', () {
        final result = PasswordResetRequestResult.failure(
          error: 'No account found with this email',
        );

        expect(result.success, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.email, isNull);
        expect(result.resetCode, isNull);
        expect(result.error, equals('No account found with this email'));
        expect(result.hasError, isTrue);
      });

      test('creates failed result with different error', () {
        final result = PasswordResetRequestResult.failure(
          error: 'Too many reset attempts',
        );

        expect(result.isFailure, isTrue);
        expect(result.error, equals('Too many reset attempts'));
      });

      test('hasError returns false for empty error', () {
        final result = PasswordResetRequestResult.failure(error: '');

        expect(result.hasError, isFalse);
      });
    });

    group('equality', () {
      test('equal success results are equal', () {
        final result1 = PasswordResetRequestResult.success(
          email: 'test@example.com',
          resetCode: '123456',
        );
        final result2 = PasswordResetRequestResult.success(
          email: 'test@example.com',
          resetCode: '123456',
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('equal failure results are equal', () {
        final result1 = PasswordResetRequestResult.failure(error: 'Error');
        final result2 = PasswordResetRequestResult.failure(error: 'Error');

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('different emails means not equal', () {
        final result1 = PasswordResetRequestResult.success(
          email: 'test1@example.com',
          resetCode: '123456',
        );
        final result2 = PasswordResetRequestResult.success(
          email: 'test2@example.com',
          resetCode: '123456',
        );

        expect(result1, isNot(equals(result2)));
      });

      test('different reset codes means not equal', () {
        final result1 = PasswordResetRequestResult.success(
          email: 'test@example.com',
          resetCode: '123456',
        );
        final result2 = PasswordResetRequestResult.success(
          email: 'test@example.com',
          resetCode: '654321',
        );

        expect(result1, isNot(equals(result2)));
      });

      test('different errors means not equal', () {
        final result1 = PasswordResetRequestResult.failure(error: 'Error 1');
        final result2 = PasswordResetRequestResult.failure(error: 'Error 2');

        expect(result1, isNot(equals(result2)));
      });

      test('success and failure are not equal', () {
        final success = PasswordResetRequestResult.success(
          email: 'test@example.com',
          resetCode: '123456',
        );
        final failure = PasswordResetRequestResult.failure(error: 'Error');

        expect(success, isNot(equals(failure)));
      });
    });

    group('toString', () {
      test('success toString shows correct format', () {
        final result = PasswordResetRequestResult.success(
          email: 'test@example.com',
          resetCode: '123456',
        );

        final str = result.toString();
        expect(str, contains('success'));
        expect(str, contains('test@example.com'));
        expect(str, contains('123456'));
      });

      test('failure toString shows correct format', () {
        final result = PasswordResetRequestResult.failure(
          error: 'No account found',
        );

        final str = result.toString();
        expect(str, contains('failure'));
        expect(str, contains('No account found'));
      });
    });
  });
}
