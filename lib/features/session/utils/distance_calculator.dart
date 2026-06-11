import 'dart:math';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/core/config/gps_tracking_config.dart';

/// Utility class for calculating distances and metrics from GPS coordinates
///
/// All calculations are based on GPS points and use standard geodesic formulas.
/// These static methods are used throughout the app for:
/// - Distance calculation during active sessions
/// - Elevation gain/loss analysis
/// - Pace calculations for performance metrics
///
/// Distance Calculation:
/// Uses Haversine formula for great-circle distance on a sphere.
/// Accuracy within 0.5% for distances up to ~500km.
///
/// See: GpsTrackingConfig for earth radius and other constants
/// See: DATABASE.md for how GPS data is stored
class DistanceCalculator {
  // Private constructor to prevent instantiation
  DistanceCalculator._();

  // ===== DISTANCE CALCULATIONS =====

  /// Calculate total distance from list of GPS points
  ///
  /// Sums up distances between consecutive GPS points using Haversine formula.
  /// Returns distance in meters.
  ///
  /// Example:
  /// ```dart
  /// final points = await gpsPointDao.findBySessionId(sessionId);
  /// final distance = DistanceCalculator.calculateTotalDistance(points);
  /// print('Total distance: ${distance / 1000} km');
  /// ```
  ///
  /// Returns 0.0 if:
  /// - Empty list
  /// - Single point (no distance to calculate)
  static double calculateTotalDistance(List<GpsPoint> points) {
    if (points.length < 2) return 0.0;

    double totalDistance = 0.0;

    for (int i = 1; i < points.length; i++) {
      totalDistance += _haversineDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }

    return totalDistance;
  }

  /// Calculate distance between two points using Haversine formula
  ///
  /// Convenience method for calculating distance between any two GPS points.
  /// Returns distance in meters.
  ///
  /// Example:
  /// ```dart
  /// final distance = DistanceCalculator.distanceBetween(startPoint, endPoint);
  /// ```
  static double distanceBetween(GpsPoint point1, GpsPoint point2) {
    return _haversineDistance(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Haversine formula for distance between two lat/lng points
  ///
  /// Formula: https://en.wikipedia.org/wiki/Haversine_formula
  /// Returns distance in meters.
  ///
  /// The Haversine formula calculates the great-circle distance between
  /// two points on a sphere given their longitudes and latitudes.
  ///
  /// Steps:
  /// 1. Convert lat/lng differences to radians
  /// 2. Calculate haversine of central angle
  /// 3. Convert to arc length using earth radius
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Convert latitude and longitude differences to radians
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    // Haversine formula
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Distance = radius × central angle
    return GpsTrackingConfig.earthRadiusMeters * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // ===== ELEVATION CALCULATIONS =====

  /// Calculate total elevation gain from GPS points
  ///
  /// Sums up all positive altitude changes between consecutive points.
  /// Returns total elevation gain in meters.
  ///
  /// Example:
  /// ```dart
  /// final points = await gpsPointDao.findBySessionId(sessionId);
  /// final gain = DistanceCalculator.calculateElevationGain(points);
  /// print('Climbed: ${gain.toStringAsFixed(0)}m');
  /// ```
  ///
  /// Returns 0.0 if:
  /// - Empty list
  /// - Single point
  /// - No altitude data available
  static double calculateElevationGain(List<GpsPoint> points) {
    if (points.length < 2) return 0.0;

    double totalGain = 0.0;

    for (int i = 1; i < points.length; i++) {
      // Skip if either point lacks altitude data
      if (points[i].altitude == null || points[i - 1].altitude == null) {
        continue;
      }

      final diff = points[i].altitude! - points[i - 1].altitude!;

      // Only count positive changes (going uphill)
      if (diff > 0) {
        totalGain += diff;
      }
    }

    return totalGain;
  }

  /// Calculate total elevation loss from GPS points
  ///
  /// Sums up all negative altitude changes between consecutive points.
  /// Returns total elevation loss in meters (always positive value).
  ///
  /// Example:
  /// ```dart
  /// final points = await gpsPointDao.findBySessionId(sessionId);
  /// final loss = DistanceCalculator.calculateElevationLoss(points);
  /// print('Descended: ${loss.toStringAsFixed(0)}m');
  /// ```
  ///
  /// Returns 0.0 if:
  /// - Empty list
  /// - Single point
  /// - No altitude data available
  static double calculateElevationLoss(List<GpsPoint> points) {
    if (points.length < 2) return 0.0;

    double totalLoss = 0.0;

    for (int i = 1; i < points.length; i++) {
      // Skip if either point lacks altitude data
      if (points[i].altitude == null || points[i - 1].altitude == null) {
        continue;
      }

      final diff = points[i].altitude! - points[i - 1].altitude!;

      // Only count negative changes (going downhill)
      if (diff < 0) {
        totalLoss += diff.abs();
      }
    }

    return totalLoss;
  }

  /// Calculate net elevation change from GPS points
  ///
  /// Returns difference between final and initial altitude.
  /// Positive = finished higher than started
  /// Negative = finished lower than started
  ///
  /// Example:
  /// ```dart
  /// final netElevation = DistanceCalculator.calculateNetElevation(points);
  /// if (netElevation > 0) {
  ///   print('Finished ${netElevation}m higher');
  /// }
  /// ```
  ///
  /// Returns null if altitude data is missing
  static double? calculateNetElevation(List<GpsPoint> points) {
    if (points.isEmpty) return null;
    if (points.first.altitude == null || points.last.altitude == null) {
      return null;
    }

    return points.last.altitude! - points.first.altitude!;
  }

  // ===== PACE CALCULATIONS =====

  /// Calculate average pace in seconds per kilometer
  ///
  /// Returns pace as seconds needed to cover 1 kilometer.
  /// Common in running/cycling metrics.
  ///
  /// Example:
  /// ```dart
  /// final pace = DistanceCalculator.calculateAveragePace(5000, 1800);
  /// // pace = 360 seconds/km (6:00 min/km)
  /// print('${pace ~/ 60}:${(pace % 60).toStringAsFixed(0).padLeft(2, '0')} min/km');
  /// ```
  ///
  /// Returns null if distance is 0 (would cause division by zero)
  static double? calculateAveragePace(
    double distanceMeters,
    int durationSeconds,
  ) {
    if (distanceMeters == 0) return null;

    final distanceKm = distanceMeters / 1000;
    return durationSeconds / distanceKm;
  }

  /// Calculate average speed in meters per second
  ///
  /// Returns average speed during the activity.
  ///
  /// Example:
  /// ```dart
  /// final speed = DistanceCalculator.calculateAverageSpeed(5000, 1800);
  /// // speed = 2.78 m/s
  /// print('Average speed: ${(speed * 3.6).toStringAsFixed(1)} km/h');
  /// ```
  ///
  /// Returns null if duration is 0
  static double? calculateAverageSpeed(
    double distanceMeters,
    int durationSeconds,
  ) {
    if (durationSeconds == 0) return null;
    return distanceMeters / durationSeconds;
  }

  /// Calculate average speed in kilometers per hour
  ///
  /// Convenience method for getting speed in km/h.
  ///
  /// Example:
  /// ```dart
  /// final speedKmh = DistanceCalculator.calculateAverageSpeedKmh(5000, 1800);
  /// print('${speedKmh?.toStringAsFixed(1)} km/h');
  /// ```
  static double? calculateAverageSpeedKmh(
    double distanceMeters,
    int durationSeconds,
  ) {
    final metersPerSecond = calculateAverageSpeed(
      distanceMeters,
      durationSeconds,
    );
    if (metersPerSecond == null) return null;
    return metersPerSecond * 3.6; // Convert m/s to km/h
  }

  // ===== DATA QUALITY =====

  /// Filter GPS points by quality threshold
  ///
  /// Returns only points that meet quality requirements:
  /// - Accuracy better than minAccuracyMeters
  /// - Timestamp not older than maxGpsAgeSeconds
  ///
  /// Useful for cleaning noisy GPS data before calculations.
  ///
  /// Example:
  /// ```dart
  /// final allPoints = await gpsPointDao.findBySessionId(sessionId);
  /// final goodPoints = DistanceCalculator.filterByQuality(allPoints);
  /// final distance = DistanceCalculator.calculateTotalDistance(goodPoints);
  /// ```
  static List<GpsPoint> filterByQuality(List<GpsPoint> points) {
    return points.where((point) => point.meetsQualityRequirements()).toList();
  }

  /// Calculate data quality score for a session
  ///
  /// Returns percentage (0-100) of GPS points that meet quality requirements.
  /// Higher score = better GPS data quality.
  ///
  /// Example:
  /// ```dart
  /// final quality = DistanceCalculator.calculateDataQuality(points);
  /// if (quality < 80) {
  ///   print('Warning: GPS data quality is low ($quality%)');
  /// }
  /// ```
  static double calculateDataQuality(List<GpsPoint> points) {
    if (points.isEmpty) return 0.0;

    final goodPoints = filterByQuality(points);
    return (goodPoints.length / points.length) * 100;
  }
}
