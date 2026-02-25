import 'auth_tokens.dart';

/// Result of an authentication attempt (login or token refresh)
///
/// Contains either successful tokens + userId, or an error message.
class AuthResult {
  final bool success;
  final AuthTokens? tokens;
  final String? userId;
  final String? error;

  const AuthResult._({
    required this.success,
    this.tokens,
    this.userId,
    this.error,
  });

  /// Create a successful authentication result
  factory AuthResult.success({
    required AuthTokens tokens,
    required String userId,
  }) {
    return AuthResult._(
      success: true,
      tokens: tokens,
      userId: userId,
      error: null,
    );
  }

  /// Create a failed authentication result
  factory AuthResult.failure({required String error}) {
    return AuthResult._(
      success: false,
      tokens: null,
      userId: null,
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
    return other is AuthResult &&
        other.success == success &&
        other.tokens == tokens &&
        other.userId == userId &&
        other.error == error;
  }

  @override
  int get hashCode =>
      success.hashCode ^ tokens.hashCode ^ userId.hashCode ^ error.hashCode;

  @override
  String toString() {
    if (success) {
      return 'AuthResult.success(userId: $userId)';
    } else {
      return 'AuthResult.failure(error: $error)';
    }
  }
}
