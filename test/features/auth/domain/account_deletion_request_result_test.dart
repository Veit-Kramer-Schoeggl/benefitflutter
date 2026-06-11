import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/domain/account_deletion_request_result.dart';

void main() {
  group('AccountDeletionRequestResult', () {
    group('success factory', () {
      test('creates successful result with email and code', () {
        final result = AccountDeletionRequestResult.success(
          email: 'test@example.com',
          deletionCode: '123456',
        );

        expect(result.success, isTrue);
        expect(result.email, equals('test@example.com'));
        expect(result.deletionCode, equals('123456'));
        expect(result.error, isNull);
      });

      test('isFailure returns false for success', () {
        final result = AccountDeletionRequestResult.success(
          email: 'test@example.com',
          deletionCode: '123456',
        );

        expect(result.isFailure, isFalse);
      });

      test('hasError returns false for success', () {
        final result = AccountDeletionRequestResult.success(
          email: 'test@example.com',
          deletionCode: '123456',
        );

        expect(result.hasError, isFalse);
      });
    });

    group('failure factory', () {
      test('creates failed result with error message', () {
        final result = AccountDeletionRequestResult.failure(
          error: 'User not found',
        );

        expect(result.success, isFalse);
        expect(result.email, isNull);
        expect(result.deletionCode, isNull);
        expect(result.error, equals('User not found'));
      });

      test('isFailure returns true for failure', () {
        final result = AccountDeletionRequestResult.failure(
          error: 'Some error',
        );

        expect(result.isFailure, isTrue);
      });

      test('hasError returns true for failure with message', () {
        final result = AccountDeletionRequestResult.failure(
          error: 'Some error',
        );

        expect(result.hasError, isTrue);
      });

      test('hasError returns false for failure with empty message', () {
        final result = AccountDeletionRequestResult.failure(error: '');

        expect(result.hasError, isFalse);
      });
    });

    group('toString', () {
      test('success result has descriptive toString', () {
        final result = AccountDeletionRequestResult.success(
          email: 'test@example.com',
          deletionCode: '123456',
        );

        final str = result.toString();

        expect(str, contains('success'));
        expect(str, contains('test@example.com'));
        expect(str, contains('123456'));
      });

      test('failure result has descriptive toString', () {
        final result = AccountDeletionRequestResult.failure(
          error: 'User not found',
        );

        final str = result.toString();

        expect(str, contains('failure'));
        expect(str, contains('User not found'));
      });
    });

    group('edge cases', () {
      test('success with empty email', () {
        final result = AccountDeletionRequestResult.success(
          email: '',
          deletionCode: '123456',
        );

        expect(result.success, isTrue);
        expect(result.email, equals(''));
      });

      test('success with empty deletion code', () {
        final result = AccountDeletionRequestResult.success(
          email: 'test@example.com',
          deletionCode: '',
        );

        expect(result.success, isTrue);
        expect(result.deletionCode, equals(''));
      });

      test('failure with various error messages', () {
        final errors = [
          'User not found',
          'Invalid credentials',
          'Network error',
          'A very long error message that contains a lot of details about what went wrong',
        ];

        for (final error in errors) {
          final result = AccountDeletionRequestResult.failure(error: error);

          expect(result.isFailure, isTrue);
          expect(result.error, equals(error));
        }
      });
    });
  });
}
