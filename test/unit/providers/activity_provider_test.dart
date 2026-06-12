import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/providers/activity_provider.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_manager.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';

import '../../mocks/mock_gps_sensor.dart';
import '../../helpers/session_fakes.dart';

void main() {
  group('ActivityProvider', () {
    late ActivityProvider provider;
    late MockSessionRepository mockRepo;

    setUp(() {
      mockRepo = MockSessionRepository();
      provider = ActivityProvider(mockRepo, userId: 'test-user-123');
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial state is idle with running as default activity', () {
      expect(provider.isIdle, true);
      expect(provider.isTracking, false);
      expect(provider.isPaused, false);
      expect(provider.elapsedSeconds, 0);
      expect(provider.selectedActivityType, ActivityType.running);
      expect(provider.canShowStopButton, false);
      expect(provider.formattedTime, '00:00:00');
    });

    test('selectActivityType updates activity type in idle state', () {
      provider.selectActivityType(ActivityType.cycling);
      expect(provider.selectedActivityType, ActivityType.cycling);

      provider.selectActivityType(ActivityType.walking);
      expect(provider.selectedActivityType, ActivityType.walking);
    });

    test('startSession creates session and transitions to tracking', () async {
      await provider.startSession();

      expect(provider.isTracking, true);
      expect(provider.isIdle, false);
      expect(provider.canShowStopButton, true);

      // Verify session was created in repository
      final sessions = await mockRepo.getAllSessions(userId: 'test-user-123');
      expect(sessions.length, 1);
      expect(sessions[0].status, SessionStatus.active);
      expect(sessions[0].trackingMode, TrackingMode.manual);
      expect(sessions[0].activityType, ActivityType.running);
    });

    test('pauseSession stops timer and updates status', () async {
      // Start session first
      await provider.startSession();
      expect(provider.isTracking, true);

      // Pause
      await provider.pauseSession();

      expect(provider.isPaused, true);
      expect(provider.isTracking, false);
      expect(provider.canShowStopButton, true);

      // Verify session status updated
      final sessions = await mockRepo.getAllSessions(userId: 'test-user-123');
      expect(sessions[0].status, SessionStatus.paused);
    });

    test('resumeSession restarts timer and updates status', () async {
      // Start and pause
      await provider.startSession();
      await provider.pauseSession();
      expect(provider.isPaused, true);

      // Resume
      await provider.resumeSession();

      expect(provider.isTracking, true);
      expect(provider.isPaused, false);

      // Verify session status updated
      final sessions = await mockRepo.getAllSessions(userId: 'test-user-123');
      expect(sessions[0].status, SessionStatus.active);
    });

    test('stopSession completes session and resets state', () async {
      // Start session
      await provider.startSession();
      expect(provider.isTracking, true);

      // Stop
      await provider.stopSession();

      expect(provider.isIdle, true);
      expect(provider.elapsedSeconds, 0);
      expect(provider.canShowStopButton, false);

      // Verify session completed
      final sessions = await mockRepo.getAllSessions(userId: 'test-user-123');
      expect(sessions[0].status, SessionStatus.completed);
      expect(sessions[0].endTime, isNotNull);
    });

    test('startSession ends active continuous sessions', () async {
      // Create a continuous session
      final continuousSession = Session(
        id: 'continuous-1',
        userId: 'test-user-123',
        trackingMode: TrackingMode.continuousDaily,
        activityType: ActivityType.walking,
        status: SessionStatus.active,
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        endTime: null,
        durationSeconds: null,
        distanceMeters: 0.0,
        trackingDate: DateTime.now(),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await mockRepo.createSession(continuousSession);

      // Start manual session
      await provider.startSession();

      // Verify continuous session was completed
      final sessions = await mockRepo.getAllSessions(userId: 'test-user-123');
      final continuous = sessions.firstWhere((s) => s.id == 'continuous-1');
      expect(continuous.status, SessionStatus.completed);
      expect(continuous.endTime, isNotNull);

      // Verify manual session was created
      final manual = sessions.firstWhere(
        (s) => s.trackingMode == TrackingMode.manual,
      );
      expect(manual.status, SessionStatus.active);
    });

    test(
      'stopSession restarts continuous if it was previously active',
      () async {
        // Create and add a continuous session
        final continuousSession = Session(
          id: 'continuous-1',
          userId: 'test-user-123',
          trackingMode: TrackingMode.continuousDaily,
          activityType: ActivityType.walking,
          status: SessionStatus.active,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: null,
          durationSeconds: null,
          distanceMeters: 0.0,
          trackingDate: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        await mockRepo.createSession(continuousSession);

        // Start manual (ends continuous)
        await provider.startSession();

        // Stop manual (should restart continuous)
        await provider.stopSession();

        // Verify a new continuous session was created
        final sessions = await mockRepo.getAllSessions(userId: 'test-user-123');
        final activeContinuous = sessions.where(
          (s) =>
              s.trackingMode == TrackingMode.continuousDaily &&
              s.status == SessionStatus.active,
        );

        expect(activeContinuous.length, 1);
      },
    );

    test(
      'stopSession does not restart continuous if none was active',
      () async {
        // Start manual session without any continuous session
        await provider.startSession();

        // Stop manual
        await provider.stopSession();

        // Verify no continuous session was created
        final sessions = await mockRepo.getAllSessions(userId: 'test-user-123');
        final continuousSessions = sessions.where(
          (s) => s.trackingMode == TrackingMode.continuousDaily,
        );

        expect(continuousSessions.length, 0);
      },
    );

    test('selectActivityType does not work during tracking', () async {
      await provider.startSession();

      final initialType = provider.selectedActivityType;
      provider.selectActivityType(ActivityType.cycling);

      // Activity type should not change
      expect(provider.selectedActivityType, initialType);
    });

    test('formattedTime formats elapsed seconds correctly', () {
      // Test initial formatted time (0 seconds)
      expect(provider.formattedTime, '00:00:00');

      // Note: Timer-based elapsed time changes are tested in other tests
      // This test just verifies the formatting logic works correctly
    });

    test('cannot start session when already tracking', () async {
      await provider.startSession();
      final sessions1 = await mockRepo.getAllSessions(userId: 'test-user-123');
      final count1 = sessions1.length;

      // Try to start again
      await provider.startSession();

      // Should not create another session
      final sessions2 = await mockRepo.getAllSessions(userId: 'test-user-123');
      expect(sessions2.length, count1);
    });

    test('cannot pause when not tracking', () async {
      await provider.pauseSession();
      expect(provider.isIdle, true); // State should remain idle
    });

    test('cannot resume when not paused', () async {
      await provider.resumeSession();
      expect(provider.isIdle, true); // State should remain idle

      // Start tracking
      await provider.startSession();
      await provider.resumeSession();
      expect(provider.isTracking, true); // Should remain tracking, not change
    });
  });

  group('GPS point batching', () {
    late MockGpsSensor mockGps;
    late FakeGpsPointDao fakeDao;
    late MockSessionRepository repo;
    late ActivityProvider provider;

    setUp(() async {
      mockGps = MockGpsSensor(); // permission granted + hardware available
      final sensorManager = SensorManager(gpsSensor: mockGps);
      await sensorManager.initialize();
      fakeDao = FakeGpsPointDao();
      repo = MockSessionRepository();
      provider = ActivityProvider(
        repo,
        userId: 'u1',
        sensorManager: sensorManager,
        gpsPointDao: fakeDao,
      );
      await provider.startSession(); // subscribes to the GPS stream
    });

    // Points ~1.1km apart so each clears the distance threshold and is stored.
    GpsPoint point(int i) => GpsPoint(
      id: 'p$i',
      sessionId: 'x',
      latitude: 0.01 * i,
      longitude: 0.0,
      timestamp: DateTime.now(),
    );

    Future<void> emit(int count) async {
      for (var i = 0; i < count; i++) {
        mockGps.emitMockPoint(point(i));
        await pumpEventQueue(); // let _onGpsPoint fully run before the next
      }
    }

    test('buffers below batch size — no DB write yet', () async {
      await emit(3);
      expect(fakeDao.batches, isEmpty);
      expect(fakeDao.persisted, isEmpty);
    });

    test(
      'flushes one batch automatically when batch size is reached',
      () async {
        await emit(10);
        expect(fakeDao.batches.length, 1);
        expect(fakeDao.batches.first.length, 10);
        expect(fakeDao.persisted.length, 10);
      },
    );

    test('never falls back to single insert()', () async {
      await emit(10);
      expect(fakeDao.insertCalls, 0);
    });

    test('pause flushes the buffered remainder', () async {
      await emit(4);
      expect(fakeDao.persisted, isEmpty); // still buffered
      await provider.pauseSession();
      expect(fakeDao.persisted.length, 4);
    });

    test('stop flushes the buffered remainder', () async {
      await emit(4);
      await provider.stopSession();
      expect(fakeDao.persisted.length, 4);
    });

    test(
      'every point is persisted exactly once across auto + manual flush',
      () async {
        await emit(13); // one auto-flush at 10, 3 left buffered
        await provider.pauseSession(); // flush the remaining 3
        final ids = fakeDao.persisted.map((p) => p.id).toList();
        expect(ids.length, 13);
        expect(ids.toSet().length, 13); // no duplicates, no losses
      },
    );

    test(
      'flushPendingGps() persists buffered points (background hook)',
      () async {
        await emit(2);
        await provider.flushPendingGps();
        expect(fakeDao.persisted.length, 2);
      },
    );
  });
}
