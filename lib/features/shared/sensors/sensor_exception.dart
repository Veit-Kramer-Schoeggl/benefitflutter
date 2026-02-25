/// Exception thrown by sensors when operations fail
///
/// Provides detailed error information including sensor ID,
/// error message, and exception type.
class SensorException implements Exception {
  /// Error message describing what went wrong
  final String message;

  /// ID of the sensor that threw the exception
  final String sensorId;

  /// Type of exception for categorization
  final SensorExceptionType type;

  SensorException({
    required this.message,
    required this.sensorId,
    required this.type,
  });

  @override
  String toString() => 'SensorException($sensorId): $message';
}

/// Types of sensor exceptions
enum SensorExceptionType {
  /// Permission denied by user
  permissionDenied,

  /// Sensor hardware unavailable on device
  unavailable,

  /// Failed to initialize sensor
  initializationFailed,

  /// Failed to start streaming
  streamingFailed,
}
