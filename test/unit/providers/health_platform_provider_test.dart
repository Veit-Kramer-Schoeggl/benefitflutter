import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/providers/health_platform_provider.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

void main() {
  group('HealthPlatformProvider', () {
    late HealthPlatformProvider provider;

    setUp(() {
      provider = HealthPlatformProvider();
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

      test('getTodayAverageHeartRate returns null when not connected', () async {
        final hr = await provider.getTodayAverageHeartRate('test-user');
        expect(hr, isNull);
      });

      test('getLatestWeight returns null when not connected', () async {
        final weight = await provider.getLatestWeight('test-user');
        expect(weight, isNull);
      });

      test('getLatestRestingHeartRate returns null when not connected', () async {
        final rhr = await provider.getLatestRestingHeartRate('test-user');
        expect(rhr, isNull);
      });

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
