import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/data/auth_service.dart';

void main() {
  group('MockAuthService', () {
    late MockAuthService authService;

    setUp(() {
      // Use minimal delays for faster tests
      authService = MockAuthService(
        minDelay: Duration.zero,
        maxDelay: const Duration(milliseconds: 10),
        tokenExpiry: const Duration(hours: 1),
      );
    });

    group('login', () {
      test('returns success with valid credentials (user 1)', () async {
        final result = await authService.login('test@gmail.com', '1234');

        expect(result.success, isTrue);
        expect(result.userId, equals('test-user-123'));
        expect(result.tokens, isNotNull);
        expect(result.tokens!.accessToken, contains('::access::'));
        expect(result.tokens!.refreshToken, contains('::refresh::'));
        expect(result.tokens!.isExpired, isFalse);
        expect(result.error, isNull);
      });

      test('returns success with valid credentials (user 2)', () async {
        final result = await authService.login('test2@gmail.com', '1234');

        expect(result.success, isTrue);
        expect(result.userId, equals('test-user-321'));
        expect(result.tokens, isNotNull);
      });

      test('handles email case insensitively', () async {
        final result = await authService.login('TEST@GMAIL.COM', '1234');

        expect(result.success, isTrue);
        expect(result.userId, equals('test-user-123'));
      });

      test('handles email with whitespace', () async {
        final result = await authService.login('  test@gmail.com  ', '1234');

        expect(result.success, isTrue);
        expect(result.userId, equals('test-user-123'));
      });

      test('returns failure for unknown email', () async {
        final result = await authService.login('unknown@gmail.com', '1234');

        expect(result.success, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.userId, isNull);
        expect(result.tokens, isNull);
        expect(result.error, contains('No account found'));
      });

      test('returns failure for wrong password', () async {
        final result = await authService.login('test@gmail.com', 'wrong');

        expect(result.success, isFalse);
        expect(result.userId, isNull);
        expect(result.tokens, isNull);
        expect(result.error, contains('Invalid password'));
      });

      test('generated tokens have correct expiry', () async {
        final beforeLogin = DateTime.now();
        final result = await authService.login('test@gmail.com', '1234');
        final afterLogin = DateTime.now();

        expect(result.tokens!.expiresAt.isAfter(beforeLogin), isTrue);
        expect(
          result.tokens!.expiresAt.isBefore(
            afterLogin.add(const Duration(hours: 1, seconds: 1)),
          ),
          isTrue,
        );
      });

      test('generated tokens contain userId', () async {
        final result = await authService.login('test@gmail.com', '1234');

        // Token format: mock::{type}::{userId}::{random}
        expect(result.tokens!.accessToken, contains('::test-user-123::'));
        expect(result.tokens!.refreshToken, contains('::test-user-123::'));
      });

      test('each login generates unique tokens', () async {
        final result1 = await authService.login('test@gmail.com', '1234');
        final result2 = await authService.login('test@gmail.com', '1234');

        expect(
          result1.tokens!.accessToken,
          isNot(equals(result2.tokens!.accessToken)),
        );
        expect(
          result1.tokens!.refreshToken,
          isNot(equals(result2.tokens!.refreshToken)),
        );
      });
    });

    group('refreshToken', () {
      test('returns new tokens with valid refresh token', () async {
        // First login to get a valid refresh token
        final loginResult = await authService.login('test@gmail.com', '1234');
        final refreshToken = loginResult.tokens!.refreshToken;

        final newTokens = await authService.refreshToken(refreshToken);

        expect(newTokens.accessToken, isNotEmpty);
        expect(newTokens.refreshToken, isNotEmpty);
        expect(newTokens.isExpired, isFalse);
      });

      test('returns different tokens than original', () async {
        final loginResult = await authService.login('test@gmail.com', '1234');
        final originalTokens = loginResult.tokens!;

        final newTokens = await authService.refreshToken(
          originalTokens.refreshToken,
        );

        expect(
          newTokens.accessToken,
          isNot(equals(originalTokens.accessToken)),
        );
        expect(
          newTokens.refreshToken,
          isNot(equals(originalTokens.refreshToken)),
        );
      });

      test('throws AuthException for invalid refresh token format', () async {
        expect(
          () => authService.refreshToken('invalid-token'),
          throwsA(isA<AuthException>()),
        );
      });

      test('throws AuthException with correct code', () async {
        try {
          await authService.refreshToken('invalid-token');
          fail('Should have thrown AuthException');
        } on AuthException catch (e) {
          expect(e.code, equals('INVALID_REFRESH_TOKEN'));
          expect(e.message, contains('Invalid refresh token'));
        }
      });

      test('preserves userId in new tokens', () async {
        final loginResult = await authService.login('test@gmail.com', '1234');
        final refreshToken = loginResult.tokens!.refreshToken;

        final newTokens = await authService.refreshToken(refreshToken);

        // Token format: mock::{type}::{userId}::{random}
        expect(newTokens.accessToken, contains('::test-user-123::'));
        expect(newTokens.refreshToken, contains('::test-user-123::'));
      });
    });

    group('logout', () {
      test('completes successfully with access token', () async {
        final loginResult = await authService.login('test@gmail.com', '1234');
        final accessToken = loginResult.tokens!.accessToken;

        // Should not throw
        await authService.logout(accessToken);
      });

      test('completes successfully with null access token', () async {
        // Should not throw
        await authService.logout(null);
      });
    });

    group('token expiry configuration', () {
      test('uses configured token expiry', () async {
        final shortExpiryService = MockAuthService(
          minDelay: Duration.zero,
          maxDelay: Duration.zero,
          tokenExpiry: const Duration(minutes: 5),
        );

        final result = await shortExpiryService.login('test@gmail.com', '1234');

        // Token should expire in about 5 minutes
        final expiresIn = result.tokens!.expiresAt.difference(DateTime.now());
        expect(expiresIn.inMinutes, lessThanOrEqualTo(5));
        expect(expiresIn.inMinutes, greaterThanOrEqualTo(4));
      });
    });

    group('register', () {
      test('returns success with new email', () async {
        final result = await authService.register(
          name: 'Test User',
          email: 'newuser@test.com',
          password: 'Password123',
        );

        expect(result.success, isTrue);
        expect(result.userId, isNotNull);
        expect(result.verificationCode, isNotNull);
        expect(result.verificationCode!.length, equals(6));
        expect(result.error, isNull);
      });

      test('returns failure for existing test email', () async {
        final result = await authService.register(
          name: 'Test User',
          email: 'test@gmail.com', // Existing test credential
          password: 'Password123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('already exists'));
      });

      test('normalizes email to lowercase', () async {
        final result = await authService.register(
          name: 'Test User',
          email: 'NEWUSER@TEST.COM',
          password: 'Password123',
        );

        expect(result.success, isTrue);
      });

      test('trims whitespace from inputs', () async {
        final result = await authService.register(
          name: '  Test User  ',
          email: '  newuser2@test.com  ',
          password: 'Password123',
        );

        expect(result.success, isTrue);
      });

      test('generates 6-digit verification codes', () async {
        final result = await authService.register(
          name: 'User 1',
          email: 'user1@test.com',
          password: 'Password123',
        );

        expect(result.verificationCode, isNotNull);
        expect(result.verificationCode!.length, equals(6));
        expect(int.tryParse(result.verificationCode!), isNotNull);
      });

      test('returns failure for already pending email', () async {
        // First registration
        await authService.register(
          name: 'User 1',
          email: 'pending@test.com',
          password: 'Password123',
        );

        // Second registration with same email
        final result = await authService.register(
          name: 'User 2',
          email: 'pending@test.com',
          password: 'Password456',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('pending'));
      });
    });

    group('verifyEmail', () {
      test('returns success with correct code', () async {
        // First register
        final regResult = await authService.register(
          name: 'Test User',
          email: 'verify@test.com',
          password: 'Password123',
        );

        // Then verify
        final verifyResult = await authService.verifyEmail(
          userId: regResult.userId!,
          code: regResult.verificationCode!,
        );

        expect(verifyResult.success, isTrue);
        expect(verifyResult.tokens, isNotNull);
        expect(verifyResult.userId, equals(regResult.userId));
      });

      test('returns failure with wrong code', () async {
        final regResult = await authService.register(
          name: 'Test User',
          email: 'wrongcode@test.com',
          password: 'Password123',
        );

        final verifyResult = await authService.verifyEmail(
          userId: regResult.userId!,
          code: '000000', // Wrong code
        );

        expect(verifyResult.success, isFalse);
        expect(verifyResult.error, contains('Invalid verification code'));
      });

      test('returns failure for unknown userId', () async {
        final verifyResult = await authService.verifyEmail(
          userId: 'unknown-user-id',
          code: '123456',
        );

        expect(verifyResult.success, isFalse);
        expect(verifyResult.error, contains('not found'));
      });

      test('allows login after verification', () async {
        // Register and verify
        final regResult = await authService.register(
          name: 'Login Test',
          email: 'logintest@test.com',
          password: 'Password123',
        );
        await authService.verifyEmail(
          userId: regResult.userId!,
          code: regResult.verificationCode!,
        );

        // Now login should work
        final loginResult = await authService.login(
          'logintest@test.com',
          'Password123',
        );

        expect(loginResult.success, isTrue);
        expect(loginResult.userId, equals(regResult.userId));
      });

      test('removes pending registration after verification', () async {
        final regResult = await authService.register(
          name: 'Test User',
          email: 'removepending@test.com',
          password: 'Password123',
        );

        // Verify
        await authService.verifyEmail(
          userId: regResult.userId!,
          code: regResult.verificationCode!,
        );

        // Try to verify again - should fail
        final secondVerify = await authService.verifyEmail(
          userId: regResult.userId!,
          code: regResult.verificationCode!,
        );

        expect(secondVerify.success, isFalse);
        expect(secondVerify.error, contains('not found'));
      });

      test('generated tokens contain userId', () async {
        final regResult = await authService.register(
          name: 'Token Test',
          email: 'tokentest@test.com',
          password: 'Password123',
        );

        final verifyResult = await authService.verifyEmail(
          userId: regResult.userId!,
          code: regResult.verificationCode!,
        );

        expect(
          verifyResult.tokens!.accessToken,
          contains('::${regResult.userId}::'),
        );
        expect(
          verifyResult.tokens!.refreshToken,
          contains('::${regResult.userId}::'),
        );
      });
    });

    group('requestPasswordReset', () {
      test('returns success for existing test email', () async {
        final result = await authService.requestPasswordReset('test@gmail.com');

        expect(result.success, isTrue);
        expect(result.email, equals('test@gmail.com'));
        expect(result.resetCode, isNotNull);
        expect(result.resetCode!.length, equals(6));
        expect(result.error, isNull);
      });

      test('returns success for existing test email (user 2)', () async {
        final result = await authService.requestPasswordReset(
          'test2@gmail.com',
        );

        expect(result.success, isTrue);
        expect(result.email, equals('test2@gmail.com'));
      });

      test('returns success for registered user email', () async {
        // First register and verify a user
        final regResult = await authService.register(
          name: 'Reset Test',
          email: 'resettest@test.com',
          password: 'Password123',
        );
        await authService.verifyEmail(
          userId: regResult.userId!,
          code: regResult.verificationCode!,
        );

        final result = await authService.requestPasswordReset(
          'resettest@test.com',
        );

        expect(result.success, isTrue);
        expect(result.email, equals('resettest@test.com'));
      });

      test('returns failure for unknown email', () async {
        final result = await authService.requestPasswordReset(
          'unknown@test.com',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('No account'));
      });

      test('normalizes email to lowercase', () async {
        final result = await authService.requestPasswordReset('TEST@GMAIL.COM');

        expect(result.success, isTrue);
        expect(result.email, equals('test@gmail.com'));
      });

      test('trims whitespace from email', () async {
        final result = await authService.requestPasswordReset(
          '  test@gmail.com  ',
        );

        expect(result.success, isTrue);
        expect(result.email, equals('test@gmail.com'));
      });

      test('generates 6-digit reset code', () async {
        final result = await authService.requestPasswordReset('test@gmail.com');

        expect(result.resetCode!.length, equals(6));
        expect(int.tryParse(result.resetCode!), isNotNull);
      });

      test('allows multiple reset requests (overwrites previous)', () async {
        final result1 = await authService.requestPasswordReset(
          'test@gmail.com',
        );
        final result2 = await authService.requestPasswordReset(
          'test@gmail.com',
        );

        expect(result1.success, isTrue);
        expect(result2.success, isTrue);
        // Second code should be different (new request)
        expect(result1.resetCode, isNot(equals(result2.resetCode)));
      });
    });

    group('resetPassword', () {
      test('returns success with correct code', () async {
        final requestResult = await authService.requestPasswordReset(
          'test@gmail.com',
        );

        final result = await authService.resetPassword(
          email: 'test@gmail.com',
          code: requestResult.resetCode!,
          newPassword: 'NewPassword123',
        );

        expect(result.success, isTrue);
        expect(result.error, isNull);
      });

      test('returns failure with wrong code', () async {
        await authService.requestPasswordReset('test@gmail.com');

        final result = await authService.resetPassword(
          email: 'test@gmail.com',
          code: '000000',
          newPassword: 'NewPassword123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Invalid reset code'));
      });

      test('returns failure for email without reset request', () async {
        final result = await authService.resetPassword(
          email: 'test@gmail.com',
          code: '123456',
          newPassword: 'NewPassword123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('No password reset request'));
      });

      test('clears pending reset after successful reset', () async {
        final requestResult = await authService.requestPasswordReset(
          'test@gmail.com',
        );

        // First reset succeeds
        await authService.resetPassword(
          email: 'test@gmail.com',
          code: requestResult.resetCode!,
          newPassword: 'NewPassword123',
        );

        // Second attempt with same code should fail
        final secondResult = await authService.resetPassword(
          email: 'test@gmail.com',
          code: requestResult.resetCode!,
          newPassword: 'AnotherPassword',
        );

        expect(secondResult.success, isFalse);
        expect(secondResult.error, contains('No password reset request'));
      });

      test('allows login with new password for test credentials', () async {
        final requestResult = await authService.requestPasswordReset(
          'test@gmail.com',
        );

        await authService.resetPassword(
          email: 'test@gmail.com',
          code: requestResult.resetCode!,
          newPassword: 'NewPassword456',
        );

        // Login with new password should work
        final loginResult = await authService.login(
          'test@gmail.com',
          'NewPassword456',
        );
        expect(loginResult.success, isTrue);
      });

      test('allows login with new password for registered users', () async {
        // Register and verify a user
        final regResult = await authService.register(
          name: 'Password Test',
          email: 'pwtest@test.com',
          password: 'OldPassword123',
        );
        await authService.verifyEmail(
          userId: regResult.userId!,
          code: regResult.verificationCode!,
        );

        // Request and perform reset
        final requestResult = await authService.requestPasswordReset(
          'pwtest@test.com',
        );
        await authService.resetPassword(
          email: 'pwtest@test.com',
          code: requestResult.resetCode!,
          newPassword: 'NewPassword789',
        );

        // Login with new password
        final loginResult = await authService.login(
          'pwtest@test.com',
          'NewPassword789',
        );
        expect(loginResult.success, isTrue);

        // Old password should no longer work
        final oldLoginResult = await authService.login(
          'pwtest@test.com',
          'OldPassword123',
        );
        expect(oldLoginResult.success, isFalse);
      });

      test('normalizes email to lowercase', () async {
        final requestResult = await authService.requestPasswordReset(
          'test@gmail.com',
        );

        final result = await authService.resetPassword(
          email: 'TEST@GMAIL.COM',
          code: requestResult.resetCode!,
          newPassword: 'NewPassword123',
        );

        expect(result.success, isTrue);
      });
    });
  });

  group('AuthException', () {
    test('toString includes message', () {
      const exception = AuthException('Something went wrong');
      expect(exception.toString(), contains('Something went wrong'));
    });

    test('toString includes code when provided', () {
      const exception = AuthException('Error', code: 'ERROR_CODE');
      expect(exception.toString(), contains('ERROR_CODE'));
    });

    test('toString format without code', () {
      const exception = AuthException('Error message');
      expect(exception.toString(), equals('AuthException: Error message'));
    });

    test('toString format with code', () {
      const exception = AuthException('Error message', code: 'CODE');
      expect(
        exception.toString(),
        equals('AuthException: Error message (CODE)'),
      );
    });
  });
}
