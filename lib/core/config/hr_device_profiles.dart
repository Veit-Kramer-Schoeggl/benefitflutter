/// Heart rate device type classification
///
/// Used to determine trust level based on HR measurement accuracy.
/// Chest straps provide significantly more accurate readings than
/// optical wrist sensors.
enum HrDeviceType {
  /// Chest strap - highest accuracy
  ///
  /// Examples: Polar H10, Garmin HRM-Pro, Wahoo TICKR
  /// Uses electrical signals (ECG-like) for measurement.
  chestStrap,

  /// Smart watch with optical HR
  ///
  /// Examples: Apple Watch, Samsung Galaxy Watch, Garmin Venu
  /// Uses photoplethysmography (PPG) on wrist.
  wristWatch,

  /// Fitness band with optical HR
  ///
  /// Examples: Fitbit Charge, Xiaomi Mi Band, Huawei Band
  /// Similar to watches but typically less accurate sensors.
  wristBand,

  /// Unknown device type
  ///
  /// Conservative estimate applied when device cannot be identified.
  unknown,
}

/// Heart rate device identification and trust scoring
///
/// Uses BLE device name pattern matching against a known device database.
/// Chest straps receive a higher trust multiplier due to superior accuracy
/// compared to optical wrist-based sensors.
///
/// ## How It Works
/// 1. When HR device connects via BLE, get device name
/// 2. Call [identifyDevice] to classify device type
/// 3. Use [getTrustMultiplier] to get scoring adjustment
///
/// ## Usage
/// ```dart
/// // When BLE device connects
/// final deviceType = HrDeviceProfiles.identifyDevice(bleDevice.name);
/// final multiplier = HrDeviceProfiles.getTrustMultiplier(deviceType);
///
/// // Or use convenience method
/// final multiplier = HrDeviceProfiles.getMultiplierForDevice(bleDevice.name);
/// ```
///
/// ## Related
/// - [TrackingConfig] - Overall sensor trust multipliers
/// - [DeviceProfiles] - Phone device overrides
class HrDeviceProfiles {
  HrDeviceProfiles._();

  // ============================================================
  // TRUST MULTIPLIERS BY DEVICE TYPE
  // ============================================================

  /// Chest strap multiplier - highest trust
  ///
  /// Medical-grade accuracy, hard to fake elevated HR
  static const double chestStrapMultiplier = 0.88;

  /// Wrist watch multiplier - medium-high trust
  ///
  /// Decent accuracy, but affected by fit and motion
  static const double wristWatchMultiplier = 0.75;

  /// Wrist band multiplier - medium-high trust
  ///
  /// Similar to watches, sometimes slightly less accurate
  static const double wristBandMultiplier = 0.75;

  /// Unknown device multiplier - conservative trust
  ///
  /// Applied when device type cannot be determined
  static const double unknownDeviceMultiplier = 0.70;

  // ============================================================
  // KNOWN DEVICE PATTERNS
  // ============================================================

  /// Known chest strap identifiers (partial match, case-insensitive)
  ///
  /// These patterns are matched against BLE device names.
  static const List<String> chestStrapPatterns = [
    // Polar
    'polar h10',
    'polar h9',
    'polar h7',
    'polar h6',
    'polar oh1', // Also optical but arm-based, similar accuracy
    // Garmin
    'hrm-pro',
    'hrm-dual',
    'hrm-run',
    'hrm-tri',
    'hrm-swim',
    // Wahoo
    'tickr',
    // Coospo
    'coospo h',
    'h808',
    // Magene
    'magene h',
    // Suunto
    'suunto smart sensor',
    // Generic patterns
    'heart rate strap',
    'hr strap',
    'chest strap',
    'hrm strap',
  ];

  /// Known wrist watch patterns
  static const List<String> wristWatchPatterns = [
    // Apple
    'apple watch',
    // Samsung
    'galaxy watch',
    'gear s',
    // Garmin watches (not HRM straps)
    'garmin venu',
    'garmin vivoactive',
    'garmin forerunner',
    'garmin fenix',
    // Fitbit watches
    'fitbit sense',
    'fitbit versa',
    // Others
    'amazfit',
    'huawei watch',
    'ticwatch',
    'fossil',
  ];

  /// Known fitness band patterns
  static const List<String> wristBandPatterns = [
    // Xiaomi
    'mi band',
    'xiaomi band',
    'mi smart band',
    // Fitbit bands
    'fitbit charge',
    'fitbit inspire',
    'fitbit luxe',
    // Huawei bands
    'huawei band',
    'honor band',
    // Samsung bands
    'galaxy fit',
    // Others
    'vivosmart',
    'vivosport',
  ];

  // ============================================================
  // IDENTIFICATION METHODS
  // ============================================================

  /// Identify device type from BLE device name
  ///
  /// Checks patterns in priority order:
  /// 1. Chest straps (highest value identification)
  /// 2. Wrist watches
  /// 3. Fitness bands
  /// 4. Unknown (fallback)
  static HrDeviceType identifyDevice(String deviceName) {
    final nameLower = deviceName.toLowerCase();

    // Check chest straps first (highest priority)
    for (final pattern in chestStrapPatterns) {
      if (nameLower.contains(pattern)) {
        return HrDeviceType.chestStrap;
      }
    }

    // Check wrist watches
    for (final pattern in wristWatchPatterns) {
      if (nameLower.contains(pattern)) {
        return HrDeviceType.wristWatch;
      }
    }

    // Check fitness bands
    for (final pattern in wristBandPatterns) {
      if (nameLower.contains(pattern)) {
        return HrDeviceType.wristBand;
      }
    }

    return HrDeviceType.unknown;
  }

  /// Get trust multiplier for device type
  static double getTrustMultiplier(HrDeviceType type) {
    switch (type) {
      case HrDeviceType.chestStrap:
        return chestStrapMultiplier;
      case HrDeviceType.wristWatch:
        return wristWatchMultiplier;
      case HrDeviceType.wristBand:
        return wristBandMultiplier;
      case HrDeviceType.unknown:
        return unknownDeviceMultiplier;
    }
  }

  /// Convenience method: get multiplier directly from device name
  ///
  /// Combines [identifyDevice] and [getTrustMultiplier] in one call.
  static double getMultiplierForDevice(String deviceName) {
    return getTrustMultiplier(identifyDevice(deviceName));
  }

  /// Check if a device name matches a chest strap pattern
  static bool isChestStrap(String deviceName) {
    return identifyDevice(deviceName) == HrDeviceType.chestStrap;
  }
}
