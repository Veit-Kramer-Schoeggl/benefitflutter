import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Maps to Health Connect / HealthKit data types
/// These are historical/background data synced from health platforms
enum HealthDataType {
  /// Daily step count
  steps,

  /// Heart rate readings (BPM)
  heartRate,

  /// Heart rate variability (milliseconds)
  heartRateVariability,

  /// Distance traveled (meters)
  distance,

  /// Calories burned (kcal)
  calories,

  /// Sleep data (duration, stages)
  sleep,

  /// Body weight (kg)
  weight,

  /// Blood oxygen saturation (%)
  bloodOxygen,

  /// VO2 Max estimate (ml/kg/min)
  vo2Max,

  /// Resting heart rate (BPM)
  restingHeartRate,

  /// Active energy burned (kcal)
  activeEnergyBurned,

  /// Workout/exercise session
  workout;

  /// Convert to string for database storage
  String toJson() => name;

  /// Create from string
  static HealthDataType fromJson(String json) {
    return HealthDataType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => throw ArgumentError('Unknown health data type: $json'),
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case HealthDataType.steps:
        return 'Steps';
      case HealthDataType.heartRate:
        return 'Heart Rate';
      case HealthDataType.heartRateVariability:
        return 'Heart Rate Variability';
      case HealthDataType.distance:
        return 'Distance';
      case HealthDataType.calories:
        return 'Calories';
      case HealthDataType.sleep:
        return 'Sleep';
      case HealthDataType.weight:
        return 'Weight';
      case HealthDataType.bloodOxygen:
        return 'Blood Oxygen';
      case HealthDataType.vo2Max:
        return 'VO2 Max';
      case HealthDataType.restingHeartRate:
        return 'Resting Heart Rate';
      case HealthDataType.activeEnergyBurned:
        return 'Active Energy';
      case HealthDataType.workout:
        return 'Workout';
    }
  }
}

/// Unified data model for health platform data (Health Connect/HealthKit)
/// This is for historical data not tied to specific sessions
class HealthDataPoint {
  /// Unique identifier
  final String id;

  /// User ID this data belongs to
  final String userId;

  /// Type of health data
  final HealthDataType dataType;

  /// Value (can be simple or complex JSON)
  /// - Simple: "5000" for steps, "72" for heart rate
  /// - Complex: JSON for sleep stages, workout details
  final String value;

  /// Start time of the data period
  final DateTime startTime;

  /// End time of the data period
  final DateTime endTime;

  /// Source app that provided this data (e.g., "Google Fit", "Garmin Connect")
  final String? sourceApp;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// When this data was synced from the health platform
  final DateTime syncedAt;

  /// When this record was created in the local database
  final DateTime createdAt;

  HealthDataPoint({
    String? id,
    required this.userId,
    required this.dataType,
    required this.value,
    required this.startTime,
    required this.endTime,
    this.sourceApp,
    this.metadata,
    DateTime? syncedAt,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        syncedAt = syncedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  HealthDataPoint copyWith({
    String? id,
    String? userId,
    HealthDataType? dataType,
    String? value,
    DateTime? startTime,
    DateTime? endTime,
    String? sourceApp,
    Map<String, dynamic>? metadata,
    DateTime? syncedAt,
    DateTime? createdAt,
  }) {
    return HealthDataPoint(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dataType: dataType ?? this.dataType,
      value: value ?? this.value,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      sourceApp: sourceApp ?? this.sourceApp,
      metadata: metadata ?? this.metadata,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'data_type': dataType.toJson(),
      'value': value,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'source_app': sourceApp,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'synced_at': syncedAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON (database row)
  factory HealthDataPoint.fromJson(Map<String, dynamic> json) {
    return HealthDataPoint(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dataType: HealthDataType.fromJson(json['data_type'] as String),
      value: json['value'] as String,
      startTime:
          DateTime.fromMillisecondsSinceEpoch(json['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['end_time'] as int),
      sourceApp: json['source_app'] as String?,
      metadata: json['metadata'] != null
          ? jsonDecode(json['metadata'] as String) as Map<String, dynamic>
          : null,
      syncedAt: DateTime.fromMillisecondsSinceEpoch(json['synced_at'] as int),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  /// Get numeric value (for simple types like steps, heart rate)
  double? get numericValue {
    try {
      return double.parse(value);
    } catch (e) {
      return null;
    }
  }

  /// Get integer value (for types like steps)
  int? get intValue {
    try {
      return int.parse(value);
    } catch (e) {
      return null;
    }
  }

  /// Get complex value (for types like sleep, workout)
  Map<String, dynamic>? get complexValue {
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Duration of this data point
  Duration get duration => endTime.difference(startTime);

  /// Whether this is from today
  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  /// Whether this is from this week
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return startTime.isAfter(startOfWeek);
  }

  @override
  String toString() {
    return 'HealthDataPoint(type: ${dataType.displayName}, value: $value, '
        'period: ${startTime.toIso8601String()} - ${endTime.toIso8601String()}, '
        'source: $sourceApp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is HealthDataPoint &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}
