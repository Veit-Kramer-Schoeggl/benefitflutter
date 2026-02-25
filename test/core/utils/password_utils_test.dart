import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/utils/password_utils.dart';

void main() {
  group('PasswordUtils', () {
    group('hashPassword', () {
      test('returns consistent hash for same password', () {
        const password = 'MySecurePassword123';
        final hash1 = PasswordUtils.hashPassword(password);
        final hash2 = PasswordUtils.hashPassword(password);

        expect(hash1, equals(hash2));
      });

      test('returns different hash for different passwords', () {
        final hash1 = PasswordUtils.hashPassword('Password1');
        final hash2 = PasswordUtils.hashPassword('Password2');

        expect(hash1, isNot(equals(hash2)));
      });

      test('returns 64 character hex string (SHA-256)', () {
        final hash = PasswordUtils.hashPassword('test');

        expect(hash.length, equals(64));
        expect(hash, matches(RegExp(r'^[a-f0-9]+$')));
      });

      test('handles empty string', () {
        final hash = PasswordUtils.hashPassword('');

        // SHA-256 of empty string is known
        expect(hash,
            equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
      });

      test('handles special characters', () {
        final hash = PasswordUtils.hashPassword('P@ssw0rd!#\$%^&*()');

        expect(hash.length, equals(64));
        expect(hash, matches(RegExp(r'^[a-f0-9]+$')));
      });

      test('handles unicode characters', () {
        final hash = PasswordUtils.hashPassword('Pässwörd123');

        expect(hash.length, equals(64));
        expect(hash, matches(RegExp(r'^[a-f0-9]+$')));
      });

      test('handles very long passwords', () {
        final longPassword = 'A' * 10000;
        final hash = PasswordUtils.hashPassword(longPassword);

        expect(hash.length, equals(64));
        expect(hash, matches(RegExp(r'^[a-f0-9]+$')));
      });

      test('is case sensitive', () {
        final hash1 = PasswordUtils.hashPassword('Password');
        final hash2 = PasswordUtils.hashPassword('password');
        final hash3 = PasswordUtils.hashPassword('PASSWORD');

        expect(hash1, isNot(equals(hash2)));
        expect(hash2, isNot(equals(hash3)));
        expect(hash1, isNot(equals(hash3)));
      });

      test('whitespace affects hash', () {
        final hash1 = PasswordUtils.hashPassword('password');
        final hash2 = PasswordUtils.hashPassword(' password');
        final hash3 = PasswordUtils.hashPassword('password ');
        final hash4 = PasswordUtils.hashPassword(' password ');

        expect(hash1, isNot(equals(hash2)));
        expect(hash1, isNot(equals(hash3)));
        expect(hash1, isNot(equals(hash4)));
        expect(hash2, isNot(equals(hash3)));
      });
    });

    group('verifyPassword', () {
      test('returns true for correct password', () {
        const password = 'MySecurePassword123';
        final hash = PasswordUtils.hashPassword(password);

        expect(PasswordUtils.verifyPassword(password, hash), isTrue);
      });

      test('returns false for incorrect password', () {
        const correctPassword = 'MySecurePassword123';
        const wrongPassword = 'WrongPassword123';
        final hash = PasswordUtils.hashPassword(correctPassword);

        expect(PasswordUtils.verifyPassword(wrongPassword, hash), isFalse);
      });

      test('returns false for similar but different password', () {
        const password = 'Password123';
        final hash = PasswordUtils.hashPassword(password);

        expect(PasswordUtils.verifyPassword('Password124', hash), isFalse);
        expect(PasswordUtils.verifyPassword('password123', hash), isFalse);
        expect(PasswordUtils.verifyPassword('Password123 ', hash), isFalse);
      });

      test('returns true for empty password with empty hash', () {
        final emptyHash = PasswordUtils.hashPassword('');

        expect(PasswordUtils.verifyPassword('', emptyHash), isTrue);
      });

      test('returns false for empty password with non-empty hash', () {
        final hash = PasswordUtils.hashPassword('SomePassword');

        expect(PasswordUtils.verifyPassword('', hash), isFalse);
      });

      test('returns false for non-empty password with empty hash', () {
        final emptyHash = PasswordUtils.hashPassword('');

        expect(PasswordUtils.verifyPassword('SomePassword', emptyHash), isFalse);
      });

      test('handles special characters correctly', () {
        const password = 'P@ss!w0rd#\$%^&*()';
        final hash = PasswordUtils.hashPassword(password);

        expect(PasswordUtils.verifyPassword(password, hash), isTrue);
        expect(PasswordUtils.verifyPassword('P@ss!w0rd#\$%^&*()', hash), isTrue);
        expect(PasswordUtils.verifyPassword('P@ss!w0rd', hash), isFalse);
      });

      test('handles unicode characters correctly', () {
        const password = 'Pässwörd123';
        final hash = PasswordUtils.hashPassword(password);

        expect(PasswordUtils.verifyPassword(password, hash), isTrue);
        expect(PasswordUtils.verifyPassword('Passwörd123', hash), isFalse);
      });
    });

    group('hash-verify roundtrip', () {
      final testPasswords = [
        'SimplePass1',
        'Complex!P@ss#123',
        'WithSpaces In It',
        '12345678',
        'ALLUPPER1',
        'alllower1',
        'Mix3dC@se!',
        '🔐Password',
        'Very' * 100,
      ];

      for (final password in testPasswords) {
        test('roundtrip works for "$password"', () {
          final hash = PasswordUtils.hashPassword(password);
          expect(PasswordUtils.verifyPassword(password, hash), isTrue);
        });
      }
    });
  });
}
