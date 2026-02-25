/// Result of a password reset attempt
///
/// Contains success/failure status. On success, user should be redirected to login.
class PasswordResetResult {
  final bool success;
  final String? error;

  const PasswordResetResult._({
    required this.success,
    this.error,
  });

  /// Create a successful password reset result
  factory PasswordResetResult.success() {
    return const PasswordResetResult._(
      success: true,
      error: null,
    );
  }

  /// Create a failed password reset result
  factory PasswordResetResult.failure({required String error}) {
    return PasswordResetResult._(
      success: false,
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
    return other is PasswordResetResult &&
        other.success == success &&
        other.error == error;
  }

  @override
  int get hashCode => success.hashCode ^ error.hashCode;

  @override
  String toString() {
    if (success) {
      return 'PasswordResetResult.success()';
    } else {
      return 'PasswordResetResult.failure(error: $error)';
    }
  }
}
