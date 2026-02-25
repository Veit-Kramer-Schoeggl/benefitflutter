import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:benefitflutter/features/shared/sensors/base_sensor.dart';
import 'package:benefitflutter/features/shared/sensors/gps_sensor.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_status.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';

/// Coordinator for managing multiple sensors
///
/// Central hub for all sensor operations. Responsibilities:
/// - Initialize all available sensors on app startup
/// - Handle permission requests across sensors
/// - Coordinate sensor lifecycle with sessions
/// - Provide unified interface for sensor access
///
/// Usage:
/// ```dart
/// final sensorManager = SensorManager();
/// await sensorManager.initialize();
/// await sensorManager.startSession(sessionId: 'abc', activityType: ActivityType.running);
/// ```
class SensorManager {
  // Sensors
  final BaseSensor<GpsPoint> _gpsSensor;

  // State
  bool _initialized = false;
  final Map<String, SensorStatus> _sensorStatuses = {};

  SensorManager({
    BaseSensor<GpsPoint>? gpsSensor,
  }) : _gpsSensor = gpsSensor ?? GpsSensor();

  // ===== GETTERS =====

  /// Get GPS sensor instance
  ///
  /// Use this to access GPS-specific methods or subscribe to data stream:
  /// ```dart
  /// sensorManager.gpsSensor.onDataStream.listen((gpsPoint) { ... });
  /// ```
  BaseSensor<GpsPoint> get gpsSensor => _gpsSensor;

  /// Check if manager is initialized
  bool get isInitialized => _initialized;

  /// Get status of all sensors
  ///
  /// Returns map of sensor ID → status
  Map<String, SensorStatus> get sensorStatuses =>
      Map.unmodifiable(_sensorStatuses);

  // ===== INITIALIZATION =====

  /// Initialize all sensors
  ///
  /// Checks device capabilities and loads user preferences.
  /// Should be called once on app startup before any other operations.
  ///
  /// Returns silently if already initialized.
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize GPS sensor
    await _gpsSensor.initialize();
    _sensorStatuses[_gpsSensor.sensorId] = _gpsSensor.status;

    // Subscribe to status changes
    _gpsSensor.onStatusChanged.listen((status) {
      _sensorStatuses[_gpsSensor.sensorId] = status;
    });

    // Future: Initialize other sensors (accelerometer, heart rate, etc.)
    // Example:
    // final accelAvailable = await _accelerometerSensor.initialize();
    // _sensorStatuses[_accelerometerSensor.sensorId] = _accelerometerSensor.status;

    _initialized = true;
  }

  // ===== SESSION MANAGEMENT =====

  /// Start session with specified activity type
  ///
  /// Starts all available sensors for the session.
  /// Returns map of sensor ID → success status.
  ///
  /// Automatically handles:
  /// - Permission requests (prompts user if needed)
  /// - Sensor availability checks
  /// - Starting sensor streams
  ///
  /// Example:
  /// ```dart
  /// final results = await sensorManager.startSession(
  ///   sessionId: session.id,
  ///   activityType: ActivityType.running,
  /// );
  /// if (results['gps'] == true) {
  ///   // GPS started successfully
  /// }
  /// ```
  Future<Map<String, bool>> startSession({
    required String sessionId,
    required ActivityType activityType,
  }) async {
    if (!_initialized) {
      throw StateError(
          'SensorManager not initialized. Call initialize() first.');
    }

    final results = <String, bool>{};

    // Start GPS sensor
    results['gps'] = await _startGpsSensor(sessionId);

    // Future: Start accelerometer if available
    // results['accelerometer'] = await _startAccelerometer(sessionId);

    // Future: Start heart rate if available
    // results['heart_rate'] = await _startHeartRate(sessionId);

    return results;
  }

  /// Stop all active sensors
  ///
  /// Stops sensor streams and releases resources.
  /// Safe to call multiple times.
  Future<void> stopSession() async {
    // Stop GPS
    await _gpsSensor.stopStreaming();

    // Future: Stop other sensors
    // await _accelerometerSensor.stopStreaming();
    // await _heartRateSensor.stopStreaming();
  }

  /// Pause sensor streaming (but keep session active)
  ///
  /// For GPS, we typically keep streaming even when paused
  /// to maintain continuous track. Other sensors may pause.
  Future<void> pauseSession() async {
    // For GPS, we typically keep streaming even when paused
    // But you could implement different behavior here

    // Future: Pause other sensors if needed
    // await _accelerometerSensor.pauseStreaming();
  }

  /// Resume sensor streaming
  ///
  /// Resumes sensors that were paused (if any).
  Future<void> resumeSession() async {
    // GPS continues streaming, so no action needed

    // Future: Resume other sensors if needed
    // await _accelerometerSensor.resumeStreaming();
  }

  // ===== GPS SPECIFIC =====

  Future<bool> _startGpsSensor(String sessionId) async {
    try {
      // Check if available
      if (_gpsSensor.status == SensorStatus.denied ||
          _gpsSensor.status == SensorStatus.permanentlyDenied) {
        // Request permission
        final granted = await _gpsSensor.requestPermissions();
        if (!granted) return false;
      }

      // Start streaming
      await _gpsSensor.startStreaming(sessionId: sessionId);
      return true;
    } catch (e) {
      debugPrint('Failed to start GPS sensor: $e');
      return false;
    }
  }

  // ===== PERMISSION MANAGEMENT =====

  /// Request permissions for all sensors
  ///
  /// Prompts user for permissions across all sensors.
  /// Returns map of sensor ID → permission granted status.
  ///
  /// Useful for upfront permission requests before starting session.
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    // Request GPS permission
    results['gps'] = await _gpsSensor.requestPermissions();

    // Future: Request other permissions
    // results['accelerometer'] = await _accelerometerSensor.requestPermissions();
    // results['heart_rate'] = await _heartRateSensor.requestPermissions();

    return results;
  }

  /// Check which sensors have permissions
  ///
  /// Returns map of sensor ID → has permission status.
  /// Does not request permissions, only checks current state.
  Future<Map<String, bool>> checkAllPermissions() async {
    final results = <String, bool>{};

    results['gps'] = await _gpsSensor.hasPermission();

    // Future: Check other permissions
    // results['accelerometer'] = await _accelerometerSensor.hasPermission();
    // results['heart_rate'] = await _heartRateSensor.hasPermission();

    return results;
  }

  // ===== LIFECYCLE =====

  /// Dispose all sensors
  ///
  /// Cleans up resources and stops all streaming.
  /// Call when app is closing or sensor manager no longer needed.
  Future<void> dispose() async {
    await _gpsSensor.dispose();

    // Future: Dispose other sensors
    // await _accelerometerSensor.dispose();
    // await _heartRateSensor.dispose();

    _initialized = false;
  }
}
