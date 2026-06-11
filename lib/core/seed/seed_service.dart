import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:benefitflutter/core/seed/seed_config.dart';
import 'package:benefitflutter/core/seed/seed_data.dart';
import 'package:benefitflutter/features/user/data/user_repository.dart';
import 'package:benefitflutter/features/user/data/user_biometrics_dao.dart';
import 'package:benefitflutter/features/user/data/user_preferences_dao.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/data/gps_point_dao.dart';
import 'package:benefitflutter/features/benefit/data/benefit_repository.dart';
import 'package:benefitflutter/features/benefit/data/benefit_dao.dart';
import 'package:benefitflutter/features/shared/database/database_helper.dart';
import 'package:benefitflutter/features/wearable_integration/data/daos/wearable_device_dao.dart';
import 'package:benefitflutter/features/wearable_integration/data/daos/session_biometric_data_dao.dart';
import 'package:benefitflutter/features/wearable_integration/data/daos/session_motion_data_dao.dart';
import 'package:benefitflutter/features/wearable_integration/data/daos/session_sensor_summary_dao.dart';
import 'package:benefitflutter/features/wearable_integration/data/daos/health_platform_data_dao.dart';

/// Service to populate database with test data in development
///
/// Usage:
///   final seedService = await SeedService.create(...);
///   await seedService.seedIfNeeded();
class SeedService {
  final UserRepository _userRepository;
  final SessionRepository _sessionRepository;
  final BenefitRepository _benefitRepository;
  final DatabaseHelper _databaseHelper;
  final SharedPreferences _prefs;

  SeedService({
    required UserRepository userRepository,
    required SessionRepository sessionRepository,
    required BenefitRepository benefitRepository,
    required DatabaseHelper databaseHelper,
    required SharedPreferences prefs,
  }) : _userRepository = userRepository,
       _sessionRepository = sessionRepository,
       _benefitRepository = benefitRepository,
       _databaseHelper = databaseHelper,
       _prefs = prefs;

  /// Factory constructor for easy creation
  static Future<SeedService> create({
    required UserRepository userRepository,
    required SessionRepository sessionRepository,
    required BenefitRepository benefitRepository,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final databaseHelper = DatabaseHelper();
    return SeedService(
      userRepository: userRepository,
      sessionRepository: sessionRepository,
      benefitRepository: benefitRepository,
      databaseHelper: databaseHelper,
      prefs: prefs,
    );
  }

  // ========================================
  // PUBLIC API
  // ========================================

  /// Seeds database if needed (checks flag)
  Future<bool> seedIfNeeded() async {
    if (!SeedConfig.isEnabled) {
      _log('❌ Seeding disabled (not in debug mode)');
      return false;
    }

    final hasSeeded = _hasBeenSeeded();

    if (hasSeeded && !SeedConfig.forceReseed) {
      _log('✅ Database already seeded');
      return false;
    }

    if (SeedConfig.forceReseed) {
      _log('🔄 Force reseed enabled');
    }

    await seedDatabase();
    return true;
  }

  /// Force seed the database (ignores flag)
  Future<void> seedDatabase() async {
    if (!SeedConfig.isEnabled) {
      _log('❌ Seeding disabled (not in debug mode)');
      return;
    }

    final startTime = DateTime.now();
    _log('🌱 Starting database seeding...');

    try {
      // Seed in order of dependencies: Users → Prefs → Biometrics → Benefits → Sessions → GPS → Wearable Devices → Sensor Data → Summaries → Health Data → UserBenefits
      if (SeedConfig.seedUsers) await _seedUsers();
      if (SeedConfig.seedUserPreferences) await _seedUserPreferences();
      if (SeedConfig.seedUserBiometrics) await _seedUserBiometrics();
      if (SeedConfig.seedBenefits) await _seedBenefits();
      if (SeedConfig.seedSessions) await _seedSessions();
      if (SeedConfig.seedGpsPoints) await _seedGpsPoints();
      if (SeedConfig.seedWearableDevices) await _seedWearableDevices();
      if (SeedConfig.seedBiometricSensorData) await _seedBiometricSensorData();
      if (SeedConfig.seedMotionSensorData) await _seedMotionSensorData();
      if (SeedConfig.seedSensorSummaries) await _seedSensorSummaries();
      if (SeedConfig.seedHealthPlatformData) await _seedHealthPlatformData();
      if (SeedConfig.seedUserBenefits) await _seedUserBenefits();

      // Mark as seeded
      await _prefs.setBool(SeedConfig.seedFlagKey, true);

      final duration = DateTime.now().difference(startTime);
      _log('✅ Seeding completed in ${duration.inMilliseconds}ms');
      _logSummary();
    } catch (e, stackTrace) {
      _log('❌ Seeding failed: $e');
      if (SeedConfig.verboseLogging) {
        debugPrint(stackTrace.toString());
      }
      rethrow;
    }
  }

  /// Clear seed flag (allows re-seeding on next launch)
  Future<void> clearSeedFlag() async {
    await _prefs.remove(SeedConfig.seedFlagKey);
    _log('🗑️ Seed flag cleared');
  }

  /// Clear seed flag and force re-seed (debug only)
  ///
  /// This method:
  /// 1. Clears all data from database tables
  /// 2. Removes the SharedPreferences seed flag
  /// 3. Forces database seeding with fresh data
  /// 4. Only works in debug mode for safety
  ///
  /// Use cases:
  /// - Development: Reset to clean baseline data
  /// - QA Testing: Need fresh seed data for testing
  /// - Demos: Reset to clean demo state
  /// - Fix: Remove duplicate benefits from multiple reseeds
  Future<void> clearAndReseed() async {
    // Safety check: Only allow in debug mode
    if (!SeedConfig.isEnabled) {
      _log('❌ Cannot reseed - not in debug mode');
      throw Exception('Reseed is only available in debug mode');
    }

    _log('🗑️ Clearing database and forcing re-seed...');

    try {
      // Step 1: Clear all database tables
      _log('  Clearing all tables...');
      await _databaseHelper.clearAllTables();
      _log('✓ All tables cleared');

      // Step 2: Clear the SharedPreferences flag
      await _prefs.remove(SeedConfig.seedFlagKey);
      _log('✓ Seed flag cleared');

      // Step 3: Force database seeding
      await seedDatabase();

      _log('✅ Reseed completed successfully');
    } catch (e, stackTrace) {
      _log('❌ Reseed failed: $e');
      if (SeedConfig.verboseLogging) {
        debugPrint(stackTrace.toString());
      }
      rethrow; // Let UI handle the error
    }
  }

  // ========================================
  // PRIVATE SEEDING METHODS
  // ========================================

  Future<void> _seedUsers() async {
    _log('👤 Seeding users...');
    final users = SeedData.getUsers();

    for (final user in users) {
      try {
        await _userRepository.createUser(user);
        _log('  ✓ Created user: ${user.name} (${user.email})');
      } catch (e) {
        _log('  ✗ Failed to create user ${user.name}: $e');
        // Continue with other users
      }
    }
  }

  Future<void> _seedBenefits() async {
    _log('🎁 Seeding benefits...');
    final benefits = SeedData.getBenefits();
    final benefitDao = BenefitDao();

    for (final benefit in benefits) {
      try {
        await benefitDao.insertBenefit(benefit);
        _log(
          '  ✓ Created benefit: ${benefit.title} (€${benefit.discountAmount})',
        );
      } catch (e) {
        _log('  ✗ Failed to create benefit ${benefit.title}: $e');
      }
    }
  }

  Future<void> _seedSessions() async {
    _log('🏃 Seeding sessions...');
    final sessions = SeedData.getSessions();

    for (final session in sessions) {
      try {
        await _sessionRepository.createSession(session);
        final status = session.status.name;
        final distance = session.distanceMeters != null
            ? '${(session.distanceMeters! / 1000).toStringAsFixed(1)}km'
            : 'N/A';
        _log(
          '  ✓ Created session: ${session.activityType.name} - $distance ($status)',
        );
      } catch (e) {
        _log('  ✗ Failed to create session ${session.id}: $e');
      }
    }
  }

  Future<void> _seedGpsPoints() async {
    _log('📍 Seeding GPS points...');
    final gpsPoints = SeedData.getGpsPoints();
    final gpsPointDao = GpsPointDao();

    for (final gpsPoint in gpsPoints) {
      try {
        await gpsPointDao.insert(gpsPoint);
        _log(
          '  ✓ Created GPS point: ${gpsPoint.latitude.toStringAsFixed(4)}, ${gpsPoint.longitude.toStringAsFixed(4)}',
        );
      } catch (e) {
        _log('  ✗ Failed to create GPS point ${gpsPoint.id}: $e');
      }
    }
  }

  Future<void> _seedUserBenefits() async {
    _log('🏆 Seeding user benefits...');
    final userBenefits = SeedData.getUserBenefits();

    for (final userBenefit in userBenefits) {
      try {
        await _benefitRepository.awardBenefit(
          userId: userBenefit.userId,
          benefitId: userBenefit.benefitId,
          sessionId: userBenefit.sessionId,
        );
        _log('  ✓ Awarded benefit: ${userBenefit.benefitId}');
      } catch (e) {
        _log('  ✗ Failed to award benefit ${userBenefit.benefitId}: $e');
      }
    }
  }

  Future<void> _seedUserBiometrics() async {
    _log('📊 Seeding user biometrics...');
    final biometrics = SeedData.getUserBiometrics();
    final biometricsDao = UserBiometricsDao();

    for (final biometric in biometrics) {
      try {
        await biometricsDao.insert(biometric);
        _log(
          '  ✓ Created biometric: ${biometric.heightCm}cm, ${biometric.weightKg}kg',
        );
      } catch (e) {
        _log('  ✗ Failed to create biometric: $e');
      }
    }
  }

  Future<void> _seedUserPreferences() async {
    _log('⚙️ Seeding user preferences...');
    final preferences = SeedData.getUserPreferences();
    final prefsDao = UserPreferencesDao();

    for (final pref in preferences) {
      try {
        await prefsDao.insert(pref);
        _log(
          '  ✓ Created preferences: ${pref.defaultLocationCity}, ${pref.distanceUnit}',
        );
      } catch (e) {
        _log('  ✗ Failed to create preferences: $e');
      }
    }
  }

  Future<void> _seedWearableDevices() async {
    _log('⌚ Seeding wearable devices...');
    final devices = SeedData.getWearableDevices();
    final deviceDao = WearableDeviceDao();

    for (final device in devices) {
      try {
        await deviceDao.insert(device);
        _log('  ✓ Created device: ${device.name} (${device.type.displayName})');
      } catch (e) {
        _log('  ✗ Failed to create device ${device.name}: $e');
      }
    }
  }

  Future<void> _seedBiometricSensorData() async {
    _log('💓 Seeding biometric sensor data...');
    final dataPoints = SeedData.getBiometricSensorData();
    final biometricDao = SessionBiometricDataDao();

    try {
      await biometricDao.insertBatch(dataPoints);
      _log('  ✓ Created ${dataPoints.length} biometric data points');
    } catch (e) {
      _log('  ✗ Failed to create biometric data: $e');
    }
  }

  Future<void> _seedMotionSensorData() async {
    _log('🏃 Seeding motion sensor data...');
    final dataPoints = SeedData.getMotionSensorData();
    final motionDao = SessionMotionDataDao();

    try {
      await motionDao.insertBatch(dataPoints);
      _log('  ✓ Created ${dataPoints.length} motion data points');
    } catch (e) {
      _log('  ✗ Failed to create motion data: $e');
    }
  }

  Future<void> _seedSensorSummaries() async {
    _log('📊 Seeding sensor summaries...');
    final summaries = SeedData.getSensorSummaries();
    final summaryDao = SessionSensorSummaryDao();

    for (final summary in summaries) {
      try {
        await summaryDao.upsert(summary);
        final avgHR = summary.avgHeartRate?.toStringAsFixed(1) ?? 'N/A';
        final steps = summary.totalSteps?.toString() ?? 'N/A';
        _log('  ✓ Created summary: Avg HR: $avgHR BPM, Steps: $steps');
      } catch (e) {
        _log('  ✗ Failed to create summary: $e');
      }
    }
  }

  Future<void> _seedHealthPlatformData() async {
    _log('🏥 Seeding health platform data...');
    final dataPoints = SeedData.getHealthPlatformData();
    final healthDao = HealthPlatformDataDao();

    try {
      await healthDao.insertBatch(dataPoints);
      _log('  ✓ Created ${dataPoints.length} health platform data points');
    } catch (e) {
      _log('  ✗ Failed to create health platform data: $e');
    }
  }

  // ========================================
  // HELPERS
  // ========================================

  bool _hasBeenSeeded() {
    return _prefs.getBool(SeedConfig.seedFlagKey) ?? false;
  }

  void _log(String message) {
    if (SeedConfig.verboseLogging || kDebugMode) {
      debugPrint('[SeedService] $message');
    }
  }

  void _logSummary() {
    final summary = SeedData.getSeedSummary();
    _log('📊 Seed Summary:');
    _log('   Users: ${summary['users']}');
    _log('   User Biometrics: ${summary['userBiometrics']}');
    _log('   User Preferences: ${summary['userPreferences']}');
    _log('   Benefits: ${summary['benefits']}');
    _log('   Sessions: ${summary['sessions']}');
    _log('   GPS Points: ${summary['gpsPoints']}');
    _log('   Wearable Devices: ${summary['wearableDevices']}');
    _log('   Biometric Sensor Data: ${summary['biometricSensorData']}');
    _log('   Motion Sensor Data: ${summary['motionSensorData']}');
    _log('   Sensor Summaries: ${summary['sensorSummaries']}');
    _log('   Health Platform Data: ${summary['healthPlatformData']}');
    _log('   User Benefits: ${summary['userBenefits']}');
    // getSeedSummary() is Map<String, dynamic>; these two are non-null numerics
    // (fold initial values), so a direct num cast is safe.
    _log(
      '   Total Distance: ${((summary['totalDistance'] as num) / 1000).toStringAsFixed(1)}km',
    );
    _log(
      '   Total Duration: ${((summary['totalDuration'] as num) / 60).toStringAsFixed(0)} minutes',
    );
  }
}
