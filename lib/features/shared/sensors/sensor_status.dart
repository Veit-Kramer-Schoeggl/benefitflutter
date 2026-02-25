/// Status of a sensor
///
/// Tracks the current operational state of a sensor including
/// availability, permissions, and active status.
enum SensorStatus {
  /// Sensor is available and ready to use
  available,

  /// Sensor is unavailable (device doesn't have hardware)
  unavailable,

  /// Permission denied by user
  denied,

  /// Permission permanently denied (requires settings)
  permanentlyDenied,

  /// Sensor is currently active/streaming
  active,

  /// Sensor error occurred
  error,
}

extension SensorStatusExtension on SensorStatus {
  /// Check if sensor is available for use
  bool get isAvailable => this == SensorStatus.available;

  /// Check if permission was denied
  bool get isDenied =>
      this == SensorStatus.denied || this == SensorStatus.permanentlyDenied;

  /// Check if we can request permission
  bool get canRequestPermission => this == SensorStatus.denied;

  /// Check if user needs to go to settings
  bool get needsSettings => this == SensorStatus.permanentlyDenied;

  /// Check if sensor is currently streaming data
  bool get isActive => this == SensorStatus.active;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case SensorStatus.available:
        return 'Available';
      case SensorStatus.unavailable:
        return 'Unavailable';
      case SensorStatus.denied:
        return 'Permission Denied';
      case SensorStatus.permanentlyDenied:
        return 'Permanently Denied';
      case SensorStatus.active:
        return 'Active';
      case SensorStatus.error:
        return 'Error';
    }
  }
}
