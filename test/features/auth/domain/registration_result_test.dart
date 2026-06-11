import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/domain/registration_result.dart';

void main() {
  group('RegistrationResult', () {
    group('success factory', () {
      test('creates successful result with userId and code', () {
        final result = RegistrationResult.success(
          userId: 'user-123',
          verificationCode: '123456',
        );

        expect(result.success, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.userId, equals('user-123'));
        expect(result.verificationCode, equals('123456'));
        expect(result.error, isNull);
        expect(result.hasError, isFalse);
      });

      test('creates result with different verification codes', () {
        final result = RegistrationResult.success(
          userId: 'user-456',
          verificationCode: '999888',
        );

        expect(result.success, isTrue);
        expect(result.verificationCode, equals('999888'));
      });
    });

    group('failure factory', () {
      test('creates failed result with error message', () {
        final result = RegistrationResult.failure(
          error: 'Email already exists',
        );

        expect(result.success, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.userId, isNull);
        expect(result.verificationCode, isNull);
        expect(result.error, equals('Email already exists'));
        expect(result.hasError, isTrue);
      });

      test('creates failed result with different error', () {
        final result = RegistrationResult.failure(error: 'Registration failed');

        expect(result.isFailure, isTrue);
        expect(result.error, equals('Registration failed'));
      });

      test('hasError returns false for empty error', () {
        final result = RegistrationResult.failure(error: '');

        expect(result.hasError, isFalse);
      });
    });

    group('equality', () {
      test('equal success results are equal', () {
        final result1 = RegistrationResult.success(
          userId: 'user-1',
          verificationCode: '123456',
        );
        final result2 = RegistrationResult.success(
          userId: 'user-1',
          verificationCode: '123456',
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('equal failure results are equal', () {
        final result1 = RegistrationResult.failure(error: 'Error');
        final result2 = RegistrationResult.failure(error: 'Error');

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('different userIds means not equal', () {
        final result1 = RegistrationResult.success(
          userId: 'user-1',
          verificationCode: '123456',
        );
        final result2 = RegistrationResult.success(
          userId: 'user-2',
          verificationCode: '123456',
        );

        expect(result1, isNot(equals(result2)));
      });

      test('different verification codes means not equal', () {
        final result1 = RegistrationResult.success(
          userId: 'user-1',
          verificationCode: '123456',
        );
        final result2 = RegistrationResult.success(
          userId: 'user-1',
          verificationCode: '654321',
        );

        expect(result1, isNot(equals(result2)));
      });

      test('different errors means not equal', () {
        final result1 = RegistrationResult.failure(error: 'Error 1');
        final result2 = RegistrationResult.failure(error: 'Error 2');

        expect(result1, isNot(equals(result2)));
      });

      test('success and failure are not equal', () {
        final success = RegistrationResult.success(
          userId: 'user-1',
          verificationCode: '123456',
        );
        final failure = RegistrationResult.failure(error: 'Error');

        expect(success, isNot(equals(failure)));
      });
    });

    group('toString', () {
      test('success toString shows correct format', () {
        final result = RegistrationResult.success(
          userId: 'user-123',
          verificationCode: '123456',
        );

        final str = result.toString();
        expect(str, contains('success'));
        expect(str, contains('user-123'));
        expect(str, contains('123456'));
      });

      test('failure toString shows correct format', () {
        final result = RegistrationResult.failure(error: 'Registration failed');

        final str = result.toString();
        expect(str, contains('failure'));
        expect(str, contains('Registration failed'));
      });
    });
  });
}
