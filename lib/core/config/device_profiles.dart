/// Known device accuracy profiles
///
/// Runtime sensor detection is the primary method for determining
/// device capabilities. This config provides overrides for known
/// problematic or excellent devices.
///
/// ## How It Works
/// 1. App detects available sensors at runtime
/// 2. Base trust level determined from sensor combination
/// 3. Device-specific override applied if device is in [overrides] map
///
/// ## Usage
/// ```dart
/// // Get device info (using device_info_plus package)
/// final deviceId = DeviceProfiles.buildDeviceId(
///   info.manufacturer,
///   info.model,
/// );
///
/// // Get multiplier (1.0 if not in overrides)
/// final multiplier = DeviceProfiles.getDeviceMultiplier(deviceId);
/// ```
///
/// ## Related
/// - [TrackingConfig] - Sensor trust multipliers and scoring
/// - [HrDeviceProfiles] - Heart rate device identification
class DeviceProfiles {
  DeviceProfiles._();

  /// Device-specific multiplier overrides
  ///
  /// Format: `"manufacturer_model": multiplier`
  ///
  /// Multiplier values:
  /// - `< 1.0` = Less trusted (known issues with sensors)
  /// - `= 1.0` = Baseline (no adjustment)
  /// - `> 1.0` = More trusted (excellent sensor quality)
  ///
  /// Populated based on user feedback and testing.
  /// Start empty - add devices as issues/excellence discovered.
  static const Map<String, double> overrides = {
    // Examples (uncomment and adjust as data is collected):
    //
    // Known problematic devices:
    // 'generic_budget_phone': 0.8,      // Step count drift
    // 'xiaomi_redmi_note_8': 0.85,      // GPS accuracy issues
    //
    // Excellent devices:
    // 'google_pixel_7': 1.05,           // Very accurate sensors
    // 'samsung_galaxy_s23': 1.0,        // Good baseline
  };

  /// Get multiplier for a device
  ///
  /// [deviceId] should be in format "manufacturer_model" (lowercase, underscores)
  ///
  /// Returns 1.0 (no adjustment) if device not in [overrides]
  static double getDeviceMultiplier(String deviceId) {
    return overrides[deviceId.toLowerCase()] ?? 1.0;
  }

  /// Build device ID from system info
  ///
  /// Creates normalized device ID for lookup in [overrides].
  ///
  /// Example:
  /// ```dart
  /// buildDeviceId('Samsung', 'Galaxy S21') // returns 'samsung_galaxy_s21'
  /// ```
  static String buildDeviceId(String manufacturer, String model) {
    final normalized = '${manufacturer}_$model'
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return normalized;
  }

  /// Check if a device has a known override
  static bool hasOverride(String deviceId) {
    return overrides.containsKey(deviceId.toLowerCase());
  }
}
