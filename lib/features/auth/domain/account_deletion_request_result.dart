/// Result of an account deletion request
///
/// Contains either successful email + deletion code, or an error message.
/// In production, the deletion code would be sent via email rather than returned.
class AccountDeletionRequestResult {
  final bool success;
  final String? email;
  final String? deletionCode;
  final String? error;

  const AccountDeletionRequestResult._({
    required this.success,
    this.email,
    this.deletionCode,
    this.error,
  });

  /// Create a successful account deletion request result
  factory AccountDeletionRequestResult.success({
    required String email,
    required String deletionCode,
  }) {
    return AccountDeletionRequestResult._(
      success: true,
      email: email,
      deletionCode: deletionCode,
      error: null,
    );
  }

  /// Create a failed account deletion request result
  factory AccountDeletionRequestResult.failure({required String error}) {
    return AccountDeletionRequestResult._(
      success: false,
      email: null,
      deletionCode: null,
      error: error,
    );
  }

  /// Whether this result represents a failure
  bool get isFailure => !success;

  /// Whether this result has an error message
  bool get hasError => error != null && error!.isNotEmpty;

  @override
  String toString() {
    if (success) {
      return 'AccountDeletionRequestResult.success(email: $email, code: $deletionCode)';
    } else {
      return 'AccountDeletionRequestResult.failure(error: $error)';
    }
  }
}
