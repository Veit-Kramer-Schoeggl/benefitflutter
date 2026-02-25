/// JWT authentication tokens model
///
/// Holds access token, refresh token, and expiration time.
/// Provides convenience getters for checking token validity.
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  /// Whether the access token has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether the token should be refreshed (5 minutes before expiry)
  bool get needsRefresh =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));

  /// Time remaining until token expires
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());

  /// Create a copy with updated fields
  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Create from JSON map
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthTokens &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode =>
      accessToken.hashCode ^ refreshToken.hashCode ^ expiresAt.hashCode;

  @override
  String toString() {
    return 'AuthTokens(accessToken: ${accessToken.substring(0, 10)}..., '
        'refreshToken: ${refreshToken.substring(0, 10)}..., '
        'expiresAt: $expiresAt)';
  }
}
