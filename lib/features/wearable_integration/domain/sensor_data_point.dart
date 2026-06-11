import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'enums.dart';

/// Generic sensor reading that all sensors emit
/// Used for biometric data (heart rate, HRV, SpO2) and motion data (cadence, power, steps)
class SensorDataPoint {
  /// Unique identifier for this data point
  final String id;

  /// Session ID this reading belongs to
  final String sessionId;

  /// Device ID that produced this reading (nullable for Health API data)
  final String? deviceId;

  /// Type of sensor
  final SensorType sensorType;

  /// The actual sensor value (e.g., 150 for heart rate in BPM)
  final double value;

  /// Timestamp when this reading was captured
  final DateTime timestamp;

  /// Quality indicator (0-1, where 1 is highest quality)
  final double? accuracy;

  /// Additional metadata (e.g., RR intervals for HRV, cadence for power data)
  final Map<String, dynamic>? metadata;

  /// When this record was created in the local database
  final DateTime createdAt;

  SensorDataPoint({
    String? id,
    required this.sessionId,
    this.deviceId,
    required this.sensorType,
    required this.value,
    DateTime? timestamp,
    this.accuracy,
    this.metadata,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  SensorDataPoint copyWith({
    String? id,
    String? sessionId,
    String? deviceId,
    SensorType? sensorType,
    double? value,
    DateTime? timestamp,
    double? accuracy,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return SensorDataPoint(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      sensorType: sensorType ?? this.sensorType,
      value: value ?? this.value,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON for database storage (biometric or motion table)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'device_id': deviceId,
      'sensor_type': sensorType.toJson(),
      'value': value,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'accuracy': accuracy,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON (database row)
  factory SensorDataPoint.fromJson(Map<String, dynamic> json) {
    return SensorDataPoint(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      deviceId: json['device_id'] as String?,
      sensorType: SensorType.fromJson(json['sensor_type'] as String),
      value: (json['value'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
      metadata: json['metadata'] != null
          ? jsonDecode(json['metadata'] as String) as Map<String, dynamic>
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  /// Get formatted value with unit
  String get formattedValue {
    final valueStr =
        sensorType == SensorType.heartRate ||
            sensorType == SensorType.steps ||
            sensorType == SensorType.cadence
        ? value.round().toString()
        : value.toStringAsFixed(1);

    return '$valueStr ${sensorType.unit}';
  }

  /// Whether this is from a BLE device (vs Health API)
  bool get isFromBleDevice => deviceId != null;

  /// Whether this is biometric data
  bool get isBiometric => sensorType.isBiometric;

  /// Whether this is motion data
  bool get isMotion => sensorType.isMotion;

  @override
  String toString() {
    return 'SensorDataPoint(type: ${sensorType.displayName}, value: $formattedValue, '
        'timestamp: $timestamp, sessionId: $sessionId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SensorDataPoint &&
        other.id == id &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode => id.hashCode ^ sessionId.hashCode;
}

/// Summary of sensor data for a session
/// Stored permanently after session ends, even after detailed readings are deleted
class SessionSensorSummary {
  /// Unique identifier
  final String id;

  /// Session ID this summary belongs to
  final String sessionId;

  // Heart rate statistics
  final double? avgHeartRate;
  final int? maxHeartRate;
  final int? minHeartRate;
  final double? avgHeartRateVariability;

  /// Time in each heart rate zone (seconds) - JSON: {zone1: 300, zone2: 900, ...}
  final Map<String, int>? heartRateZones;

  // Motion statistics
  final int? totalSteps;
  final double? avgCadence;
  final double? avgPower;

  // Energy
  final double? caloriesBurned;

  /// Data sources that contributed to this summary
  /// e.g., ['ble:polar-h10', 'healthConnect']
  final List<String>? dataSources;

  final DateTime createdAt;
  final DateTime updatedAt;

  SessionSensorSummary({
    String? id,
    required this.sessionId,
    this.avgHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.avgHeartRateVariability,
    this.heartRateZones,
    this.totalSteps,
    this.avgCadence,
    this.avgPower,
    this.caloriesBurned,
    this.dataSources,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create a copy with updated fields
  SessionSensorSummary copyWith({
    String? id,
    String? sessionId,
    double? avgHeartRate,
    int? maxHeartRate,
    int? minHeartRate,
    double? avgHeartRateVariability,
    Map<String, int>? heartRateZones,
    int? totalSteps,
    double? avgCadence,
    double? avgPower,
    double? caloriesBurned,
    List<String>? dataSources,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionSensorSummary(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      avgHeartRateVariability:
          avgHeartRateVariability ?? this.avgHeartRateVariability,
      heartRateZones: heartRateZones ?? this.heartRateZones,
      totalSteps: totalSteps ?? this.totalSteps,
      avgCadence: avgCadence ?? this.avgCadence,
      avgPower: avgPower ?? this.avgPower,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      dataSources: dataSources ?? this.dataSources,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'avg_heart_rate': avgHeartRate,
      'max_heart_rate': maxHeartRate,
      'min_heart_rate': minHeartRate,
      'avg_heart_rate_variability': avgHeartRateVariability,
      'heart_rate_zones': heartRateZones != null
          ? jsonEncode(heartRateZones)
          : null,
      'total_steps': totalSteps,
      'avg_cadence': avgCadence,
      'avg_power': avgPower,
      'calories_burned': caloriesBurned,
      'data_sources': dataSources != null ? jsonEncode(dataSources) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON (database row)
  factory SessionSensorSummary.fromJson(Map<String, dynamic> json) {
    return SessionSensorSummary(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      avgHeartRate: json['avg_heart_rate'] != null
          ? (json['avg_heart_rate'] as num).toDouble()
          : null,
      maxHeartRate: json['max_heart_rate'] as int?,
      minHeartRate: json['min_heart_rate'] as int?,
      avgHeartRateVariability: json['avg_heart_rate_variability'] != null
          ? (json['avg_heart_rate_variability'] as num).toDouble()
          : null,
      heartRateZones: json['heart_rate_zones'] != null
          ? Map<String, int>.from(
              jsonDecode(json['heart_rate_zones'] as String) as Map,
            )
          : null,
      totalSteps: json['total_steps'] as int?,
      avgCadence: json['avg_cadence'] != null
          ? (json['avg_cadence'] as num).toDouble()
          : null,
      avgPower: json['avg_power'] != null
          ? (json['avg_power'] as num).toDouble()
          : null,
      caloriesBurned: json['calories_burned'] != null
          ? (json['calories_burned'] as num).toDouble()
          : null,
      dataSources: json['data_sources'] != null
          ? List<String>.from(
              jsonDecode(json['data_sources'] as String) as List,
            )
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  /// Whether this session has any heart rate data
  bool get hasHeartRateData =>
      avgHeartRate != null || maxHeartRate != null || minHeartRate != null;

  /// Whether this session has any motion data
  bool get hasMotionData =>
      totalSteps != null || avgCadence != null || avgPower != null;

  @override
  String toString() {
    return 'SessionSensorSummary(sessionId: $sessionId, avgHR: $avgHeartRate, '
        'steps: $totalSteps, calories: $caloriesBurned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionSensorSummary &&
        other.id == id &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode => id.hashCode ^ sessionId.hashCode;
}
