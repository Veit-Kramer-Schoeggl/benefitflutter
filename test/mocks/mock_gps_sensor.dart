import 'dart:async';
import 'package:benefitflutter/features/shared/sensors/base_sensor.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_status.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';

/// Mock GPS sensor for testing
///
/// Provides full control over GPS sensor behavior in tests:
/// - Control when data is emitted
/// - Simulate permission states
/// - Simulate errors
/// - Test status changes
///
/// Usage:
/// ```dart
/// final mockSensor = MockGpsSensor();
/// await mockSensor.initialize();
/// await mockSensor.startStreaming(sessionId: 'test-123');
///
/// // Emit test data
/// mockSensor.emitMockPoint(testGpsPoint);
///
/// // Simulate error
/// mockSensor.simulateError('GPS unavailable');
/// ```
class MockGpsSensor extends BaseSensor<GpsPoint> {
  // Controllers
  final _statusController = StreamController<SensorStatus>.broadcast();
  final _dataController = StreamController<GpsPoint>.broadcast();

  // State
  SensorStatus _status = SensorStatus.available;
  bool _isStreaming = false;
  String? _currentSessionId;

  // Test configuration
  bool _permissionGranted = true;
  bool _hardwareAvailable = true;

  @override
  String get sensorId => 'mock_gps_sensor';

  @override
  String get sensorName => 'Mock GPS';

  @override
  SensorStatus get status => _status;

  @override
  Stream<SensorStatus> get onStatusChanged => _statusController.stream;

  @override
  Stream<GpsPoint> get onDataStream => _dataController.stream;

  /// Check if sensor is currently streaming
  bool get isStreaming => _isStreaming;

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  // ===== INITIALIZATION =====

  @override
  Future<bool> initialize() async {
    if (!_hardwareAvailable) {
      _updateStatus(SensorStatus.unavailable);
      return false;
    }

    if (_permissionGranted) {
      _updateStatus(SensorStatus.available);
      return true;
    } else {
      _updateStatus(SensorStatus.denied);
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    return _hardwareAvailable;
  }

  @override
  Future<bool> hasPermission() async {
    return _permissionGranted;
  }

  // ===== PERMISSION HANDLING =====

  @override
  Future<bool> requestPermissions() async {
    // In mock, simulate user granting permission if not permanently denied
    if (_status == SensorStatus.permanentlyDenied) {
      return false;
    }

    if (_permissionGranted) {
      _updateStatus(SensorStatus.available);
      return true;
    }

    // Simulate denied
    _updateStatus(SensorStatus.denied);
    return false;
  }

  // ===== STREAMING =====

  @override
  Future<void> startStreaming({String? sessionId}) async {
    if (_status != SensorStatus.available) {
      throw Exception('Mock GPS sensor not available. Status: $_status');
    }

    _isStreaming = true;
    _currentSessionId = sessionId;
    _updateStatus(SensorStatus.active);
  }

  @override
  Future<void> stopStreaming() async {
    _isStreaming = false;
    _currentSessionId = null;

    if (_status == SensorStatus.active) {
      _updateStatus(SensorStatus.available);
    }
  }

  // ===== LIFECYCLE =====

  @override
  Future<void> dispose() async {
    await stopStreaming();
    await _statusController.close();
    await _dataController.close();
  }

  // ===== TEST HELPERS =====

  /// Emit a mock GPS point on the data stream
  ///
  /// Only emits if sensor is currently streaming.
  /// Use this to simulate receiving GPS data in tests.
  void emitMockPoint(GpsPoint point) {
    if (_isStreaming) {
      _dataController.add(point);
    }
  }

  /// Simulate a GPS error
  ///
  /// Updates sensor status to error and emits error on data stream.
  void simulateError(String errorMessage) {
    _updateStatus(SensorStatus.error);
    _dataController.addError(Exception(errorMessage));
  }

  /// Configure whether hardware is available
  ///
  /// Must be called before initialize() to take effect.
  void setHardwareAvailable(bool available) {
    _hardwareAvailable = available;
  }

  /// Configure whether permission is granted
  ///
  /// Must be called before initialize() to take effect.
  void setPermissionGranted(bool granted) {
    _permissionGranted = granted;
  }

  /// Simulate permanent permission denial
  ///
  /// Sets status to permanentlyDenied. Permission requests will fail.
  void setPermanentlyDenied() {
    _permissionGranted = false;
    _updateStatus(SensorStatus.permanentlyDenied);
  }

  /// Reset sensor to initial state
  ///
  /// Useful for resetting between test cases.
  void reset() {
    _isStreaming = false;
    _currentSessionId = null;
    _permissionGranted = true;
    _hardwareAvailable = true;
    _status = SensorStatus.available;
  }

  // ===== HELPERS =====

  void _updateStatus(SensorStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
    }
  }
}
