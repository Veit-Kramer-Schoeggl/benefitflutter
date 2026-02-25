/// Utility class for password validation
///
/// Provides static methods for validating passwords according to
/// the app's security requirements:
/// - Minimum 8 characters
/// - At least one uppercase letter
/// - At least one lowercase letter
/// - At least one number
class PasswordValidator {
  // Private constructor to prevent instantiation
  PasswordValidator._();

  /// Minimum password length
  static const int minLength = 8;

  /// Validate password and return null if valid, error message if invalid
  ///
  /// Returns the first validation error encountered, or null if valid.
  static String? validate(String password) {
    if (!hasMinLength(password)) {
      return 'Password must be at least $minLength characters';
    }
    if (!hasUppercase(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!hasLowercase(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!hasNumber(password)) {
      return 'Password must contain at least one number';
    }
    return null; // Valid
  }

  /// Check if password meets minimum length requirement
  static bool hasMinLength(String password) => password.length >= minLength;

  /// Check if password contains at least one uppercase letter
  static bool hasUppercase(String password) => password.contains(RegExp(r'[A-Z]'));

  /// Check if password contains at least one lowercase letter
  static bool hasLowercase(String password) => password.contains(RegExp(r'[a-z]'));

  /// Check if password contains at least one digit
  static bool hasNumber(String password) => password.contains(RegExp(r'[0-9]'));

  /// Check if password is completely valid
  static bool isValid(String password) => validate(password) == null;

  /// Get all validation errors as a list
  ///
  /// Returns an empty list if password is valid.
  static List<String> getErrors(String password) {
    final errors = <String>[];

    if (!hasMinLength(password)) {
      errors.add('Password must be at least $minLength characters');
    }
    if (!hasUppercase(password)) {
      errors.add('Password must contain at least one uppercase letter');
    }
    if (!hasLowercase(password)) {
      errors.add('Password must contain at least one lowercase letter');
    }
    if (!hasNumber(password)) {
      errors.add('Password must contain at least one number');
    }

    return errors;
  }
}
