import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/session/domain/continuous_tracking_state.dart';

void main() {
  group('ContinuousTrackingState', () {
    group('constructor', () {
      test('creates state with required fields', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-123',
          isActive: true,
          isPausedForManual: false,
        );

        expect(state.id, equals('state-1'));
        expect(state.userId, equals('user-123'));
        expect(state.isActive, isTrue);
        expect(state.isPausedForManual, isFalse);
      });

      test('optional fields default to null', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-123',
          isActive: false,
          isPausedForManual: false,
        );

        expect(state.currentSessionId, isNull);
        expect(state.startedAt, isNull);
        expect(state.lastDataReceived, isNull);
        expect(state.currentDetectedActivity, isNull);
        expect(state.detectionConfidence, isNull);
      });
    });

    group('defaultFor', () {
      test('creates inactive state for user', () {
        final state = ContinuousTrackingState.defaultFor('user-456');

        expect(state.id, equals('cts-user-456'));
        expect(state.userId, equals('user-456'));
        expect(state.isActive, isFalse);
        expect(state.isPausedForManual, isFalse);
        expect(state.currentSessionId, isNull);
      });
    });

    group('fromJson', () {
      test('parses JSON with integer booleans', () {
        final json = {
          'id': 'state-1',
          'user_id': 'user-1',
          'is_active': 1,
          'is_paused_for_manual': 0,
          'current_session_id': 'session-123',
          'started_at': 1700000000000,
          'last_data_received': 1700001000000,
          'current_detected_activity': 'walking',
          'detection_confidence': 0.85,
          'updated_at': 1700001000000,
        };

        final state = ContinuousTrackingState.fromJson(json);

        expect(state.id, equals('state-1'));
        expect(state.isActive, isTrue);
        expect(state.isPausedForManual, isFalse);
        expect(state.currentSessionId, equals('session-123'));
        expect(state.startedAt, isNotNull);
        expect(state.currentDetectedActivity, equals('walking'));
        expect(state.detectionConfidence, equals(0.85));
      });

      test('parses JSON with true/false booleans', () {
        final json = {
          'id': 'state-2',
          'user_id': 'user-2',
          'is_active': true,
          'is_paused_for_manual': true,
          'updated_at': 1700000000000,
        };

        final state = ContinuousTrackingState.fromJson(json);

        expect(state.isActive, isTrue);
        expect(state.isPausedForManual, isTrue);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'state-3',
          'user_id': 'user-3',
          'is_active': 0,
          'is_paused_for_manual': 0,
          'updated_at': 1700000000000,
        };

        final state = ContinuousTrackingState.fromJson(json);

        expect(state.currentSessionId, isNull);
        expect(state.startedAt, isNull);
        expect(state.lastDataReceived, isNull);
      });
    });

    group('toJson', () {
      test('converts to JSON with integer booleans', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: false,
          currentSessionId: 'session-123',
          startedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastDataReceived: DateTime.fromMillisecondsSinceEpoch(1700001000000),
          currentDetectedActivity: 'running',
          detectionConfidence: 0.9,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1700001000000),
        );

        final json = state.toJson();

        expect(json['is_active'], equals(1));
        expect(json['is_paused_for_manual'], equals(0));
        expect(json['current_session_id'], equals('session-123'));
        expect(json['started_at'], equals(1700000000000));
        expect(json['current_detected_activity'], equals('running'));
        expect(json['detection_confidence'], equals(0.9));
      });

      test('roundtrip conversion', () {
        final original = ContinuousTrackingState(
          id: 'state-rt',
          userId: 'user-rt',
          isActive: true,
          isPausedForManual: true,
          currentSessionId: 'session-rt',
          currentDetectedActivity: 'cycling',
          detectionConfidence: 0.75,
        );

        final json = original.toJson();
        final restored = ContinuousTrackingState.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.isActive, equals(original.isActive));
        expect(restored.isPausedForManual, equals(original.isPausedForManual));
        expect(restored.currentSessionId, equals(original.currentSessionId));
        expect(
          restored.currentDetectedActivity,
          equals(original.currentDetectedActivity),
        );
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = ContinuousTrackingState.defaultFor('user-1');
        final copy = original.copyWith(
          isActive: true,
          currentSessionId: 'session-new',
        );

        expect(copy.id, equals(original.id));
        expect(copy.isActive, isTrue);
        expect(copy.currentSessionId, equals('session-new'));
        expect(copy.isPausedForManual, equals(original.isPausedForManual));
      });

      test('updates updatedAt timestamp', () {
        final original = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: false,
          isPausedForManual: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        );

        final copy = original.copyWith(isActive: true);

        expect(copy.updatedAt.isAfter(original.updatedAt), isTrue);
      });
    });

    group('isTracking getter', () {
      test('returns true when active and not paused', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: false,
        );

        expect(state.isTracking, isTrue);
      });

      test('returns false when not active', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: false,
          isPausedForManual: false,
        );

        expect(state.isTracking, isFalse);
      });

      test('returns false when paused for manual', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: true,
        );

        expect(state.isTracking, isFalse);
      });
    });

    group('activeTime getter', () {
      test('returns null when startedAt is null', () {
        final state = ContinuousTrackingState.defaultFor('user-1');

        expect(state.activeTime, isNull);
      });

      test('returns duration when startedAt is set', () {
        final startTime = DateTime.now().subtract(const Duration(hours: 2));
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: false,
          startedAt: startTime,
        );

        final activeTime = state.activeTime!;
        expect(activeTime.inHours, greaterThanOrEqualTo(2));
      });
    });

    group('timeSinceLastData getter', () {
      test('returns null when lastDataReceived is null', () {
        final state = ContinuousTrackingState.defaultFor('user-1');

        expect(state.timeSinceLastData, isNull);
      });

      test('returns duration when lastDataReceived is set', () {
        final lastData = DateTime.now().subtract(const Duration(minutes: 5));
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: false,
          lastDataReceived: lastData,
        );

        final timeSince = state.timeSinceLastData!;
        expect(timeSince.inMinutes, greaterThanOrEqualTo(5));
      });
    });

    group('hasRecentData getter', () {
      test('returns false when no data received', () {
        final state = ContinuousTrackingState.defaultFor('user-1');

        expect(state.hasRecentData, isFalse);
      });

      test('returns true for data within 10 minutes', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: false,
          lastDataReceived: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        expect(state.hasRecentData, isTrue);
      });

      test('returns false for data older than 10 minutes', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: false,
          lastDataReceived: DateTime.now().subtract(
            const Duration(minutes: 15),
          ),
        );

        expect(state.hasRecentData, isFalse);
      });
    });

    group('formattedActiveTime getter', () {
      test('returns -- when not active', () {
        final state = ContinuousTrackingState.defaultFor('user-1');

        expect(state.formattedActiveTime, equals('--'));
      });

      test('formats time with hours and minutes', () {
        final state = ContinuousTrackingState(
          id: 'state-1',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: false,
          startedAt: DateTime.now().subtract(
            const Duration(hours: 2, minutes: 30),
          ),
        );

        expect(state.formattedActiveTime, matches(RegExp(r'\d+h \d+m')));
      });
    });

    group('equality', () {
      test('states with same id are equal', () {
        final state1 = ContinuousTrackingState(
          id: 'same-id',
          userId: 'user-1',
          isActive: true,
          isPausedForManual: false,
        );

        final state2 = ContinuousTrackingState(
          id: 'same-id',
          userId: 'user-2',
          isActive: false,
          isPausedForManual: true,
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('states with different ids are not equal', () {
        final state1 = ContinuousTrackingState.defaultFor('user-1');
        final state2 = ContinuousTrackingState.defaultFor('user-2');

        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
