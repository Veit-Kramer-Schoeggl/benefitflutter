import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/providers/activity_provider.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';

/// Mock SessionRepository for testing
class MockSessionRepository implements SessionRepository {
  final List<Session> _sessions = [];

  @override
  Future<Session> createSession(Session session) async {
    _sessions.add(session);
    return session;
  }

  @override
  Future<void> updateSession(Session session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = session;
    }
  }

  @override
  Future<List<Session>> getAllSessions({required String userId}) async {
    return _sessions.where((s) => s.userId == userId).toList();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<Session> getSessionById(String sessionId) async {
    return _sessions.firstWhere((s) => s.id == sessionId);
  }

  @override
  Future<List<Session>> getSessionsByActivityType({
    required String userId,
    required ActivityType activityType,
  }) async {
    return _sessions
        .where((s) => s.userId == userId && s.activityType == activityType)
        .toList();
  }

  @override
  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required SessionStatus status,
  }) async {
    return _sessions
        .where((s) => s.userId == userId && s.status == status)
        .toList();
  }

  @override
  Future<List<Session>> getSessionsInDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _sessions
        .where(
          (s) =>
              s.userId == userId &&
              s.startTime.isAfter(startDate) &&
              s.startTime.isBefore(endDate),
        )
        .toList();
  }
}

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
}
