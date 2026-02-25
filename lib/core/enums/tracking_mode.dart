/// Tracking modes for sessions
enum TrackingMode {
  /// User-initiated workout session with start/stop
  manual,

  /// Automatically created daily session from continuous tracking
  continuousDaily;

  /// Convert to JSON string
  String toJson() => name;

  /// Create from JSON string
  static TrackingMode fromJson(String value) {
    return TrackingMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TrackingMode.manual,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case TrackingMode.manual:
        return 'Manual Session';
      case TrackingMode.continuousDaily:
        return 'Daily Movement';
    }
  }
}