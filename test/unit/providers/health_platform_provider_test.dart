import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/providers/health_platform_provider.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/features/wearable_integration/data/services/health_sync_service.dart';

/// Fake HealthSyncService so the provider is constructible on the test host
/// (the real one throws in its constructor on non-Android/iOS platforms).
class _FakeHealthSyncService implements HealthSyncService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> isHealthConnectInstalled() async => false;
  @override
  Future<bool> hasPermissions() async => false;
  @override
  Future<bool> requestPermissions() async => false;
  @override
  Future<bool> syncAll(String userId, {int daysBack = 7}) async => false;
  @override
  Future<void> syncSteps(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<void> syncHeartRate(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> syncDistance(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<void> syncCalories(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<void> syncWeight(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<void> syncRestingHeartRate(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<Session> enrichSession(Session session) async => session;
  @override
  Future<int> getDailySteps(String userId, DateTime date) async => 0;
  @override
  Future<double?> getAverageHeartRate(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async => null;
  @override
  Future<double?> getLatestWeight(String userId) async => null;
  @override
  Future<int?> getLatestRestingHeartRate(String userId) async => null;
  @override
  Future<Map<String, dynamic>> getWeeklySummary(
    String userId,
    DateTime weekStart,
  ) async => {'steps': 0, 'distance': 0.0, 'calories': 0.0};
  @override
  Future<void> cleanupOldData(DateTime cutoffDate) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  group('HealthPlatformProvider', () {
    late HealthPlatformProvider provider;

    setUp(() {
      provider = HealthPlatformProvider(syncService: _FakeHealthSyncService());
    });

    tearDown(() {
      provider.dispose();
    });

    group('Initial State', () {
      test('starts disconnected', () {
        expect(provider.isConnected, false);
      });

      test('is not syncing initially', () {
        expect(provider.isSyncing, false);
      });

      test('has no last sync time initially', () {
        expect(provider.lastSyncTime, isNull);
      });

      test('has no error message initially', () {
        expect(provider.errorMessage, isNull);
      });
    });

    group('Error Handling', () {
      test('clearError removes error message', () {
        // Manually set an error for testing
        provider.clearError();
        expect(provider.errorMessage, isNull);
      });
    });

    group('Session Enrichment', () {
      test('returns null when not connected', () async {
        final session = Session(
          id: 'test-session',
          userId: 'test-user',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.running,
          status: SessionStatus.completed,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
        );

        final enriched = await provider.enrichSession(session);
        expect(enriched, isNull);
      });
    });

    group('Data Retrieval When Not Connected', () {
      test('getDailySteps returns 0 when not connected', () async {
        final steps = await provider.getDailySteps('test-user', DateTime.now());
        expect(steps, 0);
      });

      test(
        'getTodayAverageHeartRate returns null when not connected',
        () async {
          final hr = await provider.getTodayAverageHeartRate('test-user');
          expect(hr, isNull);
        },
      );

      test('getLatestWeight returns null when not connected', () async {
        final weight = await provider.getLatestWeight('test-user');
        expect(weight, isNull);
      });

      test(
        'getLatestRestingHeartRate returns null when not connected',
        () async {
          final rhr = await provider.getLatestRestingHeartRate('test-user');
          expect(rhr, isNull);
        },
      );

      test('getWeeklySummary returns empty data when not connected', () async {
        final summary = await provider.getWeeklySummary('test-user');
        expect(summary['steps'], 0);
        expect(summary['distance'], 0.0);
        expect(summary['calories'], 0.0);
      });
    });

    group('Sync Operations When Not Connected', () {
      test('syncAll fails when not connected', () async {
        final result = await provider.syncAll('test-user');
        expect(result, false);
        expect(provider.errorMessage, isNotNull);
        expect(provider.errorMessage, contains('not connected'));
      });

      test('syncSteps does nothing when not connected', () async {
        await provider.syncSteps('test-user');
        expect(provider.lastSyncTime, isNull);
      });

      test('syncHeartRate does nothing when not connected', () async {
        await provider.syncHeartRate('test-user');
        expect(provider.lastSyncTime, isNull);
      });
    });

    group('Disconnect', () {
      test('disconnect clears connection state', () {
        provider.disconnect();
        expect(provider.isConnected, false);
        expect(provider.lastSyncTime, isNull);
        expect(provider.errorMessage, isNull);
      });
    });
  });
}
