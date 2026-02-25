import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/domain/account_deletion_result.dart';

void main() {
  group('AccountDeletionResult', () {
    group('success factory', () {
      test('creates successful result', () {
        final result = AccountDeletionResult.success();

        expect(result.success, isTrue);
        expect(result.error, isNull);
      });

      test('isFailure returns false for success', () {
        final result = AccountDeletionResult.success();

        expect(result.isFailure, isFalse);
      });

      test('hasError returns false for success', () {
        final result = AccountDeletionResult.success();

        expect(result.hasError, isFalse);
      });
    });

    group('failure factory', () {
      test('creates failed result with error message', () {
        final result = AccountDeletionResult.failure(
          error: 'Invalid verification code',
        );

        expect(result.success, isFalse);
        expect(result.error, equals('Invalid verification code'));
      });

      test('isFailure returns true for failure', () {
        final result = AccountDeletionResult.failure(
          error: 'Some error',
        );

        expect(result.isFailure, isTrue);
      });

      test('hasError returns true for failure with message', () {
        final result = AccountDeletionResult.failure(
          error: 'Some error',
        );

        expect(result.hasError, isTrue);
      });

      test('hasError returns false for failure with empty message', () {
        final result = AccountDeletionResult.failure(
          error: '',
        );

        expect(result.hasError, isFalse);
      });
    });

    group('toString', () {
      test('success result has descriptive toString', () {
        final result = AccountDeletionResult.success();

        final str = result.toString();

        expect(str, contains('success'));
      });

      test('failure result has descriptive toString', () {
        final result = AccountDeletionResult.failure(
          error: 'Invalid code',
        );

        final str = result.toString();

        expect(str, contains('failure'));
        expect(str, contains('Invalid code'));
      });
    });

    group('edge cases', () {
      test('failure with various error messages', () {
        final errors = [
          'Invalid verification code',
          'Code expired',
          'User already deleted',
          'Network timeout',
          'A very long error message with excessive detail about the failure reason',
        ];

        for (final error in errors) {
          final result = AccountDeletionResult.failure(error: error);

          expect(result.isFailure, isTrue);
          expect(result.error, equals(error));
          expect(result.hasError, isTrue);
        }
      });

      test('success result is const', () {
        final result1 = AccountDeletionResult.success();
        final result2 = AccountDeletionResult.success();

        // Both should be the same const instance
        expect(identical(result1, result2), isTrue);
      });
    });

    group('immutability', () {
      test('properties are final and cannot be modified', () {
        final result = AccountDeletionResult.failure(error: 'test');

        // These are compile-time checks - if the class is mutable,
        // trying to assign to result.success would work
        // This test documents the immutability expectation
        expect(result.success, isFalse);
        expect(result.error, equals('test'));
      });
    });
  });
}
