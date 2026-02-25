import 'package:flutter/foundation.dart';

/// Configuration for database seeding in development
class SeedConfig {
  // Master switch - only seed in debug mode
  static bool get isEnabled => kDebugMode;

  // SharedPreferences key to track if DB has been seeded
  // Change the version number to force re-seeding (e.g., 'v2', 'v3')
  static const String seedFlagKey = 'database_seeded_v4';

  // Feature flags - enable/disable seeding for specific entities
  static const bool seedUsers = true;
  static const bool seedBenefits = true;
  static const bool seedSessions = true;
  static const bool seedUserBenefits = true;
  static const bool seedGpsPoints = true;
  static const bool seedUserBiometrics = true; // v3
  static const bool seedUserPreferences = true; // v3
  static const bool seedWearableDevices = true; // v4
  static const bool seedBiometricSensorData = true; // v4
  static const bool seedMotionSensorData = true; // v4
  static const bool seedSensorSummaries = true; // v4
  static const bool seedHealthPlatformData = true; // v4

  // Logging configuration
  static const bool verboseLogging = true;

  // Reset flag - set to true to force re-seed on next launch
  // Remember to set back to false after testing!
  static const bool forceReseed = false;
}
