/// Centralized tracking & scoring configuration
///
/// This config complements [GpsTrackingConfig] which handles GPS-specific settings.
/// TrackingConfig focuses on trust scoring, anti-gaming, and activity multipliers.
///
/// ## Usage
/// ```dart
/// final score = TrackingConfig.calculateScore(
///   baseDistancePoints: 100,
///   sensorTrustMultiplier: TrackingConfig.gpsPedometerMultiplier,
///   deviceMultiplier: DeviceProfiles.getDeviceMultiplier(deviceId),
///   activityMultiplier: TrackingConfig.runningMultiplier,
/// );
/// ```
///
/// ## Related
/// - [GpsTrackingConfig] - GPS intervals and quality filters
/// - [DeviceProfiles] - Device-specific accuracy overrides
/// - [HrDeviceProfiles] - Heart rate device identification
/// - [StepValidationConfig] - Step count cross-validation
class TrackingConfig {
  TrackingConfig._();

  // ============================================================
  // SENSOR TRUST MULTIPLIERS
  // ============================================================
  // These multipliers adjust the points earned based on how
  // reliably we can verify the movement data.
  // More sensors = more cross-validation = higher trust.

  /// GPS only - lowest trust
  ///
  /// Risks: Could be in vehicle, weak signal areas unreliable, easy to spoof
  static const double gpsOnlyMultiplier = 0.35;

  /// GPS + Pedometer - medium trust
  ///
  /// Pedometer confirms walking motion, helps filter out vehicles
  static const double gpsPedometerMultiplier = 0.55;

  /// GPS + Pedometer + Barometer - high trust
  ///
  /// Can detect elevation changes, better stair detection,
  /// cross-validation between sensors possible
  static const double gpsBarometerMultiplier = 0.75;

  /// GPS + Pedometer + Wrist HR - high trust
  ///
  /// Confirms physical exertion, wrist HR less accurate but still useful
  static const double gpsWristHrMultiplier = 0.75;

  /// GPS + Pedometer + Chest Strap HR - very high trust
  ///
  /// Chest strap provides medical-grade HR accuracy,
  /// strong exertion validation
  static const double gpsChestHrMultiplier = 0.88;

  /// Full sensor suite (GPS + Pedometer + Barometer + Chest HR) - highest trust
  ///
  /// Multiple independent signals enable full cross-validation
  static const double fullSensorMultiplier = 0.90;

  // ============================================================
  // ANTI-GAMING FILTERS
  // ============================================================
  // Speed filters to detect vehicles and stationary noise.

  /// Speed above this is likely a vehicle (km/h)
  ///
  /// Even fast cyclists rarely exceed 25 km/h sustained
  static const double maxValidSpeedKmh = 25.0;

  /// Speed below this is stationary noise (km/h)
  ///
  /// GPS drift and minor movements below this threshold
  static const double minValidSpeedKmh = 0.3;

  // ============================================================
  // ACTIVITY TYPE MULTIPLIERS
  // ============================================================
  // Applied based on user-declared or auto-detected activity type.

  /// Walking - baseline activity
  static const double walkingMultiplier = 1.0;

  /// Running - higher effort than walking
  static const double runningMultiplier = 1.3;

  /// Cycling - similar effort to running, different mechanics
  static const double cyclingMultiplier = 1.2;

  /// Daily movement - for continuous tracking sessions
  ///
  /// No bonus applied since activity type is mixed/unknown
  static const double dailyMovementMultiplier = 1.0;

  // ============================================================
  // CONTINUOUS TRACKING DEFAULTS
  // ============================================================

  /// Whether continuous tracking is enabled by default
  ///
  /// Set to false to require explicit user opt-in (battery impact)
  static const bool continuousEnabledByDefault = false;

  /// Default reset times for continuous sessions (24h format)
  ///
  /// Sessions reset at these times to enable syncing.
  /// Default 03:00 chosen because most users are asleep.
  static const List<String> defaultResetPoints = ['03:00'];

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Calculate final score for movement
  ///
  /// Formula: base × sensor_trust × device × activity
  ///
  /// Example:
  /// - 1km walk (100 base points)
  /// - GPS + Pedometer (0.55 trust)
  /// - Standard device (1.0)
  /// - Walking (1.0)
  /// - Result: 100 × 0.55 × 1.0 × 1.0 = 55 points
  static double calculateScore({
    required double baseDistancePoints,
    required double sensorTrustMultiplier,
    required double deviceMultiplier,
    required double activityMultiplier,
  }) {
    return baseDistancePoints *
        sensorTrustMultiplier *
        deviceMultiplier *
        activityMultiplier;
  }

  /// Check if speed is within valid range for human movement
  ///
  /// Returns true if speed is between [minValidSpeedKmh] and [maxValidSpeedKmh]
  static bool isValidSpeed(double speedKmh) {
    return speedKmh >= minValidSpeedKmh && speedKmh <= maxValidSpeedKmh;
  }

  /// Get activity multiplier by activity type string
  ///
  /// Returns [dailyMovementMultiplier] (1.0) for unknown types
  static double getActivityMultiplier(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return walkingMultiplier;
      case 'running':
        return runningMultiplier;
      case 'cycling':
        return cyclingMultiplier;
      case 'daily_movement':
      default:
        return dailyMovementMultiplier;
    }
  }
}
