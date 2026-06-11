import 'package:benefitflutter/core/enums/activity_type.dart';

/// How the activity type was determined
enum DetectionSource {
  /// User manually selected the activity type
  manual,

  /// App automatically detected the activity type
  auto,

  /// User corrected an auto-detected activity type
  corrected;

  /// Create from JSON string
  static DetectionSource fromJson(String? value) {
    switch (value?.toLowerCase()) {
      case 'manual':
        return DetectionSource.manual;
      case 'auto':
        return DetectionSource.auto;
      case 'corrected':
        return DetectionSource.corrected;
      default:
        return DetectionSource.manual;
    }
  }

  /// Convert to JSON string
  String toJson() => name;
}

/// A segment of activity within a session
///
/// Sessions can contain multiple activity segments when the user
/// changes activities (e.g., starts walking, then runs, then walks again).
/// Each segment records the activity type, duration, and distance.
class ActivitySegment {
  final String id;
  final String sessionId;
  final ActivityType activityType;

  /// When this activity segment started
  final DateTime startTime;

  /// When this activity segment ended (null if ongoing)
  final DateTime? endTime;

  /// Distance covered during this segment (meters)
  final double? distanceMeters;

  /// How the activity type was determined
  final DetectionSource detectionSource;

  /// Confidence score for auto-detected activities (0.0 - 1.0)
  final double? confidence;

  final DateTime createdAt;
  final DateTime updatedAt;

  ActivitySegment({
    required this.id,
    required this.sessionId,
    required this.activityType,
    required this.startTime,
    this.endTime,
    this.distanceMeters,
    required this.detectionSource,
    this.confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create from JSON (API response/database)
  factory ActivitySegment.fromJson(Map<String, dynamic> json) {
    return ActivitySegment(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      activityType: ActivityType.fromJson(json['activity_type'] as String),
      startTime: _parseDateTime(json['start_time'])!,
      endTime: _parseDateTime(json['end_time']),
      distanceMeters: json['distance_meters'] != null
          ? (json['distance_meters'] as num).toDouble()
          : null,
      detectionSource: DetectionSource.fromJson(
        json['detection_source'] as String?,
      ),
      confidence: json['confidence'] != null
          ? (json['confidence'] as num).toDouble()
          : null,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.parse(value);
    return null;
  }

  /// Convert to JSON (for API/database)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'activity_type': activityType.toJson(),
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'distance_meters': distanceMeters,
      'detection_source': detectionSource.toJson(),
      'confidence': confidence,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with modified fields
  ActivitySegment copyWith({
    String? id,
    String? sessionId,
    ActivityType? activityType,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceMeters,
    DetectionSource? detectionSource,
    double? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ActivitySegment(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      activityType: activityType ?? this.activityType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      detectionSource: detectionSource ?? this.detectionSource,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Duration of this segment (null if ongoing)
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// Duration in seconds (null if ongoing)
  int? get durationSeconds => duration?.inSeconds;

  /// Whether this segment is still ongoing
  bool get isOngoing => endTime == null;

  /// Whether this segment was manually set
  bool get isManual => detectionSource == DetectionSource.manual;

  /// Whether this segment was auto-detected
  bool get isAutoDetected => detectionSource == DetectionSource.auto;

  /// Whether this segment was corrected by user
  bool get isCorrected => detectionSource == DetectionSource.corrected;

  /// Formatted duration string (e.g., "15m", "1h 30m")
  String get formattedDuration {
    final dur = duration;
    if (dur == null) return 'ongoing';
    final hours = dur.inHours;
    final minutes = dur.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Formatted distance string (e.g., "1.5 km")
  String get formattedDistance {
    if (distanceMeters == null) return '--';
    return '${(distanceMeters! / 1000).toStringAsFixed(2)} km';
  }

  @override
  String toString() =>
      'ActivitySegment(id: $id, type: ${activityType.name}, duration: $formattedDuration)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivitySegment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
