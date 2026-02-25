/// GPS tracking configuration
///
/// Adjust these parameters to balance accuracy vs battery/storage.
/// Changes to these values affect:
/// - Storage usage (more frequent = more GPS points stored)
/// - Battery consumption (more frequent = more GPS reads)
/// - Distance accuracy (more frequent = more accurate calculations)
///
/// For more details on GPS tracking architecture, see DATABASE.md
class GpsTrackingConfig {
  // ===== GPS Point Storage Frequency =====

  /// Store GPS point every X seconds (time-based threshold)
  ///
  /// Used for manual tracking sessions. GPS point is stored if either
  /// this time threshold OR the distance threshold is exceeded.
  ///
  /// Default: 5 seconds
  static const int maxSecondsBetweenPoints = 5;

  /// Store GPS point every X meters (distance-based threshold)
  ///
  /// Whichever comes first (time OR distance) triggers point storage.
  /// This ensures we capture significant movement even if time hasn't elapsed.
  ///
  /// Default: 10 meters
  static const double minMetersBetweenPoints = 10.0;

  // ===== GPS Quality Filters =====

  /// Minimum GPS accuracy (in meters) to accept a point
  ///
  /// Points with worse accuracy than this are discarded.
  /// Lower values = more strict (better accuracy required).
  /// Higher values = more lenient (accept less accurate points).
  ///
  /// Default: 50 meters (reasonable for outdoor tracking)
  static const double minAccuracyMeters = 50.0;

  /// Maximum age of GPS fix (in seconds) to consider valid
  ///
  /// GPS points older than this are considered stale and discarded.
  /// Prevents using cached/outdated location data.
  ///
  /// Default: 10 seconds
  static const int maxGpsAgeSeconds = 10;

  // ===== Distance Calculation =====

  /// Earth radius for Haversine formula (meters)
  ///
  /// Used to calculate distance between GPS coordinates.
  /// Standard earth radius: 6,371,000 meters (6,371 km)
  ///
  /// See: lib/features/session/utils/distance_calculator.dart
  static const double earthRadiusMeters = 6371000.0;

  // ===== Continuous Mode (Different Settings) =====

  /// For continuous tracking, use lower frequency to save battery
  ///
  /// Continuous tracking runs in background for extended periods,
  /// so we use less frequent updates to preserve battery.
  ///
  /// Default: 300 seconds (5 minutes)
  static const int continuousModeMaxSecondsBetweenPoints = 300;

  /// Distance threshold for continuous mode
  ///
  /// Default: 100 meters
  static const double continuousModeMinMetersBetweenPoints = 100.0;

  // ===== Data Retention =====

  /// Delete GPS points after successful sync to server
  ///
  /// When true, GPS points are deleted from local database after
  /// successful upload to server. Session summary (distance, duration)
  /// is kept permanently.
  ///
  /// Set to false during development to preserve GPS tracks locally.
  ///
  /// Default: true (delete after sync)
  static const bool deleteGpsPointsAfterSync = true;

  /// How many sync retries before considering GPS data "synced"
  ///
  /// GPS points are only deleted after this many successful syncs.
  /// Higher values = more conservative (keep data longer).
  ///
  /// Default: 1 (delete after first successful sync)
  static const int requiredSuccessfulSyncs = 1;

  // ===== Helper Methods =====

  /// Get time threshold based on tracking mode
  static int getMaxSecondsBetweenPoints(bool isContinuousMode) {
    return isContinuousMode
        ? continuousModeMaxSecondsBetweenPoints
        : maxSecondsBetweenPoints;
  }

  /// Get distance threshold based on tracking mode
  static double getMinMetersBetweenPoints(bool isContinuousMode) {
    return isContinuousMode
        ? continuousModeMinMetersBetweenPoints
        : minMetersBetweenPoints;
  }

  /// Check if GPS point should be stored based on time/distance thresholds
  ///
  /// Returns true if either:
  /// - Enough time has passed since last point
  /// - Enough distance has been covered since last point
  static bool shouldStorePoint({
    required DateTime lastPointTime,
    required double distanceFromLastPoint,
    required bool isContinuousMode,
  }) {
    final now = DateTime.now();
    final secondsSinceLastPoint = now.difference(lastPointTime).inSeconds;

    final maxSeconds = getMaxSecondsBetweenPoints(isContinuousMode);
    final minMeters = getMinMetersBetweenPoints(isContinuousMode);

    // Store if time threshold exceeded OR distance threshold exceeded
    return secondsSinceLastPoint >= maxSeconds ||
        distanceFromLastPoint >= minMeters;
  }

  /// Check if GPS point meets quality requirements
  static bool meetsQualityRequirements({
    required double? accuracyMeters,
    required DateTime timestamp,
  }) {
    // Reject if no accuracy data
    if (accuracyMeters == null) return false;

    // Reject if accuracy is worse than threshold
    if (accuracyMeters > minAccuracyMeters) return false;

    // Reject if GPS fix is too old
    final now = DateTime.now();
    final ageSeconds = now.difference(timestamp).inSeconds;
    if (ageSeconds > maxGpsAgeSeconds) return false;

    return true;
  }
}
