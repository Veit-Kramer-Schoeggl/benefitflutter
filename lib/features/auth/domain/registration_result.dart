/// Result of a registration attempt
///
/// Contains either successful userId + verification code, or an error message.
/// Unlike AuthResult, this does not contain tokens - tokens are provided
/// after email verification.
class RegistrationResult {
  final bool success;
  final String? userId;
  final String? verificationCode;
  final String? error;

  const RegistrationResult._({
    required this.success,
    this.userId,
    this.verificationCode,
    this.error,
  });

  /// Create a successful registration result
  factory RegistrationResult.success({
    required String userId,
    required String verificationCode,
  }) {
    return RegistrationResult._(
      success: true,
      userId: userId,
      verificationCode: verificationCode,
      error: null,
    );
  }

  /// Create a failed registration result
  factory RegistrationResult.failure({required String error}) {
    return RegistrationResult._(
      success: false,
      userId: null,
      verificationCode: null,
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
    return other is RegistrationResult &&
        other.success == success &&
        other.userId == userId &&
        other.verificationCode == verificationCode &&
        other.error == error;
  }

  @override
  int get hashCode =>
      success.hashCode ^
      userId.hashCode ^
      verificationCode.hashCode ^
      error.hashCode;

  @override
  String toString() {
    if (success) {
      return 'RegistrationResult.success(userId: $userId, code: $verificationCode)';
    } else {
      return 'RegistrationResult.failure(error: $error)';
    }
  }
}
