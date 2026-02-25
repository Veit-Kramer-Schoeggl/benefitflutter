/// UI state for Activity tracking screen
///
/// Represents the current state of a manual tracking session in the UI.
/// This is separate from SessionStatus which is stored in the database.
enum TrackingState {
  /// No active manual tracking session
  /// User can select activity type and start a new session
  idle,

  /// Manual tracking session is active and timer is running
  /// User can pause or stop the session
  tracking,

  /// Manual tracking session is paused and timer is stopped
  /// User can resume or stop the session
  paused;

  /// Human-readable display name for the state
  String get displayName {
    switch (this) {
      case TrackingState.idle:
        return 'Ready';
      case TrackingState.tracking:
        return 'Tracking';
      case TrackingState.paused:
        return 'Paused';
    }
  }
}
