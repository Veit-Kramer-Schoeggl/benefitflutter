import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart' as health;
import 'package:uuid/uuid.dart';
import '../../domain/wearable_device.dart';
import '../../domain/health_data_type.dart' as domain;
import '../../domain/enums.dart';
import '../../domain/sensor_data_point.dart';
import '../../domain/repositories/wearable_repository.dart';

/// Data source for Health Connect (Android)
/// Implements WearableRepository to provide access to Android health data
class HealthConnectSource implements WearableRepository {
  final health.Health _health = health.Health();
  final Uuid _uuid = const Uuid();

  @override
  IntegrationSource get source => IntegrationSource.healthConnect;

  /// Get the virtual Health Connect device
  @override
  Future<List<WearableDevice>> getAvailableDevices() async {
    if (!Platform.isAndroid) return [];

    // Health Connect is always available on Android (note: package doesn't have isInstalled check)
    // Users must have Health Connect app installed, which will be checked during permissions
    return [
      WearableDevice(
        id: 'health-connect',
        userId: '', // Will be set by caller
        name: 'Health Connect',
        type: WearableDeviceType.healthPlatform,
        source: IntegrationSource.healthConnect,
        status: ConnectionStatus.disconnected,
        capabilities: [
          SensorType.heartRate,
          SensorType.steps,
          SensorType.distance,
          SensorType.calories,
          // Note: HRV not supported by Health Connect
        ],
      ),
    ];
  }

  /// Get connected devices (Health Connect is always "connected" if permissions granted)
  @override
  Future<List<WearableDevice>> getConnectedDevices() async {
    if (!Platform.isAndroid) return [];

    final hasPerms = await hasPermissions();
    if (!hasPerms) return [];

    final devices = await getAvailableDevices();
    return devices.map((d) => d.copyWith(status: ConnectionStatus.connected)).toList();
  }

  /// Connect to Health Connect (request permissions)
  @override
  Future<void> connectDevice(String deviceId) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Health Connect is only available on Android');
    }

    await requestPermissions();
  }

  /// Disconnect from Health Connect (no-op, can't really disconnect)
  @override
  Future<void> disconnectDevice(String deviceId) async {
    // Health Connect doesn't have a disconnect concept
    // Permissions remain granted until user revokes them in settings
  }

  /// Request Health Connect permissions
  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;

    // Only request data types that are definitely supported by Health Connect
    final types = [
      health.HealthDataType.HEART_RATE,
      health.HealthDataType.STEPS,
      health.HealthDataType.DISTANCE_DELTA,
      health.HealthDataType.ACTIVE_ENERGY_BURNED,
      health.HealthDataType.WEIGHT,
      health.HealthDataType.HEIGHT,
      health.HealthDataType.BLOOD_OXYGEN,
      // Note: HEART_RATE_VARIABILITY_SDNN and RESTING_HEART_RATE
      // are not supported by Health Connect
    ];

    final permissions = types.map((type) => health.HealthDataAccess.READ).toList();

    try {
      final granted = await _health.requestAuthorization(types, permissions: permissions);
      return granted;
    } catch (e) {
      debugPrint('[HealthConnect] Permission request failed: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  @override
  Future<bool> hasPermissions() async {
    if (!Platform.isAndroid) return false;

    final types = [
      health.HealthDataType.HEART_RATE,
      health.HealthDataType.STEPS,
    ];

    try {
      final granted = await _health.hasPermissions(types);
      return granted ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if Health Connect is installed on the device
  Future<bool> isHealthConnectInstalled() async {
    if (!Platform.isAndroid) return false;

    try {
      // Try to check permissions - if Health Connect is not installed, this will fail
      final types = [health.HealthDataType.STEPS];
      await _health.hasPermissions(types);
      return true;
    } catch (e) {
      // If we get an error about permission launcher, HC is not installed
      return !e.toString().toLowerCase().contains('permission launcher not found');
    }
  }

  /// Get sensor data stream (Health Connect doesn't support real-time streaming)
  @override
  Stream<SensorDataPoint>? getSensorStream(String deviceId, SensorType type) {
    // Health Connect doesn't support real-time streaming
    // Use getHistoricalData instead
    return null;
  }

  /// Start streaming (Health Connect doesn't support real-time streaming)
  @override
  Future<void> startStreaming(String deviceId, SensorType type) async {
    // No-op: Health Connect doesn't support real-time streaming
  }

  /// Stop streaming (Health Connect doesn't support real-time streaming)
  @override
  Future<void> stopStreaming(String deviceId, SensorType type) async {
    // No-op: Health Connect doesn't support real-time streaming
  }

  /// Get historical health data
  @override
  Future<List<domain.HealthDataPoint>> getHistoricalData(
    domain.HealthDataType dataType,
    DateTime startTime,
    DateTime endTime,
  ) async {
    if (!Platform.isAndroid) return [];

    final healthType = _mapToHealthType(dataType);
    if (healthType == null) return [];

    try {
      final healthDataPoints = await _health.getHealthDataFromTypes(
        types: [healthType],
        startTime: startTime,
        endTime: endTime,
      );

      return healthDataPoints.map((point) => _convertHealthDataPoint(point, '', dataType)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get multiple types of health data at once
  Future<List<domain.HealthDataPoint>> getMultipleTypes(
    String userId,
    List<domain.HealthDataType> dataTypes,
    DateTime startTime,
    DateTime endTime,
  ) async {
    if (!Platform.isAndroid) return [];

    final healthTypes = dataTypes.map(_mapToHealthType).whereType<health.HealthDataType>().toList();
    if (healthTypes.isEmpty) return [];

    try {
      final healthDataPoints = await _health.getHealthDataFromTypes(
        types: healthTypes,
        startTime: startTime,
        endTime: endTime,
      );

      return healthDataPoints.map((point) {
        final dataType = _mapFromHealthType(point.type);
        return _convertHealthDataPoint(point, userId, dataType);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get last sync time
  @override
  Future<DateTime?> getLastSyncTime() async {
    // Health Connect doesn't track sync times internally
    // This should be managed by the app's HealthSyncService
    return null;
  }

  /// Sync now (trigger data fetch)
  @override
  Future<void> syncNow() async {
    // Health Connect sync is handled by the OS
    // This is a no-op, but could trigger a manual data fetch in the future
  }

  /// Get battery level (Health Connect doesn't provide battery info)
  @override
  Future<int?> getBatteryLevel(String deviceId) async {
    return null;
  }

  /// Get signal strength (Health Connect doesn't have signal strength)
  @override
  Future<int?> getSignalStrength(String deviceId) async {
    return null;
  }

  /// Cleanup and dispose resources
  @override
  Future<void> dispose() async {
    // No resources to dispose for Health Connect
  }

  // ========================================
  // PRIVATE HELPERS
  // ========================================

  /// Map app HealthDataType to health package HealthDataType
  health.HealthDataType? _mapToHealthType(domain.HealthDataType dataType) {
    switch (dataType) {
      case domain.HealthDataType.steps:
        return health.HealthDataType.STEPS;
      case domain.HealthDataType.heartRate:
        return health.HealthDataType.HEART_RATE;
      case domain.HealthDataType.distance:
        return health.HealthDataType.DISTANCE_DELTA;
      case domain.HealthDataType.calories:
        return health.HealthDataType.ACTIVE_ENERGY_BURNED;
      case domain.HealthDataType.weight:
        return health.HealthDataType.WEIGHT;
      case domain.HealthDataType.restingHeartRate:
        return health.HealthDataType.RESTING_HEART_RATE;
      case domain.HealthDataType.heartRateVariability:
        return health.HealthDataType.HEART_RATE_VARIABILITY_SDNN;
      case domain.HealthDataType.bloodOxygen:
        return health.HealthDataType.BLOOD_OXYGEN;
      case domain.HealthDataType.vo2Max:
        // VO2_MAX not available in current health package version
        return null;
      case domain.HealthDataType.sleep:
        return health.HealthDataType.SLEEP_SESSION;
      default:
        return null;
    }
  }

  /// Map health package HealthDataType to app HealthDataType
  domain.HealthDataType _mapFromHealthType(health.HealthDataType healthType) {
    switch (healthType) {
      case health.HealthDataType.STEPS:
        return domain.HealthDataType.steps;
      case health.HealthDataType.HEART_RATE:
        return domain.HealthDataType.heartRate;
      case health.HealthDataType.DISTANCE_DELTA:
        return domain.HealthDataType.distance;
      case health.HealthDataType.ACTIVE_ENERGY_BURNED:
      case health.HealthDataType.TOTAL_CALORIES_BURNED:
        return domain.HealthDataType.calories;
      case health.HealthDataType.WEIGHT:
        return domain.HealthDataType.weight;
      case health.HealthDataType.RESTING_HEART_RATE:
        return domain.HealthDataType.restingHeartRate;
      case health.HealthDataType.HEART_RATE_VARIABILITY_SDNN:
        return domain.HealthDataType.heartRateVariability;
      case health.HealthDataType.BLOOD_OXYGEN:
        return domain.HealthDataType.bloodOxygen;
      // case health.HealthDataType.VO2_MAX:
      //   return domain.HealthDataType.vo2Max;
      case health.HealthDataType.SLEEP_SESSION:
      case health.HealthDataType.SLEEP_ASLEEP:
      case health.HealthDataType.SLEEP_AWAKE:
        return domain.HealthDataType.sleep;
      default:
        return domain.HealthDataType.steps; // Fallback
    }
  }

  /// Convert health package HealthDataPoint to app HealthDataPoint
  domain.HealthDataPoint _convertHealthDataPoint(
    health.HealthDataPoint point,
    String userId,
    domain.HealthDataType dataType,
  ) {
    // Extract value based on type
    String value;
    if (point.value is health.NumericHealthValue) {
      value = (point.value as health.NumericHealthValue).numericValue.toString();
    } else if (point.value is health.WorkoutHealthValue) {
      final workout = point.value as health.WorkoutHealthValue;
      value = workout.toString();
    } else {
      value = point.value.toString();
    }

    return domain.HealthDataPoint(
      id: _uuid.v4(),
      userId: userId,
      dataType: dataType,
      value: value,
      startTime: point.dateFrom,
      endTime: point.dateTo,
      sourceApp: point.sourceName,
      syncedAt: DateTime.now(),
    );
  }
}
