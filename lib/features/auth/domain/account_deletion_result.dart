/// Result of an account deletion confirmation
///
/// Contains success/failure status. On success, user is logged out.
class AccountDeletionResult {
  final bool success;
  final String? error;

  const AccountDeletionResult._({
    required this.success,
    this.error,
  });

  /// Create a successful account deletion result
  factory AccountDeletionResult.success() {
    return const AccountDeletionResult._(
      success: true,
      error: null,
    );
  }

  /// Create a failed account deletion result
  factory AccountDeletionResult.failure({required String error}) {
    return AccountDeletionResult._(
      success: false,
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
      return 'AccountDeletionResult.success()';
    } else {
      return 'AccountDeletionResult.failure(error: $error)';
    }
  }
}
