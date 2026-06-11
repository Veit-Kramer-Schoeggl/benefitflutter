import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/domain/password_reset_result.dart';

void main() {
  group('PasswordResetResult', () {
    group('success factory', () {
      test('creates successful result', () {
        final result = PasswordResetResult.success();

        expect(result.success, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.error, isNull);
        expect(result.hasError, isFalse);
      });

      test('multiple success results are equal', () {
        final result1 = PasswordResetResult.success();
        final result2 = PasswordResetResult.success();

        expect(result1, equals(result2));
      });
    });

    group('failure factory', () {
      test('creates failed result with error message', () {
        final result = PasswordResetResult.failure(error: 'Invalid reset code');

        expect(result.success, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.error, equals('Invalid reset code'));
        expect(result.hasError, isTrue);
      });

      test('creates failed result with different error', () {
        final result = PasswordResetResult.failure(
          error: 'Reset code has expired',
        );

        expect(result.isFailure, isTrue);
        expect(result.error, equals('Reset code has expired'));
      });

      test('hasError returns false for empty error', () {
        final result = PasswordResetResult.failure(error: '');

        expect(result.hasError, isFalse);
      });
    });

    group('equality', () {
      test('equal success results are equal', () {
        final result1 = PasswordResetResult.success();
        final result2 = PasswordResetResult.success();

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('equal failure results are equal', () {
        final result1 = PasswordResetResult.failure(error: 'Error');
        final result2 = PasswordResetResult.failure(error: 'Error');

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('different errors means not equal', () {
        final result1 = PasswordResetResult.failure(error: 'Error 1');
        final result2 = PasswordResetResult.failure(error: 'Error 2');

        expect(result1, isNot(equals(result2)));
      });

      test('success and failure are not equal', () {
        final success = PasswordResetResult.success();
        final failure = PasswordResetResult.failure(error: 'Error');

        expect(success, isNot(equals(failure)));
      });
    });

    group('toString', () {
      test('success toString shows correct format', () {
        final result = PasswordResetResult.success();

        final str = result.toString();
        expect(str, contains('success'));
      });

      test('failure toString shows correct format', () {
        final result = PasswordResetResult.failure(error: 'Invalid reset code');

        final str = result.toString();
        expect(str, contains('failure'));
        expect(str, contains('Invalid reset code'));
      });
    });
  });
}
