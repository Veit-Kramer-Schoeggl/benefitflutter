import 'dart:io';
import 'package:health/health.dart' as health;
import 'package:uuid/uuid.dart';
import '../../domain/wearable_device.dart';
import '../../domain/health_data_type.dart' as domain;
import '../../domain/enums.dart';
import '../../domain/sensor_data_point.dart';
import '../../domain/repositories/wearable_repository.dart';

/// Data source for HealthKit (iOS)
/// Implements WearableRepository to provide access to iOS health data
class HealthKitSource implements WearableRepository {
  final health.Health _health = health.Health();
  final Uuid _uuid = const Uuid();

  @override
  IntegrationSource get source => IntegrationSource.healthKit;

  /// Get the virtual HealthKit device
  @override
  Future<List<WearableDevice>> getAvailableDevices() async {
    if (!Platform.isIOS) return [];

    // HealthKit is always available on iOS
    return [
      WearableDevice(
        id: 'healthkit',
        userId: '', // Will be set by caller
        name: 'Apple Health',
        type: WearableDeviceType.healthPlatform,
        source: IntegrationSource.healthKit,
        status: ConnectionStatus.disconnected,
        capabilities: [
          SensorType.heartRate,
          SensorType.steps,
          SensorType.distance,
          SensorType.calories,
          SensorType.heartRateVariability,
        ],
      ),
    ];
  }

  /// Get connected devices (HealthKit is always "connected" if permissions granted)
  @override
  Future<List<WearableDevice>> getConnectedDevices() async {
    if (!Platform.isIOS) return [];

    final hasPerms = await hasPermissions();
    if (!hasPerms) return [];

    final devices = await getAvailableDevices();
    return devices
        .map((d) => d.copyWith(status: ConnectionStatus.connected))
        .toList();
  }

  /// Connect to HealthKit (request permissions)
  @override
  Future<void> connectDevice(String deviceId) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('HealthKit is only available on iOS');
    }

    await requestPermissions();
  }

  /// Disconnect from HealthKit (no-op, can't really disconnect)
  @override
  Future<void> disconnectDevice(String deviceId) async {
    // HealthKit doesn't have a disconnect concept
    // Permissions remain granted until user revokes them in settings
  }

  /// Request HealthKit permissions
  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isIOS) return false;

    final types = [
      health.HealthDataType.HEART_RATE,
      health.HealthDataType.STEPS,
      health.HealthDataType.DISTANCE_WALKING_RUNNING,
      health.HealthDataType.ACTIVE_ENERGY_BURNED,
      health.HealthDataType.WEIGHT,
      health.HealthDataType.HEIGHT,
      health.HealthDataType.RESTING_HEART_RATE,
      health.HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      health.HealthDataType.BLOOD_OXYGEN,
      health.HealthDataType.WORKOUT,
    ];

    final permissions = types
        .map((type) => health.HealthDataAccess.READ)
        .toList();

    try {
      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Check if permissions are granted
  @override
  Future<bool> hasPermissions() async {
    if (!Platform.isIOS) return false;

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

  /// Get sensor data stream (HealthKit doesn't support real-time streaming)
  @override
  Stream<SensorDataPoint>? getSensorStream(String deviceId, SensorType type) {
    // HealthKit doesn't support real-time streaming
    // Use getHistoricalData instead
    return null;
  }

  /// Start streaming (HealthKit doesn't support real-time streaming)
  @override
  Future<void> startStreaming(String deviceId, SensorType type) async {
    // No-op: HealthKit doesn't support real-time streaming
  }

  /// Stop streaming (HealthKit doesn't support real-time streaming)
  @override
  Future<void> stopStreaming(String deviceId, SensorType type) async {
    // No-op: HealthKit doesn't support real-time streaming
  }

  /// Get historical health data
  @override
  Future<List<domain.HealthDataPoint>> getHistoricalData(
    domain.HealthDataType dataType,
    DateTime startTime,
    DateTime endTime,
  ) async {
    if (!Platform.isIOS) return [];

    final healthType = _mapToHealthType(dataType);
    if (healthType == null) return [];

    try {
      final healthDataPoints = await _health.getHealthDataFromTypes(
        types: [healthType],
        startTime: startTime,
        endTime: endTime,
      );

      return healthDataPoints
          .map((point) => _convertHealthDataPoint(point, '', dataType))
          .toList();
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
    if (!Platform.isIOS) return [];

    final healthTypes = dataTypes
        .map(_mapToHealthType)
        .whereType<health.HealthDataType>()
        .toList();
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
    // HealthKit doesn't track sync times internally
    // This should be managed by the app's HealthSyncService
    return null;
  }

  /// Sync now (trigger data fetch)
  @override
  Future<void> syncNow() async {
    // HealthKit sync is handled by the OS
    // This is a no-op, but could trigger a manual data fetch in the future
  }

  /// Get battery level (HealthKit doesn't provide battery info)
  @override
  Future<int?> getBatteryLevel(String deviceId) async {
    return null;
  }

  /// Get signal strength (HealthKit doesn't have signal strength)
  @override
  Future<int?> getSignalStrength(String deviceId) async {
    return null;
  }

  /// Cleanup and dispose resources
  @override
  Future<void> dispose() async {
    // No resources to dispose for HealthKit
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
        return health.HealthDataType.DISTANCE_WALKING_RUNNING;
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
      case health.HealthDataType.DISTANCE_WALKING_RUNNING:
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
      value = (point.value as health.NumericHealthValue).numericValue
          .toString();
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
