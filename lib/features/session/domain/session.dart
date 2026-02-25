import 'dart:convert';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

/// Represents a tracking session (manual or continuous daily)
class Session {
  final String id;
  final String userId;
  final TrackingMode trackingMode;
  final ActivityType activityType;
  final SessionStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final double? distanceMeters;
  final DateTime? trackingDate; // Only for continuous_daily sessions
  final DateTime createdAt;

  // Wearable data fields (v4 - Wearable Integration)
  final int? avgHeartRate;
  final int? maxHeartRate;
  final int? minHeartRate;
  final double? avgHeartRateVariability;
  final int? totalSteps;
  final double? avgCadence;
  final double? caloriesBurned;
  final Map<String, int>? heartRateZones; // JSON: {zone1: 300, zone2: 900, ...}
  final bool hasWearableData;
  final List<String>? connectedDeviceIds;

  Session({
    required this.id,
    required this.userId,
    required this.trackingMode,
    required this.activityType,
    required this.status,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.distanceMeters,
    this.trackingDate,
    DateTime? createdAt,
    // Wearable data fields
    this.avgHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.avgHeartRateVariability,
    this.totalSteps,
    this.avgCadence,
    this.caloriesBurned,
    this.heartRateZones,
    this.hasWearableData = false,
    this.connectedDeviceIds,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create Session from JSON
  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      trackingMode: TrackingMode.fromJson(json['tracking_mode'] as String),
      activityType: ActivityType.fromJson(json['activity_type'] as String),
      status: SessionStatus.fromJson(json['status'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      distanceMeters: json['distance_meters'] != null
          ? (json['distance_meters'] as num).toDouble()
          : null,
      trackingDate: json['tracking_date'] != null
          ? DateTime.parse(json['tracking_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      // Wearable data fields
      avgHeartRate: json['avg_heart_rate'] as int?,
      maxHeartRate: json['max_heart_rate'] as int?,
      minHeartRate: json['min_heart_rate'] as int?,
      avgHeartRateVariability: json['avg_heart_rate_variability'] != null
          ? (json['avg_heart_rate_variability'] as num).toDouble()
          : null,
      totalSteps: json['total_steps'] as int?,
      avgCadence: json['avg_cadence'] != null
          ? (json['avg_cadence'] as num).toDouble()
          : null,
      caloriesBurned: json['calories_burned'] != null
          ? (json['calories_burned'] as num).toDouble()
          : null,
      heartRateZones: json['heart_rate_zones'] != null
          ? Map<String, int>.from(jsonDecode(json['heart_rate_zones'] as String))
          : null,
      hasWearableData: json['has_wearable_data'] == 1,
      connectedDeviceIds: json['connected_device_ids'] != null
          ? List<String>.from(jsonDecode(json['connected_device_ids'] as String))
          : null,
    );
  }

  /// Convert Session to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tracking_mode': trackingMode.toJson(),
      'activity_type': activityType.toJson(),
      'status': status.toJson(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'tracking_date': trackingDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      // Wearable data fields
      'avg_heart_rate': avgHeartRate,
      'max_heart_rate': maxHeartRate,
      'min_heart_rate': minHeartRate,
      'avg_heart_rate_variability': avgHeartRateVariability,
      'total_steps': totalSteps,
      'avg_cadence': avgCadence,
      'calories_burned': caloriesBurned,
      'heart_rate_zones': heartRateZones != null ? jsonEncode(heartRateZones) : null,
      'has_wearable_data': hasWearableData ? 1 : 0,
      'connected_device_ids': connectedDeviceIds != null ? jsonEncode(connectedDeviceIds) : null,
    };
  }

  /// Create a copy with modified fields
  Session copyWith({
    String? id,
    String? userId,
    TrackingMode? trackingMode,
    ActivityType? activityType,
    SessionStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? distanceMeters,
    DateTime? trackingDate,
    DateTime? createdAt,
    // Wearable data fields
    int? avgHeartRate,
    int? maxHeartRate,
    int? minHeartRate,
    double? avgHeartRateVariability,
    int? totalSteps,
    double? avgCadence,
    double? caloriesBurned,
    Map<String, int>? heartRateZones,
    bool? hasWearableData,
    List<String>? connectedDeviceIds,
  }) {
    return Session(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trackingMode: trackingMode ?? this.trackingMode,
      activityType: activityType ?? this.activityType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      trackingDate: trackingDate ?? this.trackingDate,
      createdAt: createdAt ?? this.createdAt,
      // Wearable data fields
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      avgHeartRateVariability: avgHeartRateVariability ?? this.avgHeartRateVariability,
      totalSteps: totalSteps ?? this.totalSteps,
      avgCadence: avgCadence ?? this.avgCadence,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      heartRateZones: heartRateZones ?? this.heartRateZones,
      hasWearableData: hasWearableData ?? this.hasWearableData,
      connectedDeviceIds: connectedDeviceIds ?? this.connectedDeviceIds,
    );
  }

  /// Get formatted duration string (e.g., "1h 30m")
  String get formattedDuration {
    if (durationSeconds == null) return '--';
    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Get formatted distance string (e.g., "5.2 km")
  String get formattedDistance {
    if (distanceMeters == null) return '--';
    return '${(distanceMeters! / 1000).toStringAsFixed(2)} km';
  }

  /// Get formatted average heart rate string
  String get formattedAvgHeartRate {
    if (avgHeartRate == null) return '--';
    return '$avgHeartRate BPM';
  }

  /// Get formatted heart rate range string
  String get formattedHeartRateRange {
    if (minHeartRate == null || maxHeartRate == null) return '--';
    return '$minHeartRate - $maxHeartRate BPM';
  }

  /// Get formatted steps string
  String get formattedSteps {
    if (totalSteps == null) return '--';
    return '$totalSteps steps';
  }

  /// Get formatted calories string
  String get formattedCalories {
    if (caloriesBurned == null) return '--';
    return '${caloriesBurned!.toStringAsFixed(0)} kcal';
  }

  /// Whether this session has any heart rate data
  bool get hasHeartRateData =>
      avgHeartRate != null || maxHeartRate != null || minHeartRate != null;

  /// Whether this session has any motion data
  bool get hasMotionData =>
      totalSteps != null || avgCadence != null;

  @override
  String toString() => 'Session(id: $id, type: $activityType, status: $status, hasWearableData: $hasWearableData)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Session && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}