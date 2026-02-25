import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/utils/password_validator.dart';

void main() {
  group('PasswordValidator', () {
    group('validate', () {
      test('returns null for valid password', () {
        expect(PasswordValidator.validate('Password1'), isNull);
        expect(PasswordValidator.validate('Abcdefg1'), isNull);
        expect(PasswordValidator.validate('MyP@ssw0rd'), isNull);
        expect(PasswordValidator.validate('Complex123Pass'), isNull);
      });

      test('returns error for password too short', () {
        final result = PasswordValidator.validate('Pass1');
        expect(result, contains('8 characters'));
      });

      test('returns error for password without uppercase', () {
        final result = PasswordValidator.validate('password1');
        expect(result, contains('uppercase'));
      });

      test('returns error for password without lowercase', () {
        final result = PasswordValidator.validate('PASSWORD1');
        expect(result, contains('lowercase'));
      });

      test('returns error for password without number', () {
        final result = PasswordValidator.validate('Passwordd');
        expect(result, contains('number'));
      });

      test('returns first error encountered (length)', () {
        // Short password triggers length error first
        final result = PasswordValidator.validate('ab1');
        expect(result, contains('8 characters'));
      });

      test('returns length error before uppercase error', () {
        // Even though it lacks uppercase, length is checked first
        final result = PasswordValidator.validate('short1');
        expect(result, contains('8 characters'));
      });
    });

    group('hasMinLength', () {
      test('returns true for exactly 8 characters', () {
        expect(PasswordValidator.hasMinLength('12345678'), isTrue);
      });

      test('returns true for more than 8 characters', () {
        expect(PasswordValidator.hasMinLength('123456789'), isTrue);
        expect(PasswordValidator.hasMinLength('a' * 20), isTrue);
      });

      test('returns false for less than 8 characters', () {
        expect(PasswordValidator.hasMinLength('1234567'), isFalse);
        expect(PasswordValidator.hasMinLength(''), isFalse);
        expect(PasswordValidator.hasMinLength('a'), isFalse);
      });
    });

    group('hasUppercase', () {
      test('returns true when contains uppercase at start', () {
        expect(PasswordValidator.hasUppercase('Password'), isTrue);
      });

      test('returns true when contains uppercase at end', () {
        expect(PasswordValidator.hasUppercase('passworD'), isTrue);
      });

      test('returns true when contains uppercase in middle', () {
        expect(PasswordValidator.hasUppercase('passWord'), isTrue);
      });

      test('returns true when multiple uppercase letters', () {
        expect(PasswordValidator.hasUppercase('PassWord'), isTrue);
      });

      test('returns false when no uppercase', () {
        expect(PasswordValidator.hasUppercase('password'), isFalse);
        expect(PasswordValidator.hasUppercase('12345678'), isFalse);
        expect(PasswordValidator.hasUppercase(''), isFalse);
      });
    });

    group('hasLowercase', () {
      test('returns true when contains lowercase at start', () {
        expect(PasswordValidator.hasLowercase('pASSWORD'), isTrue);
      });

      test('returns true when contains lowercase at end', () {
        expect(PasswordValidator.hasLowercase('PASSWORd'), isTrue);
      });

      test('returns true when contains lowercase in middle', () {
        expect(PasswordValidator.hasLowercase('PASSoORD'), isTrue);
      });

      test('returns false when no lowercase', () {
        expect(PasswordValidator.hasLowercase('PASSWORD'), isFalse);
        expect(PasswordValidator.hasLowercase('12345678'), isFalse);
        expect(PasswordValidator.hasLowercase(''), isFalse);
      });
    });

    group('hasNumber', () {
      test('returns true when contains number at start', () {
        expect(PasswordValidator.hasNumber('1Password'), isTrue);
      });

      test('returns true when contains number at end', () {
        expect(PasswordValidator.hasNumber('Password1'), isTrue);
      });

      test('returns true when contains number in middle', () {
        expect(PasswordValidator.hasNumber('Pass1word'), isTrue);
      });

      test('returns true when multiple numbers', () {
        expect(PasswordValidator.hasNumber('Pass123word'), isTrue);
      });

      test('returns false when no number', () {
        expect(PasswordValidator.hasNumber('Password'), isFalse);
        expect(PasswordValidator.hasNumber('abcdefgh'), isFalse);
        expect(PasswordValidator.hasNumber(''), isFalse);
      });
    });

    group('isValid', () {
      test('returns true for valid passwords', () {
        expect(PasswordValidator.isValid('Password1'), isTrue);
        expect(PasswordValidator.isValid('ComplexP@ss1'), isTrue);
        expect(PasswordValidator.isValid('Test1234'), isTrue);
        expect(PasswordValidator.isValid('Abcd1234'), isTrue);
      });

      test('returns false for password too short', () {
        expect(PasswordValidator.isValid('Pass1'), isFalse);
      });

      test('returns false for password without uppercase', () {
        expect(PasswordValidator.isValid('password1'), isFalse);
      });

      test('returns false for password without lowercase', () {
        expect(PasswordValidator.isValid('PASSWORD1'), isFalse);
      });

      test('returns false for password without number', () {
        expect(PasswordValidator.isValid('Password'), isFalse);
      });

      test('returns false for empty password', () {
        expect(PasswordValidator.isValid(''), isFalse);
      });
    });

    group('getErrors', () {
      test('returns empty list for valid password', () {
        expect(PasswordValidator.getErrors('Password1'), isEmpty);
      });

      test('returns single error for one violation', () {
        final errors = PasswordValidator.getErrors('Password');
        expect(errors.length, equals(1));
        expect(errors.first, contains('number'));
      });

      test('returns multiple errors for multiple violations', () {
        final errors = PasswordValidator.getErrors('ab');
        expect(errors.length, equals(3)); // too short, no uppercase, no number
        expect(errors.any((e) => e.contains('8 characters')), isTrue);
        expect(errors.any((e) => e.contains('uppercase')), isTrue);
        expect(errors.any((e) => e.contains('number')), isTrue);
      });

      test('returns all four errors for empty password', () {
        final errors = PasswordValidator.getErrors('');
        expect(errors.length, equals(4));
      });

      test('returns all applicable errors for all-numbers', () {
        final errors = PasswordValidator.getErrors('123');
        expect(errors.length, equals(3)); // too short, no uppercase, no lowercase
      });
    });

    group('minLength constant', () {
      test('minLength is 8', () {
        expect(PasswordValidator.minLength, equals(8));
      });
    });
  });
}
