import 'dart:math';
import 'package:benefitflutter/core/config/gps_tracking_config.dart';

/// Represents a single GPS tracking point during a session
///
/// GPS points are captured at regular intervals during active tracking
/// (manual or continuous sessions). Each point records:
/// - Location (latitude, longitude, altitude)
/// - Quality metrics (accuracy, speed)
/// - Timestamp (when the point was captured)
///
/// GPS points are stored in the database and used to:
/// - Calculate total distance using Haversine formula
/// - Calculate elevation gain/loss
/// - Display route on map (future feature)
/// - Analyze pace and performance
///
/// Data retention:
/// GPS points are deleted after successful sync to server (configurable).
/// Session summaries (distance, duration) are kept permanently.
///
/// See: DATABASE.md for database schema
/// See: GpsTrackingConfig for frequency and quality settings
class GpsPoint {
  /// Unique identifier (UUID)
  final String id;

  /// Reference to parent session
  final String sessionId;

  /// Latitude in decimal degrees (-90 to 90)
  final double latitude;

  /// Longitude in decimal degrees (-180 to 180)
  final double longitude;

  /// Altitude/elevation in meters above sea level (optional)
  ///
  /// Used to calculate elevation gain/loss.
  /// May be null if device doesn't support altitude or GPS fix is 2D only.
  final double? altitude;

  /// GPS accuracy in meters (optional)
  ///
  /// Represents the radius of uncertainty for this GPS fix.
  /// Lower values = more accurate position.
  /// Used to filter out low-quality GPS points.
  final double? accuracyMeters;

  /// Instantaneous speed in meters per second (optional)
  ///
  /// Calculated by GPS hardware based on Doppler shift.
  /// May be more accurate than calculating speed from position changes.
  final double? speedMetersPerSecond;

  /// When this GPS point was captured
  ///
  /// Timestamp from GPS hardware, not device clock.
  /// Used for:
  /// - Ordering GPS points chronologically
  /// - Calculating time deltas between points
  /// - Filtering stale GPS fixes
  final DateTime timestamp;

  /// When this GPS point was stored in database
  ///
  /// Device clock timestamp, used for:
  /// - Cleanup queries (delete old points)
  /// - Debugging sync issues
  final DateTime createdAt;

  GpsPoint({
    required this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    required this.timestamp,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create GpsPoint from JSON
  ///
  /// Used when:
  /// - Deserializing from database
  /// - Receiving from API
  factory GpsPoint.fromJson(Map<String, dynamic> json) {
    return GpsPoint(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] != null
          ? (json['altitude'] as num).toDouble()
          : null,
      accuracyMeters: json['accuracy_meters'] != null
          ? (json['accuracy_meters'] as num).toDouble()
          : null,
      speedMetersPerSecond: json['speed_meters_per_second'] != null
          ? (json['speed_meters_per_second'] as num).toDouble()
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert GpsPoint to JSON
  ///
  /// Used when:
  /// - Serializing for database storage
  /// - Sending to API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy_meters': accuracyMeters,
      'speed_meters_per_second': speedMetersPerSecond,
      'timestamp': timestamp.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Calculate distance to another GPS point using Haversine formula
  ///
  /// Returns distance in meters.
  /// Formula accounts for Earth's curvature (spherical approximation).
  ///
  /// Accuracy:
  /// - Within 0.5% error for distances up to ~500km
  /// - Assumes Earth is a perfect sphere (good enough for fitness tracking)
  ///
  /// See: DistanceCalculator for implementation details
  double distanceTo(GpsPoint other) {
    return _haversineDistance(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// Haversine formula implementation
  ///
  /// Calculates great-circle distance between two points on a sphere.
  /// Formula: https://en.wikipedia.org/wiki/Haversine_formula
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return GpsTrackingConfig.earthRadiusMeters * c;
  }

  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Check if this GPS point meets quality requirements
  ///
  /// Returns true if:
  /// - Accuracy is good enough (< minAccuracyMeters)
  /// - Timestamp is recent (< maxGpsAgeSeconds)
  ///
  /// See: GpsTrackingConfig for threshold values
  bool meetsQualityRequirements() {
    return GpsTrackingConfig.meetsQualityRequirements(
      accuracyMeters: accuracyMeters,
      timestamp: timestamp,
    );
  }

  /// Create a copy of this GPS point with updated fields
  ///
  /// Useful for:
  /// - Updating mutable fields
  /// - Creating test fixtures
  GpsPoint copyWith({
    String? id,
    String? sessionId,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracyMeters,
    double? speedMetersPerSecond,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return GpsPoint(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      speedMetersPerSecond: speedMetersPerSecond ?? this.speedMetersPerSecond,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'GpsPoint('
        'lat: ${latitude.toStringAsFixed(6)}, '
        'lng: ${longitude.toStringAsFixed(6)}, '
        'alt: ${altitude?.toStringAsFixed(1) ?? 'N/A'}m, '
        'acc: ${accuracyMeters?.toStringAsFixed(1) ?? 'N/A'}m, '
        'time: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GpsPoint &&
        other.id == id &&
        other.sessionId == sessionId &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude &&
        other.accuracyMeters == accuracyMeters &&
        other.speedMetersPerSecond == speedMetersPerSecond &&
        other.timestamp == timestamp &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      sessionId,
      latitude,
      longitude,
      altitude,
      accuracyMeters,
      speedMetersPerSecond,
      timestamp,
      createdAt,
    );
  }
}
