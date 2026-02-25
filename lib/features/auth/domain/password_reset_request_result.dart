/// Result of a password reset request
///
/// Contains either successful email + reset code, or an error message.
/// In production, the reset code would be sent via email rather than returned.
class PasswordResetRequestResult {
  final bool success;
  final String? email;
  final String? resetCode;
  final String? error;

  const PasswordResetRequestResult._({
    required this.success,
    this.email,
    this.resetCode,
    this.error,
  });

  /// Create a successful password reset request result
  factory PasswordResetRequestResult.success({
    required String email,
    required String resetCode,
  }) {
    return PasswordResetRequestResult._(
      success: true,
      email: email,
      resetCode: resetCode,
      error: null,
    );
  }

  /// Create a failed password reset request result
  factory PasswordResetRequestResult.failure({required String error}) {
    return PasswordResetRequestResult._(
      success: false,
      email: null,
      resetCode: null,
      error: error,
    );
  }

  /// Whether this result represents a failure
  bool get isFailure => !success;

  /// Whether this result has an error message
  bool get hasError => error != null && error!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PasswordResetRequestResult &&
        other.success == success &&
        other.email == email &&
        other.resetCode == resetCode &&
        other.error == error;
  }

  @override
  int get hashCode =>
      success.hashCode ^
      email.hashCode ^
      resetCode.hashCode ^
      error.hashCode;

  @override
  String toString() {
    if (success) {
      return 'PasswordResetRequestResult.success(email: $email, code: $resetCode)';
    } else {
      return 'PasswordResetRequestResult.failure(error: $error)';
    }
  }
}
