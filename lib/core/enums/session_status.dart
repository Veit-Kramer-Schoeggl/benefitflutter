/// Status of a tracking session
enum SessionStatus {
  /// Session is currently active/recording
  active,

  /// Session is temporarily paused
  paused,

  /// Session has been completed
  completed,

  /// Session was cancelled/abandoned
  cancelled;

  /// Convert to JSON string
  String toJson() => name;

  /// Create from JSON string
  static SessionStatus fromJson(String value) {
    return SessionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SessionStatus.completed,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Check if session is in a final state
  bool get isFinal =>
      this == SessionStatus.completed || this == SessionStatus.cancelled;

  /// Check if session is ongoing
  bool get isOngoing =>
      this == SessionStatus.active || this == SessionStatus.paused;
}
