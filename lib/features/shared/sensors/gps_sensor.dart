import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:benefitflutter/features/shared/sensors/base_sensor.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_status.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_exception.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';

/// GPS sensor implementation using geolocator
///
/// Provides real-time GPS location data as a stream of GpsPoint objects.
/// Handles permission requests and location service availability.
///
/// Key features:
/// - Automatic permission handling
/// - Quality filtering based on GPS accuracy
/// - Configurable frequency (time and distance based)
/// - Stream-based real-time updates
class GpsSensor extends BaseSensor<GpsPoint> {
  // Controllers
  final _statusController = StreamController<SensorStatus>.broadcast();
  final _dataController = StreamController<GpsPoint>.broadcast();

  // State
  SensorStatus _status = SensorStatus.unavailable;
  StreamSubscription<Position>? _positionSubscription;

  // Session tracking
  String? _currentSessionId;

  @override
  String get sensorId => 'gps_sensor';

  @override
  String get sensorName => 'GPS Location';

  @override
  SensorStatus get status => _status;

  @override
  Stream<SensorStatus> get onStatusChanged => _statusController.stream;

  @override
  Stream<GpsPoint> get onDataStream => _dataController.stream;

  // ===== INITIALIZATION =====

  @override
  Future<bool> initialize() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateStatus(SensorStatus.unavailable);
        return false;
      }

      // Check permissions
      final hasPermission = await this.hasPermission();
      if (hasPermission) {
        _updateStatus(SensorStatus.available);
        return true;
      }

      // Check if permanently denied
      final permission = await Permission.location.status;
      if (permission.isPermanentlyDenied) {
        _updateStatus(SensorStatus.permanentlyDenied);
      } else {
        _updateStatus(SensorStatus.denied);
      }

      return false;
    } catch (e) {
      _updateStatus(SensorStatus.error);
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<bool> hasPermission() async {
    final permission = await Permission.location.status;
    return permission.isGranted;
  }

  // ===== PERMISSION HANDLING =====

  @override
  Future<bool> requestPermissions() async {
    try {
      // Check if location services enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateStatus(SensorStatus.unavailable);

        // Prompt user to enable location services
        throw SensorException(
          message: 'Location services are disabled. Please enable in settings.',
          sensorId: sensorId,
          type: SensorExceptionType.unavailable,
        );
      }

      // Request permission
      final permission = await Permission.location.request();

      if (permission.isGranted) {
        _updateStatus(SensorStatus.available);
        return true;
      } else if (permission.isPermanentlyDenied) {
        _updateStatus(SensorStatus.permanentlyDenied);
        return false;
      } else {
        _updateStatus(SensorStatus.denied);
        return false;
      }
    } catch (e) {
      _updateStatus(SensorStatus.error);
      return false;
    }
  }

  // ===== STREAMING =====

  @override
  Future<void> startStreaming({String? sessionId}) async {
    // Guard: Check status
    if (_status != SensorStatus.available) {
      throw SensorException(
        message: 'GPS sensor not available. Status: $_status',
        sensorId: sensorId,
        type: SensorExceptionType.streamingFailed,
      );
    }

    // Guard: Already streaming
    if (_positionSubscription != null) {
      return;
    }

    try {
      _currentSessionId = sessionId;
      _updateStatus(SensorStatus.active);

      // Configure location settings
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Minimum 5 meters between updates
        // TODO: Consider adding timeLimit for production (e.g., 60 seconds)
        // Currently removed because:
        // 1. Emulator doesn't send continuous updates (needs manual location changes)
        // 2. 10 seconds was too aggressive - caused errors during normal use
        // 3. Real devices might need longer timeout for GPS acquisition
        // Recommendation: Test on real device first, then decide if timeout needed
      );

      // Start position stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: _onPositionError,
        cancelOnError: false,
      );
    } catch (e) {
      _updateStatus(SensorStatus.error);
      throw SensorException(
        message: 'Failed to start GPS streaming: $e',
        sensorId: sensorId,
        type: SensorExceptionType.streamingFailed,
      );
    }
  }

  @override
  Future<void> stopStreaming() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _currentSessionId = null;

    // Reset to available if we were tracking (active or error during tracking)
    if (_status == SensorStatus.active || _status == SensorStatus.error) {
      _updateStatus(SensorStatus.available);
    }
  }

  // ===== POSITION HANDLING =====

  void _onPositionUpdate(Position position) {
    // Convert Position to GpsPoint
    final gpsPoint = GpsPoint(
      id: const Uuid().v4(),
      sessionId: _currentSessionId ?? 'unknown',
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracyMeters: position.accuracy,
      speedMetersPerSecond: position.speed,
      timestamp: position.timestamp,
    );

    // Quality check
    if (!gpsPoint.meetsQualityRequirements()) {
      // Skip low-quality points
      return;
    }

    // Emit GPS point
    _dataController.add(gpsPoint);
  }

  void _onPositionError(dynamic error) {
    // Handle position stream errors
    debugPrint('GPS Sensor Error: $error');
    _updateStatus(SensorStatus.error);
  }

  // ===== LIFECYCLE =====

  @override
  Future<void> dispose() async {
    await stopStreaming();
    await _statusController.close();
    await _dataController.close();
  }

  // ===== HELPERS =====

  void _updateStatus(SensorStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
    }
  }
}
