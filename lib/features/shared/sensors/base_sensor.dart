import 'dart:async';
import 'package:benefitflutter/features/shared/sensors/sensor_status.dart';

/// Abstract base class for all sensors
///
/// Defines common interface that all sensors must implement.
/// Sensors provide stream-based real-time data and status updates.
///
/// Type parameter T represents the data type emitted by the sensor
/// (e.g., GpsPoint for GPS sensor, int for step counter).
///
/// Example implementation:
/// ```dart
/// class GpsSensor extends BaseSensor<GpsPoint> {
///   @override
///   String get sensorId => 'gps_sensor';
///   // ... implement other methods
/// }
/// ```
abstract class BaseSensor<T> {
  /// Unique sensor identifier
  ///
  /// Used to track sensor status and coordinate multiple sensors.
  /// Should be lowercase with underscores (e.g., 'gps_sensor', 'accelerometer').
  String get sensorId;

  /// Human-readable sensor name
  ///
  /// Displayed in UI when showing sensor status.
  String get sensorName;

  /// Current sensor status
  ///
  /// Indicates whether sensor is available, denied, active, etc.
  SensorStatus get status;

  /// Stream of status changes
  ///
  /// Emits new status whenever sensor availability or state changes.
  /// Useful for reactive UI updates and permission monitoring.
  Stream<SensorStatus> get onStatusChanged;

  /// Stream of sensor data (only active when sensor is streaming)
  ///
  /// Emits sensor-specific data (e.g., GPS points, step counts).
  /// Only active when sensor is in streaming mode.
  Stream<T> get onDataStream;

  /// Initialize sensor and check availability
  ///
  /// Called once on app startup. Checks:
  /// - Device hardware availability
  /// - Current permission status
  /// - Service availability (e.g., location services)
  ///
  /// Returns true if sensor is available on device.
  /// Updates [status] based on initialization result.
  Future<bool> initialize();

  /// Request necessary permissions
  ///
  /// Prompts user for required permissions.
  /// Returns true if permissions granted.
  ///
  /// May throw [SensorException] if services unavailable or
  /// permanently denied.
  Future<bool> requestPermissions();

  /// Start streaming sensor data
  ///
  /// Begins emitting data on [onDataStream].
  /// Optional sessionId parameter associates data with specific session.
  ///
  /// Throws [SensorException] if:
  /// - Sensor not available
  /// - Permission denied
  /// - Hardware error
  Future<void> startStreaming({String? sessionId});

  /// Stop streaming sensor data
  ///
  /// Stops [onDataStream] and releases sensor resources.
  /// Safe to call multiple times.
  Future<void> stopStreaming();

  /// Dispose resources
  ///
  /// Cleans up streams, subscriptions, and sensor connections.
  /// Called when sensor is no longer needed.
  /// Must be implemented by all sensors.
  Future<void> dispose();

  /// Check if sensor hardware is available on device
  ///
  /// Returns true if device has required hardware (e.g., GPS chip).
  /// Does not check permissions.
  Future<bool> isAvailable();

  /// Check if permissions are granted
  ///
  /// Returns true if all required permissions granted.
  /// Does not request permissions.
  Future<bool> hasPermission();
}
