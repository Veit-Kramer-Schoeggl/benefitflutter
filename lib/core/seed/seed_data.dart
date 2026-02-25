import 'package:benefitflutter/core/utils/password_utils.dart';
import 'package:benefitflutter/features/user/domain/user.dart';
import 'package:benefitflutter/features/user/domain/user_biometrics_reported.dart';
import 'package:benefitflutter/features/user/domain/user_preferences.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/benefit/domain/benefit.dart';
import 'package:benefitflutter/features/benefit/domain/user_benefit.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/features/wearable_integration/domain/wearable_device.dart';
import 'package:benefitflutter/features/wearable_integration/domain/sensor_data_point.dart';
import 'package:benefitflutter/features/wearable_integration/domain/health_data_type.dart';
import 'package:benefitflutter/features/wearable_integration/domain/enums.dart';

/// Centralized seed data for development
///
/// All test users, sessions, and benefits are defined here.
/// Update this file to change the baseline data all developers get.
class SeedData {
  // ========================================
  // CONSTANTS
  // ========================================

  static const String testUserId = 'test-user-123';
  static const String testUserId2 = 'test-user-321';

  // ========================================
  // USERS
  // ========================================

  /// Default password for test users: '1234'
  static const String _defaultPassword = '1234';

  static List<User> getUsers() {
    // Hash the default password for storage
    final hashedPassword = PasswordUtils.hashPassword(_defaultPassword);

    return [
      User(
        id: testUserId,
        name: 'Test Developer',
        email: 'test@gmail.com',
        passwordHash: hashedPassword,
        displayName: 'Dev Tester',
        gender: 'male',
        dateOfBirth: DateTime(1990, 5, 15), // 35 years old
        timezone: 'Europe/Vienna',
      ),
      User(
        id: testUserId2,
        name: 'Sarah Runner',
        email: 'test2@gmail.com',
        passwordHash: hashedPassword,
        displayName: 'Sarah',
        gender: 'female',
        dateOfBirth: DateTime(1995, 8, 22), // 30 years old
        timezone: 'Europe/Berlin',
      ),
    ];
  }

  // ========================================
  // BENEFITS (Reward Templates)
  // ========================================

  static List<Benefit> getBenefits() {
    return [
      Benefit(
        id: 'benefit-5-euro',
        title: '5 Euro Discount',
        description: 'Complete 5 sessions to unlock',
        discountAmount: 5.0,
        requiredSessions: 5,
        createdAt: DateTime(2024, 1, 1),
      ),
      Benefit(
        id: 'benefit-10-euro',
        title: '10 Euro Discount',
        description: 'Run 10km total distance',
        discountAmount: 10.0,
        requiredDistance: 10000, // 10km in meters
        createdAt: DateTime(2024, 1, 1),
      ),
      Benefit(
        id: 'benefit-20-euro',
        title: '20 Euro Discount',
        description: 'Complete 20 sessions',
        discountAmount: 20.0,
        requiredSessions: 20,
        createdAt: DateTime(2024, 1, 1),
      ),
      Benefit(
        id: 'benefit-50-euro',
        title: '50 Euro Discount',
        description: 'Run 100km total distance',
        discountAmount: 50.0,
        requiredDistance: 100000, // 100km in meters
        createdAt: DateTime(2024, 1, 1),
      ),
    ];
  }

  // ========================================
  // SESSIONS (Historical Activity)
  // ========================================

  static List<Session> getSessions() {
    final now = DateTime.now();
    return [
      // Recent completed runs
      Session(
        id: 'session-1',
        userId: testUserId,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.running,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 1, hours: 8)),
        endTime: now.subtract(const Duration(days: 1, hours: 7, minutes: 30)),
        durationSeconds: 1800, // 30 minutes
        distanceMeters: 5000, // 5km
        trackingDate: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Session(
        id: 'session-2',
        userId: testUserId,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.walking,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 2, hours: 9)),
        endTime: now.subtract(const Duration(days: 2, hours: 8)),
        durationSeconds: 3600, // 1 hour
        distanceMeters: 4000, // 4km
        trackingDate: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Session(
        id: 'session-3',
        userId: testUserId,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.cycling,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 3, hours: 18)),
        endTime: now.subtract(const Duration(days: 3, hours: 17)),
        durationSeconds: 3600, // 1 hour
        distanceMeters: 15000, // 15km
        trackingDate: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      Session(
        id: 'session-4',
        userId: testUserId,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.running,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 5, hours: 7)),
        endTime: now.subtract(const Duration(days: 5, hours: 6, minutes: 45)),
        durationSeconds: 2700, // 45 minutes
        distanceMeters: 7500, // 7.5km
        trackingDate: now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      Session(
        id: 'session-5',
        userId: testUserId,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.walking,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 7, hours: 10)),
        endTime: now.subtract(const Duration(days: 7, hours: 9, minutes: 30)),
        durationSeconds: 1800, // 30 minutes
        distanceMeters: 3000, // 3km
        trackingDate: now.subtract(const Duration(days: 7)),
        createdAt: now.subtract(const Duration(days: 7)),
      ),

      // One active session (for Activity screen testing)
      Session(
        id: 'session-active',
        userId: testUserId,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.running,
        status: SessionStatus.active,
        startTime: now.subtract(const Duration(minutes: 15)),
        durationSeconds: null, // Still running
        distanceMeters: null,
        trackingDate: now,
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),

      // ========================================
      // SESSIONS FOR USER 2 (Sarah Runner)
      // ========================================

      // Recent yoga session
      Session(
        id: 'session-u2-1',
        userId: testUserId2,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.yoga,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 1, hours: 6)),
        endTime: now.subtract(const Duration(days: 1, hours: 5)),
        durationSeconds: 3600, // 1 hour
        distanceMeters: null, // No distance for yoga
        trackingDate: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      // Morning run
      Session(
        id: 'session-u2-2',
        userId: testUserId2,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.running,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 2, hours: 7)),
        endTime: now.subtract(const Duration(days: 2, hours: 6, minutes: 20)),
        durationSeconds: 2400, // 40 minutes
        distanceMeters: 6000, // 6km
        trackingDate: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      // Evening walk
      Session(
        id: 'session-u2-3',
        userId: testUserId2,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.walking,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 3, hours: 19)),
        endTime: now.subtract(const Duration(days: 3, hours: 18, minutes: 30)),
        durationSeconds: 1800, // 30 minutes
        distanceMeters: 2500, // 2.5km
        trackingDate: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      // Long cycling session
      Session(
        id: 'session-u2-4',
        userId: testUserId2,
        trackingMode: TrackingMode.manual,
        activityType: ActivityType.cycling,
        status: SessionStatus.completed,
        startTime: now.subtract(const Duration(days: 4, hours: 10)),
        endTime: now.subtract(const Duration(days: 4, hours: 8)),
        durationSeconds: 7200, // 2 hours
        distanceMeters: 35000, // 35km
        trackingDate: now.subtract(const Duration(days: 4)),
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];
  }

  // ========================================
  // USER BENEFITS (Earned Rewards)
  // ========================================

  static List<UserBenefit> getUserBenefits() {
    final now = DateTime.now();
    return [
      // User 1 earned the 5 Euro benefit after completing 5 sessions
      UserBenefit(
        id: 'ub-1',
        userId: testUserId,
        benefitId: 'benefit-5-euro',
        sessionId: 'session-5', // Earned on 5th session
        earnedAt: now.subtract(const Duration(days: 7)),
      ),
      // User 2 earned the 10 Euro benefit (distance-based)
      UserBenefit(
        id: 'ub-2',
        userId: testUserId2,
        benefitId: 'benefit-10-euro',
        sessionId: 'session-u2-4', // Earned after cycling 35km
        earnedAt: now.subtract(const Duration(days: 4)),
      ),
    ];
  }

  // ========================================
  // GPS POINTS (Tracking Data)
  // ========================================

  static List<GpsPoint> getGpsPoints() {
    final now = DateTime.now();
    // GPS points for session-1 (5km run, 30 minutes, completed 1 day ago)
    final sessionStartTime = now.subtract(const Duration(days: 1, hours: 8));

    return [
      // Point 1: Start of run (0km)
      GpsPoint(
        id: 'gps-1-1',
        sessionId: 'session-1',
        latitude: 52.520008,
        longitude: 13.404954,
        altitude: 34.0,
        accuracyMeters: 8.5,
        speedMetersPerSecond: 0.0,
        timestamp: sessionStartTime,
        createdAt: sessionStartTime,
      ),

      // Point 2: ~600m into run (4 min)
      GpsPoint(
        id: 'gps-1-2',
        sessionId: 'session-1',
        latitude: 52.524012,
        longitude: 13.408120,
        altitude: 36.5,
        accuracyMeters: 6.2,
        speedMetersPerSecond: 2.5, // ~9 km/h
        timestamp: sessionStartTime.add(const Duration(minutes: 4)),
        createdAt: sessionStartTime.add(const Duration(minutes: 4)),
      ),

      // Point 3: ~1200m into run (8 min)
      GpsPoint(
        id: 'gps-1-3',
        sessionId: 'session-1',
        latitude: 52.527890,
        longitude: 13.411450,
        altitude: 38.2,
        accuracyMeters: 5.8,
        speedMetersPerSecond: 2.7, // ~9.7 km/h
        timestamp: sessionStartTime.add(const Duration(minutes: 8)),
        createdAt: sessionStartTime.add(const Duration(minutes: 8)),
      ),

      // Point 4: ~2000m into run (13 min)
      GpsPoint(
        id: 'gps-1-4',
        sessionId: 'session-1',
        latitude: 52.531245,
        longitude: 13.414890,
        altitude: 35.8,
        accuracyMeters: 7.1,
        speedMetersPerSecond: 2.4, // ~8.6 km/h (slowing down)
        timestamp: sessionStartTime.add(const Duration(minutes: 13)),
        createdAt: sessionStartTime.add(const Duration(minutes: 13)),
      ),

      // Point 5: ~3000m into run (19 min)
      GpsPoint(
        id: 'gps-1-5',
        sessionId: 'session-1',
        latitude: 52.534678,
        longitude: 13.418234,
        altitude: 37.5,
        accuracyMeters: 6.5,
        speedMetersPerSecond: 2.6, // ~9.4 km/h
        timestamp: sessionStartTime.add(const Duration(minutes: 19)),
        createdAt: sessionStartTime.add(const Duration(minutes: 19)),
      ),

      // Point 6: ~3800m into run (24 min)
      GpsPoint(
        id: 'gps-1-6',
        sessionId: 'session-1',
        latitude: 52.537890,
        longitude: 13.421567,
        altitude: 39.0,
        accuracyMeters: 5.5,
        speedMetersPerSecond: 2.8, // ~10 km/h (final push)
        timestamp: sessionStartTime.add(const Duration(minutes: 24)),
        createdAt: sessionStartTime.add(const Duration(minutes: 24)),
      ),

      // Point 7: ~4500m into run (28 min)
      GpsPoint(
        id: 'gps-1-7',
        sessionId: 'session-1',
        latitude: 52.540456,
        longitude: 13.424789,
        altitude: 38.2,
        accuracyMeters: 6.8,
        speedMetersPerSecond: 3.0, // ~10.8 km/h (sprinting)
        timestamp: sessionStartTime.add(const Duration(minutes: 28)),
        createdAt: sessionStartTime.add(const Duration(minutes: 28)),
      ),

      // Point 8: End of run (~5000m, 30 min)
      GpsPoint(
        id: 'gps-1-8',
        sessionId: 'session-1',
        latitude: 52.542789,
        longitude: 13.427890,
        altitude: 36.8,
        accuracyMeters: 7.2,
        speedMetersPerSecond: 0.5, // Slowing to stop
        timestamp: sessionStartTime.add(const Duration(minutes: 30)),
        createdAt: sessionStartTime.add(const Duration(minutes: 30)),
      ),
    ];
  }

  // ========================================
  // USER BIOMETRICS (v3 - Profile Support)
  // ========================================

  static List<UserBiometricsReported> getUserBiometrics() {
    final now = DateTime.now();
    return [
      // Initial entry (30 days ago)
      UserBiometricsReported(
        id: 'biometrics-1',
        userId: testUserId,
        reportDate: now.subtract(const Duration(days: 30)),
        heightCm: 175,
        weightKg: 72.5,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      ),
      // Mid entry (15 days ago) - weight loss
      UserBiometricsReported(
        id: 'biometrics-2',
        userId: testUserId,
        reportDate: now.subtract(const Duration(days: 15)),
        heightCm: 175,
        weightKg: 71.8,
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
      // Recent entry (2 days ago) - continued progress
      UserBiometricsReported(
        id: 'biometrics-3',
        userId: testUserId,
        reportDate: now.subtract(const Duration(days: 2)),
        heightCm: 175,
        weightKg: 71.2,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),

      // ========================================
      // BIOMETRICS FOR USER 2 (Sarah Runner)
      // ========================================

      // Initial entry (20 days ago)
      UserBiometricsReported(
        id: 'biometrics-u2-1',
        userId: testUserId2,
        reportDate: now.subtract(const Duration(days: 20)),
        heightCm: 165,
        weightKg: 58.5,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 20)),
      ),
      // Recent entry (3 days ago)
      UserBiometricsReported(
        id: 'biometrics-u2-2',
        userId: testUserId2,
        reportDate: now.subtract(const Duration(days: 3)),
        heightCm: 165,
        weightKg: 58.0,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  // ========================================
  // USER PREFERENCES (v3 - Profile Support)
  // ========================================

  static List<UserPreferences> getUserPreferences() {
    final now = DateTime.now();
    return [
      UserPreferences(
        id: 'prefs-1',
        userId: testUserId,
        defaultLocationCity: 'Vienna',
        distanceUnit: 'metric',
        temperatureUnit: 'celsius',
        weightUnit: 'kg',
        theme: 'system',
        language: 'en',
        timezone: 'Europe/Vienna',
        createdAt: now,
        updatedAt: now,
      ),
      // User 2 preferences (Sarah - Berlin)
      UserPreferences(
        id: 'prefs-2',
        userId: testUserId2,
        defaultLocationCity: 'Berlin',
        distanceUnit: 'metric',
        temperatureUnit: 'celsius',
        weightUnit: 'kg',
        theme: 'dark',
        language: 'de',
        timezone: 'Europe/Berlin',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  // ========================================
  // WEARABLE DEVICES (v4 - Wearable Integration)
  // ========================================

  static List<WearableDevice> getWearableDevices() {
    final now = DateTime.now();
    return [
      // Bluetooth heart rate monitor
      WearableDevice(
        id: 'device-polar-h10',
        name: 'Polar H10',
        type: WearableDeviceType.heartRateMonitor,
        source: IntegrationSource.ble,
        status: ConnectionStatus.connected,
        capabilities: [SensorType.heartRate, SensorType.heartRateVariability],
        userId: testUserId,
        lastSyncTime: now.subtract(const Duration(days: 1)),
        metadata: {
          'batteryLevel': 85,
          'firmwareVersion': '3.0.35',
          'rssi': -65,
        },
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),

      // Health Connect virtual device
      WearableDevice(
        id: 'device-health-connect',
        name: 'Health Connect',
        type: WearableDeviceType.unknown,
        source: IntegrationSource.healthConnect,
        status: ConnectionStatus.connected,
        capabilities: [
          SensorType.heartRate,
          SensorType.steps,
          SensorType.distance,
          SensorType.calories,
        ],
        userId: testUserId,
        lastSyncTime: now,
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now,
      ),

      // Smartwatch (disconnected example)
      WearableDevice(
        id: 'device-garmin-watch',
        name: 'Garmin Forerunner 245',
        type: WearableDeviceType.smartwatch,
        source: IntegrationSource.ble,
        status: ConnectionStatus.disconnected,
        capabilities: [
          SensorType.heartRate,
          SensorType.steps,
          SensorType.cadence,
          SensorType.bloodOxygen,
        ],
        userId: testUserId,
        lastSyncTime: now.subtract(const Duration(days: 5)),
        metadata: {
          'batteryLevel': 45,
          'firmwareVersion': '4.20',
        },
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),

      // ========================================
      // WEARABLE DEVICES FOR USER 2 (Sarah Runner)
      // ========================================

      // Apple Watch
      WearableDevice(
        id: 'device-apple-watch-u2',
        name: 'Apple Watch Series 8',
        type: WearableDeviceType.smartwatch,
        source: IntegrationSource.healthKit,
        status: ConnectionStatus.connected,
        capabilities: [
          SensorType.heartRate,
          SensorType.steps,
          SensorType.distance,
          SensorType.calories,
          SensorType.bloodOxygen,
        ],
        userId: testUserId2,
        lastSyncTime: now.subtract(const Duration(hours: 2)),
        metadata: {
          'batteryLevel': 72,
          'firmwareVersion': '10.2',
        },
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  // ========================================
  // BIOMETRIC SENSOR DATA (Heart Rate during sessions)
  // ========================================

  static List<SensorDataPoint> getBiometricSensorData() {
    final now = DateTime.now();
    final sessionStartTime = now.subtract(const Duration(days: 1, hours: 8));
    final List<SensorDataPoint> dataPoints = [];

    // Heart rate data for session-1 (5km run, 30 minutes)
    // Simulate realistic heart rate progression during a run
    final heartRateProfile = [
      {'min': 0, 'hr': 75},  // Resting
      {'min': 2, 'hr': 110}, // Warm up
      {'min': 5, 'hr': 140}, // Getting into rhythm
      {'min': 10, 'hr': 155}, // Steady state
      {'min': 15, 'hr': 160}, // Maintaining
      {'min': 20, 'hr': 158}, // Slight fatigue
      {'min': 25, 'hr': 165}, // Final push
      {'min': 28, 'hr': 170}, // Sprint finish
      {'min': 30, 'hr': 145}, // Cool down start
    ];

    for (final point in heartRateProfile) {
      dataPoints.add(SensorDataPoint(
        sessionId: 'session-1',
        deviceId: 'device-polar-h10',
        sensorType: SensorType.heartRate,
        value: (point['hr'] as int).toDouble(),
        timestamp: sessionStartTime.add(Duration(minutes: point['min'] as int)),
        accuracy: 0.98,
      ));
    }

    // Add HRV data (every 5 minutes)
    for (int i = 0; i <= 30; i += 5) {
      dataPoints.add(SensorDataPoint(
        sessionId: 'session-1',
        deviceId: 'device-polar-h10',
        sensorType: SensorType.heartRateVariability,
        value: 45.0 - (i / 2), // HRV decreases during exercise
        timestamp: sessionStartTime.add(Duration(minutes: i)),
        accuracy: 0.95,
        metadata: {'rr_intervals': '[850, 840, 855, 845]'},
      ));
    }

    return dataPoints;
  }

  // ========================================
  // MOTION SENSOR DATA (Steps, Cadence during sessions)
  // ========================================

  static List<SensorDataPoint> getMotionSensorData() {
    final now = DateTime.now();
    final sessionStartTime = now.subtract(const Duration(days: 1, hours: 8));
    final List<SensorDataPoint> dataPoints = [];

    // Cadence data for session-1 (running cadence: steps per minute)
    final cadenceProfile = [
      {'min': 2, 'cadence': 160},
      {'min': 5, 'cadence': 172},
      {'min': 10, 'cadence': 175},
      {'min': 15, 'cadence': 174},
      {'min': 20, 'cadence': 170}, // Tiring
      {'min': 25, 'cadence': 168},
      {'min': 28, 'cadence': 180}, // Sprint finish
    ];

    for (final point in cadenceProfile) {
      dataPoints.add(SensorDataPoint(
        sessionId: 'session-1',
        deviceId: 'device-polar-h10',
        sensorType: SensorType.cadence,
        value: (point['cadence'] as int).toDouble(),
        timestamp: sessionStartTime.add(Duration(minutes: point['min'] as int)),
        accuracy: 0.92,
      ));
    }

    // Total steps for the session (accumulated at end)
    dataPoints.add(SensorDataPoint(
      sessionId: 'session-1',
      deviceId: 'device-health-connect',
      sensorType: SensorType.steps,
      value: 5200.0, // ~30 min * 173 avg cadence
      timestamp: sessionStartTime.add(const Duration(minutes: 30)),
      accuracy: 1.0,
    ));

    return dataPoints;
  }

  // ========================================
  // SENSOR SUMMARIES (Aggregated data per session)
  // ========================================

  static List<SessionSensorSummary> getSensorSummaries() {
    final now = DateTime.now();
    return [
      // Summary for session-1 (5km run with heart rate data)
      SessionSensorSummary(
        sessionId: 'session-1',
        avgHeartRate: 155.5,
        maxHeartRate: 170,
        minHeartRate: 110,
        avgHeartRateVariability: 35.8,
        heartRateZones: {
          'zone1': 120,  // Warm up (2 min)
          'zone2': 600,  // Aerobic (10 min)
          'zone3': 900,  // Threshold (15 min)
          'zone4': 180,  // Max effort (3 min)
        },
        totalSteps: 5200,
        avgCadence: 172.5,
        caloriesBurned: 425.0,
        dataSources: ['ble:device-polar-h10', 'healthConnect'],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),

      // Summary for session-4 (7.5km run, moderate intensity)
      SessionSensorSummary(
        sessionId: 'session-4',
        avgHeartRate: 148.0,
        maxHeartRate: 162,
        minHeartRate: 105,
        heartRateZones: {
          'zone1': 180,  // Warm up
          'zone2': 1200, // Aerobic
          'zone3': 1320, // Threshold
        },
        totalSteps: 7800,
        avgCadence: 168.0,
        caloriesBurned: 640.0,
        dataSources: ['healthConnect'],
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
    ];
  }

  // ========================================
  // HEALTH PLATFORM DATA (Historical data from Health Connect/HealthKit)
  // ========================================

  static List<HealthDataPoint> getHealthPlatformData() {
    final now = DateTime.now();
    final List<HealthDataPoint> dataPoints = [];

    // Daily step counts for past 7 days
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      dataPoints.add(HealthDataPoint(
        userId: testUserId,
        dataType: HealthDataType.steps,
        value: (8500 + (i * 500)).toString(), // Varying daily steps
        startTime: dayStart,
        endTime: dayEnd,
        sourceApp: 'Google Fit',
        syncedAt: now,
      ));
    }

    // Resting heart rate samples
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day, 7); // Morning

      dataPoints.add(HealthDataPoint(
        userId: testUserId,
        dataType: HealthDataType.restingHeartRate,
        value: (58 + (i % 3)).toString(), // Varying resting HR
        startTime: dayStart,
        endTime: dayStart.add(const Duration(minutes: 5)),
        sourceApp: 'Google Fit',
        syncedAt: now,
      ));
    }

    // Weight measurements
    dataPoints.add(HealthDataPoint(
      userId: testUserId,
      dataType: HealthDataType.weight,
      value: '71.2',
      startTime: now.subtract(const Duration(days: 2, hours: 8)),
      endTime: now.subtract(const Duration(days: 2, hours: 8)),
      sourceApp: 'Health Connect',
      syncedAt: now.subtract(const Duration(days: 2)),
    ));

    // VO2 Max estimate
    dataPoints.add(HealthDataPoint(
      userId: testUserId,
      dataType: HealthDataType.vo2Max,
      value: '48.5',
      startTime: now.subtract(const Duration(days: 5)),
      endTime: now.subtract(const Duration(days: 5)),
      sourceApp: 'Garmin Connect',
      metadata: {'sport': 'running'},
      syncedAt: now.subtract(const Duration(days: 5)),
    ));

    // ========================================
    // HEALTH PLATFORM DATA FOR USER 2 (Sarah Runner)
    // ========================================

    // Daily step counts for past 5 days
    for (int i = 0; i < 5; i++) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      dataPoints.add(HealthDataPoint(
        userId: testUserId2,
        dataType: HealthDataType.steps,
        value: (10500 + (i * 300)).toString(), // Higher daily steps
        startTime: dayStart,
        endTime: dayEnd,
        sourceApp: 'Apple Health',
        syncedAt: now,
      ));
    }

    // Resting heart rate for user 2
    for (int i = 0; i < 5; i++) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day, 6);

      dataPoints.add(HealthDataPoint(
        userId: testUserId2,
        dataType: HealthDataType.restingHeartRate,
        value: (52 + (i % 2)).toString(), // Lower resting HR (fitter)
        startTime: dayStart,
        endTime: dayStart.add(const Duration(minutes: 5)),
        sourceApp: 'Apple Health',
        syncedAt: now,
      ));
    }

    // Weight for user 2
    dataPoints.add(HealthDataPoint(
      userId: testUserId2,
      dataType: HealthDataType.weight,
      value: '58.0',
      startTime: now.subtract(const Duration(days: 3, hours: 7)),
      endTime: now.subtract(const Duration(days: 3, hours: 7)),
      sourceApp: 'Apple Health',
      syncedAt: now.subtract(const Duration(days: 3)),
    ));

    // VO2 Max for user 2
    dataPoints.add(HealthDataPoint(
      userId: testUserId2,
      dataType: HealthDataType.vo2Max,
      value: '42.0',
      startTime: now.subtract(const Duration(days: 2)),
      endTime: now.subtract(const Duration(days: 2)),
      sourceApp: 'Apple Health',
      metadata: {'sport': 'running'},
      syncedAt: now.subtract(const Duration(days: 2)),
    ));

    return dataPoints;
  }

  // ========================================
  // SUMMARY STATS (for logging)
  // ========================================

  static Map<String, dynamic> getSeedSummary() {
    return {
      'users': getUsers().length,
      'benefits': getBenefits().length,
      'sessions': getSessions().length,
      'userBenefits': getUserBenefits().length,
      'gpsPoints': getGpsPoints().length,
      'userBiometrics': getUserBiometrics().length,
      'userPreferences': getUserPreferences().length,
      'wearableDevices': getWearableDevices().length,
      'biometricSensorData': getBiometricSensorData().length,
      'motionSensorData': getMotionSensorData().length,
      'sensorSummaries': getSensorSummaries().length,
      'healthPlatformData': getHealthPlatformData().length,
      'totalDistance': getSessions()
          .where((s) => s.distanceMeters != null)
          .fold(0.0, (sum, s) => sum + s.distanceMeters!),
      'totalDuration': getSessions()
          .where((s) => s.durationSeconds != null)
          .fold(0, (sum, s) => sum + s.durationSeconds!),
    };
  }
}
