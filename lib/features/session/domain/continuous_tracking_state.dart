/// Runtime state for continuous tracking
///
/// Represents the current state of continuous tracking for a user.
/// This is transient data that changes frequently during tracking.
class ContinuousTrackingState {
  final String id;
  final String userId;

  /// Whether continuous tracking is currently running
  final bool isActive;

  /// Whether tracking is temporarily paused for a manual session
  ///
  /// When true, continuous tracking will auto-resume after
  /// the manual session ends.
  final bool isPausedForManual;

  /// Current continuous session ID (if active)
  final String? currentSessionId;

  /// When continuous tracking was started (null if not active)
  final DateTime? startedAt;

  /// Last time GPS/sensor data was received
  final DateTime? lastDataReceived;

  /// Currently detected activity type (if auto-detection enabled)
  final String? currentDetectedActivity;

  /// Confidence score for detected activity (0.0 - 1.0)
  final double? detectionConfidence;

  final DateTime updatedAt;

  ContinuousTrackingState({
    required this.id,
    required this.userId,
    required this.isActive,
    required this.isPausedForManual,
    this.currentSessionId,
    this.startedAt,
    this.lastDataReceived,
    this.currentDetectedActivity,
    this.detectionConfidence,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Create a default (inactive) state for a user
  factory ContinuousTrackingState.defaultFor(String userId) {
    return ContinuousTrackingState(
      id: 'cts-$userId',
      userId: userId,
      isActive: false,
      isPausedForManual: false,
      updatedAt: DateTime.now(),
    );
  }

  /// Create from JSON (API response/database)
  factory ContinuousTrackingState.fromJson(Map<String, dynamic> json) {
    return ContinuousTrackingState(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isPausedForManual:
          json['is_paused_for_manual'] == 1 || json['is_paused_for_manual'] == true,
      currentSessionId: json['current_session_id'] as String?,
      startedAt: _parseDateTime(json['started_at']),
      lastDataReceived: _parseDateTime(json['last_data_received']),
      currentDetectedActivity: json['current_detected_activity'] as String?,
      detectionConfidence: json['detection_confidence'] != null
          ? (json['detection_confidence'] as num).toDouble()
          : null,
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
      'user_id': userId,
      'is_active': isActive ? 1 : 0,
      'is_paused_for_manual': isPausedForManual ? 1 : 0,
      'current_session_id': currentSessionId,
      'started_at': startedAt?.millisecondsSinceEpoch,
      'last_data_received': lastDataReceived?.millisecondsSinceEpoch,
      'current_detected_activity': currentDetectedActivity,
      'detection_confidence': detectionConfidence,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with modified fields
  ContinuousTrackingState copyWith({
    String? id,
    String? userId,
    bool? isActive,
    bool? isPausedForManual,
    String? currentSessionId,
    DateTime? startedAt,
    DateTime? lastDataReceived,
    String? currentDetectedActivity,
    double? detectionConfidence,
    DateTime? updatedAt,
  }) {
    return ContinuousTrackingState(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      isPausedForManual: isPausedForManual ?? this.isPausedForManual,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      startedAt: startedAt ?? this.startedAt,
      lastDataReceived: lastDataReceived ?? this.lastDataReceived,
      currentDetectedActivity: currentDetectedActivity ?? this.currentDetectedActivity,
      detectionConfidence: detectionConfidence ?? this.detectionConfidence,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Whether tracking is currently running (active and not paused)
  bool get isTracking => isActive && !isPausedForManual;

  /// How long tracking has been active (null if not started)
  Duration? get activeTime {
    if (startedAt == null) return null;
    return DateTime.now().difference(startedAt!);
  }

  /// Time since last data was received (null if no data yet)
  Duration? get timeSinceLastData {
    if (lastDataReceived == null) return null;
    return DateTime.now().difference(lastDataReceived!);
  }

  /// Whether we have recent data (within last 10 minutes)
  bool get hasRecentData {
    final elapsed = timeSinceLastData;
    if (elapsed == null) return false;
    return elapsed.inMinutes < 10;
  }

  /// Formatted active time string (e.g., "2h 30m")
  String get formattedActiveTime {
    final duration = activeTime;
    if (duration == null) return '--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  String toString() =>
      'ContinuousTrackingState(id: $id, isActive: $isActive, isPaused: $isPausedForManual)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContinuousTrackingState && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
