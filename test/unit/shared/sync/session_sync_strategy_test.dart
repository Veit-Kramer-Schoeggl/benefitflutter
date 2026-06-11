import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/session/data/session_sync_strategy.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

void main() {
  group('SessionSyncStrategy', () {
    late SessionSyncStrategy strategy;

    setUp(() {
      strategy = SessionSyncStrategy();
    });

    group('shouldSync', () {
      test('returns true for completed sessions', () async {
        // Arrange
        final session = Session(
          id: 'session-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.running,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
        );

        // Act
        final result = await strategy.shouldSync(session);

        // Assert
        expect(result, isTrue);
      });

      test('returns false for active sessions', () async {
        // Arrange
        final session = Session(
          id: 'session-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.running,
          status: SessionStatus.active,
          startTime: DateTime.now(),
        );

        // Act
        final result = await strategy.shouldSync(session);

        // Assert
        expect(result, isFalse);
      });

      test('returns false for paused sessions', () async {
        // Arrange
        final session = Session(
          id: 'session-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.paused,
          startTime: DateTime.now(),
        );

        // Act
        final result = await strategy.shouldSync(session);

        // Assert
        expect(result, isFalse);
      });

      test('returns false for cancelled sessions', () async {
        // Arrange
        final session = Session(
          id: 'session-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.cycling,
          status: SessionStatus.cancelled,
          startTime: DateTime.now(),
        );

        // Act
        final result = await strategy.shouldSync(session);

        // Assert
        expect(result, isFalse);
      });
    });

    group('resolveConflict', () {
      group('Case 1: Local session active or paused - ALWAYS keep local', () {
        test(
          'keeps local when local is active and remote is completed',
          () async {
            // Arrange
            final local = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.running,
              status: SessionStatus.active,
              startTime: DateTime.now().subtract(Duration(hours: 1)),
            );

            final remote = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.running,
              status: SessionStatus.completed,
              startTime: DateTime.now().subtract(Duration(hours: 1)),
              endTime: DateTime.now(),
            );

            // Act
            final result = await strategy.resolveConflict(local, remote);

            // Assert
            expect(result, local);
            expect(result.status, SessionStatus.active);
          },
        );

        test(
          'keeps local when local is paused and remote is completed',
          () async {
            // Arrange
            final local = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.cycling,
              status: SessionStatus.paused,
              startTime: DateTime.now().subtract(Duration(hours: 2)),
            );

            final remote = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.cycling,
              status: SessionStatus.completed,
              startTime: DateTime.now().subtract(Duration(hours: 2)),
              endTime: DateTime.now(),
            );

            // Act
            final result = await strategy.resolveConflict(local, remote);

            // Assert
            expect(result, local);
            expect(result.status, SessionStatus.paused);
          },
        );

        test(
          'keeps local when local is active and remote is cancelled',
          () async {
            // Arrange
            final local = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.walking,
              status: SessionStatus.active,
              startTime: DateTime.now(),
            );

            final remote = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.walking,
              status: SessionStatus.cancelled,
              startTime: DateTime.now(),
            );

            // Act
            final result = await strategy.resolveConflict(local, remote);

            // Assert
            expect(result, local);
            expect(result.status, SessionStatus.active);
          },
        );
      });

      group('Case 2: Both completed - keep later endTime', () {
        test('keeps local when local has later endTime', () async {
          // Arrange
          final now = DateTime.now();
          final local = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.running,
            status: SessionStatus.completed,
            startTime: now.subtract(Duration(hours: 1)),
            endTime: now, // Later
          );

          final remote = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.running,
            status: SessionStatus.completed,
            startTime: now.subtract(Duration(hours: 1)),
            endTime: now.subtract(Duration(minutes: 30)), // Earlier
          );

          // Act
          final result = await strategy.resolveConflict(local, remote);

          // Assert
          expect(result, local);
          expect(result.endTime, now);
        });

        test('keeps remote when remote has later endTime', () async {
          // Arrange
          final now = DateTime.now();
          final local = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.cycling,
            status: SessionStatus.completed,
            startTime: now.subtract(Duration(hours: 2)),
            endTime: now.subtract(Duration(hours: 1)), // Earlier
          );

          final remote = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.cycling,
            status: SessionStatus.completed,
            startTime: now.subtract(Duration(hours: 2)),
            endTime: now, // Later
          );

          // Act
          final result = await strategy.resolveConflict(local, remote);

          // Assert
          expect(result, remote);
          expect(result.endTime, now);
        });

        test('handles same endTime by defaulting to remote', () async {
          // Arrange
          final now = DateTime.now();
          final local = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.walking,
            status: SessionStatus.completed,
            startTime: now.subtract(Duration(hours: 1)),
            endTime: now,
          );

          final remote = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.walking,
            status: SessionStatus.completed,
            startTime: now.subtract(Duration(hours: 1)),
            endTime: now,
          );

          // Act
          final result = await strategy.resolveConflict(local, remote);

          // Assert
          expect(result, remote);
        });
      });

      group('Case 3: Remote completed, local not - take remote', () {
        test(
          'takes remote when remote is completed and local is active',
          () async {
            // Arrange
            final local = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.running,
              status: SessionStatus.active,
              startTime: DateTime.now(),
            );

            final remote = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.running,
              status: SessionStatus.completed,
              startTime: DateTime.now(),
              endTime: DateTime.now().add(Duration(minutes: 30)),
            );

            // Act
            final result = await strategy.resolveConflict(local, remote);

            // Assert
            // This case is overridden by Case 1 (local active takes priority)
            expect(result, local);
          },
        );

        test(
          'takes remote when remote is completed and local is cancelled',
          () async {
            // Arrange
            final local = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.cycling,
              status: SessionStatus.cancelled,
              startTime: DateTime.now(),
            );

            final remote = Session(
              id: 'session-1',
              userId: 'user-1',
              trackingMode: TrackingMode.manual,
              activityType: ActivityType.cycling,
              status: SessionStatus.completed,
              startTime: DateTime.now(),
              endTime: DateTime.now().add(Duration(minutes: 30)),
            );

            // Act
            final result = await strategy.resolveConflict(local, remote);

            // Assert
            expect(result, remote);
            expect(result.status, SessionStatus.completed);
          },
        );
      });

      group('Default: Remote wins', () {
        test('takes remote when both are cancelled', () async {
          // Arrange
          final local = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.walking,
            status: SessionStatus.cancelled,
            startTime: DateTime.now(),
          );

          final remote = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.walking,
            status: SessionStatus.cancelled,
            startTime: DateTime.now(),
          );

          // Act
          final result = await strategy.resolveConflict(local, remote);

          // Assert
          expect(result, remote);
        });

        test('takes remote when both completed but endTime is null', () async {
          // Arrange
          final local = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.running,
            status: SessionStatus.completed,
            startTime: DateTime.now(),
            endTime: null, // Missing endTime
          );

          final remote = Session(
            id: 'session-1',
            userId: 'user-1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.running,
            status: SessionStatus.completed,
            startTime: DateTime.now(),
            endTime: null, // Missing endTime
          );

          // Act
          final result = await strategy.resolveConflict(local, remote);

          // Assert
          expect(result, remote);
        });
      });
    });

    group('Sync Configuration', () {
      test('requiresSync returns true', () {
        expect(strategy.requiresSync, isTrue);
      });

      test('maxRetries is 5 (high priority)', () {
        expect(strategy.maxRetries, 5);
      });

      test('retryDelaySeconds is 10 (longer than default)', () {
        expect(strategy.retryDelaySeconds, 10);
      });
    });
  });
}
