import 'dart:convert';

/// User preferences for continuous tracking
///
/// Stores configuration for how continuous tracking should behave,
/// including reset times, activity detection mode, and GPS settings.
class ContinuousTrackingConfig {
  final String id;
  final String userId;
  final bool isEnabled;

  /// Reset times in 24h format, e.g., ["03:00", "15:00"]
  ///
  /// Sessions are automatically ended and restarted at these times
  /// to enable regular syncing with the server.
  final List<String> resetPoints;

  /// Activity detection mode: 'manual', 'auto', or 'hybrid'
  ///
  /// - manual: User selects activity type
  /// - auto: App detects activity automatically
  /// - hybrid: Auto-detection with manual override (default)
  final String activityDetection;

  /// GPS update interval in seconds (default: 300 = 5 minutes)
  final int gpsIntervalSeconds;

  /// Minimum distance to trigger GPS save (default: 100 meters)
  final int minDisplacementMeters;

  final DateTime createdAt;
  final DateTime updatedAt;

  ContinuousTrackingConfig({
    required this.id,
    required this.userId,
    required this.isEnabled,
    required this.resetPoints,
    required this.activityDetection,
    required this.gpsIntervalSeconds,
    required this.minDisplacementMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create a default configuration for a user
  factory ContinuousTrackingConfig.defaultFor(String userId) {
    final now = DateTime.now();
    return ContinuousTrackingConfig(
      id: 'ctc-$userId',
      userId: userId,
      isEnabled: false,
      resetPoints: ['03:00'],
      activityDetection: 'hybrid',
      gpsIntervalSeconds: 300,
      minDisplacementMeters: 100,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from JSON (API response)
  factory ContinuousTrackingConfig.fromJson(Map<String, dynamic> json) {
    return ContinuousTrackingConfig(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      isEnabled: json['is_enabled'] == 1 || json['is_enabled'] == true,
      resetPoints: _parseResetPoints(json['reset_points']),
      activityDetection: json['activity_detection'] as String? ?? 'hybrid',
      gpsIntervalSeconds: json['gps_interval_seconds'] as int? ?? 300,
      minDisplacementMeters: json['min_displacement_meters'] as int? ?? 100,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static List<String> _parseResetPoints(dynamic value) {
    if (value == null) return ['03:00'];
    if (value is List) return List<String>.from(value);
    if (value is String) {
      try {
        return List<String>.from(jsonDecode(value));
      } catch (_) {
        return ['03:00'];
      }
    }
    return ['03:00'];
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  /// Convert to JSON (for API/database)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'is_enabled': isEnabled ? 1 : 0,
      'reset_points': jsonEncode(resetPoints),
      'activity_detection': activityDetection,
      'gps_interval_seconds': gpsIntervalSeconds,
      'min_displacement_meters': minDisplacementMeters,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with modified fields
  ContinuousTrackingConfig copyWith({
    String? id,
    String? userId,
    bool? isEnabled,
    List<String>? resetPoints,
    String? activityDetection,
    int? gpsIntervalSeconds,
    int? minDisplacementMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContinuousTrackingConfig(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isEnabled: isEnabled ?? this.isEnabled,
      resetPoints: resetPoints ?? this.resetPoints,
      activityDetection: activityDetection ?? this.activityDetection,
      gpsIntervalSeconds: gpsIntervalSeconds ?? this.gpsIntervalSeconds,
      minDisplacementMeters:
          minDisplacementMeters ?? this.minDisplacementMeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// GPS interval as Duration
  Duration get gpsInterval => Duration(seconds: gpsIntervalSeconds);

  /// Whether activity detection is manual only
  bool get isManualDetection => activityDetection == 'manual';

  /// Whether activity detection is automatic only
  bool get isAutoDetection => activityDetection == 'auto';

  /// Whether activity detection is hybrid (auto with manual override)
  bool get isHybridDetection => activityDetection == 'hybrid';

  @override
  String toString() =>
      'ContinuousTrackingConfig(id: $id, userId: $userId, isEnabled: $isEnabled)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContinuousTrackingConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
