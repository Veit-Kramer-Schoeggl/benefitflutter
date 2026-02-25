import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/features/shared/sync/base_sync_strategy.dart';

void main() {
  group('Enum Conversions', () {
    group('ActivityType', () {
      test('toJson returns correct string for all values', () {
        expect(ActivityType.running.toJson(), 'running');
        expect(ActivityType.walking.toJson(), 'walking');
        expect(ActivityType.cycling.toJson(), 'cycling');
        expect(ActivityType.swimming.toJson(), 'swimming');
        expect(ActivityType.strengthTraining.toJson(), 'strengthTraining');
        expect(ActivityType.yoga.toJson(), 'yoga');
        expect(ActivityType.hiking.toJson(), 'hiking');
        expect(ActivityType.trailRunning.toJson(), 'trailRunning');
        expect(ActivityType.dancing.toJson(), 'dancing');
        expect(ActivityType.martialArts.toJson(), 'martialArts');
        expect(ActivityType.teamSports.toJson(), 'teamSports');
        expect(ActivityType.other.toJson(), 'other');
      });

      test('fromJson parses valid strings correctly', () {
        expect(ActivityType.fromJson('running'), ActivityType.running);
        expect(ActivityType.fromJson('walking'), ActivityType.walking);
        expect(ActivityType.fromJson('cycling'), ActivityType.cycling);
        expect(ActivityType.fromJson('swimming'), ActivityType.swimming);
        expect(ActivityType.fromJson('strengthTraining'), ActivityType.strengthTraining);
        expect(ActivityType.fromJson('yoga'), ActivityType.yoga);
        expect(ActivityType.fromJson('hiking'), ActivityType.hiking);
        expect(ActivityType.fromJson('trailRunning'), ActivityType.trailRunning);
        expect(ActivityType.fromJson('dancing'), ActivityType.dancing);
        expect(ActivityType.fromJson('martialArts'), ActivityType.martialArts);
        expect(ActivityType.fromJson('teamSports'), ActivityType.teamSports);
        expect(ActivityType.fromJson('other'), ActivityType.other);
      });

      test('fromJson handles unknown value with default', () {
        // Should default to 'other'
        expect(ActivityType.fromJson('unknown'), ActivityType.other);
        expect(ActivityType.fromJson('invalid'), ActivityType.other);
        expect(ActivityType.fromJson(''), ActivityType.other);
      });

      test('toJson and fromJson are reversible', () {
        for (final type in ActivityType.values) {
          final json = type.toJson();
          final parsed = ActivityType.fromJson(json);
          expect(parsed, type);
        }
      });

      test('displayName returns human-readable strings', () {
        expect(ActivityType.running.displayName, 'Running');
        expect(ActivityType.walking.displayName, 'Walking');
        expect(ActivityType.cycling.displayName, 'Cycling');
        expect(ActivityType.swimming.displayName, 'Swimming');
        expect(ActivityType.strengthTraining.displayName, 'Strength Training');
        expect(ActivityType.yoga.displayName, 'Yoga');
        expect(ActivityType.hiking.displayName, 'Hiking');
        expect(ActivityType.trailRunning.displayName, 'Trail Running');
        expect(ActivityType.dancing.displayName, 'Dancing');
        expect(ActivityType.martialArts.displayName, 'Martial Arts');
        expect(ActivityType.teamSports.displayName, 'Team Sports');
        expect(ActivityType.other.displayName, 'Other');
      });
    });

    group('TrackingMode', () {
      test('toJson returns correct string for all values', () {
        expect(TrackingMode.manual.toJson(), 'manual');
        expect(TrackingMode.continuousDaily.toJson(), 'continuousDaily');
      });

      test('fromJson parses valid strings correctly', () {
        expect(TrackingMode.fromJson('manual'), TrackingMode.manual);
        expect(TrackingMode.fromJson('continuousDaily'), TrackingMode.continuousDaily);
      });

      test('fromJson handles unknown value with default', () {
        // Should default to 'manual'
        expect(TrackingMode.fromJson('unknown'), TrackingMode.manual);
        expect(TrackingMode.fromJson('invalid'), TrackingMode.manual);
        expect(TrackingMode.fromJson(''), TrackingMode.manual);
      });

      test('toJson and fromJson are reversible', () {
        for (final mode in TrackingMode.values) {
          final json = mode.toJson();
          final parsed = TrackingMode.fromJson(json);
          expect(parsed, mode);
        }
      });

      test('displayName returns human-readable strings', () {
        expect(TrackingMode.manual.displayName, 'Manual Session');
        expect(TrackingMode.continuousDaily.displayName, 'Daily Movement');
      });
    });

    group('SessionStatus', () {
      test('toJson returns correct string for all values', () {
        expect(SessionStatus.active.toJson(), 'active');
        expect(SessionStatus.paused.toJson(), 'paused');
        expect(SessionStatus.completed.toJson(), 'completed');
        expect(SessionStatus.cancelled.toJson(), 'cancelled');
      });

      test('fromJson parses valid strings correctly', () {
        expect(SessionStatus.fromJson('active'), SessionStatus.active);
        expect(SessionStatus.fromJson('paused'), SessionStatus.paused);
        expect(SessionStatus.fromJson('completed'), SessionStatus.completed);
        expect(SessionStatus.fromJson('cancelled'), SessionStatus.cancelled);
      });

      test('fromJson handles unknown value with default', () {
        // Should default to 'completed'
        expect(SessionStatus.fromJson('unknown'), SessionStatus.completed);
        expect(SessionStatus.fromJson('invalid'), SessionStatus.completed);
        expect(SessionStatus.fromJson(''), SessionStatus.completed);
      });

      test('toJson and fromJson are reversible', () {
        for (final status in SessionStatus.values) {
          final json = status.toJson();
          final parsed = SessionStatus.fromJson(json);
          expect(parsed, status);
        }
      });

      test('displayName returns human-readable strings', () {
        expect(SessionStatus.active.displayName, 'Active');
        expect(SessionStatus.paused.displayName, 'Paused');
        expect(SessionStatus.completed.displayName, 'Completed');
        expect(SessionStatus.cancelled.displayName, 'Cancelled');
      });

      test('isFinal returns true for completed and cancelled', () {
        expect(SessionStatus.completed.isFinal, isTrue);
        expect(SessionStatus.cancelled.isFinal, isTrue);
        expect(SessionStatus.active.isFinal, isFalse);
        expect(SessionStatus.paused.isFinal, isFalse);
      });

      test('isOngoing returns true for active and paused', () {
        expect(SessionStatus.active.isOngoing, isTrue);
        expect(SessionStatus.paused.isOngoing, isTrue);
        expect(SessionStatus.completed.isOngoing, isFalse);
        expect(SessionStatus.cancelled.isOngoing, isFalse);
      });

      test('isFinal and isOngoing are mutually exclusive', () {
        for (final status in SessionStatus.values) {
          // Either final OR ongoing, never both, never neither
          expect(status.isFinal != status.isOngoing, isTrue);
        }
      });
    });

    group('SyncOperation', () {
      test('toJson returns correct string for all values', () {
        expect(SyncOperation.create.toJson(), 'create');
        expect(SyncOperation.update.toJson(), 'update');
        expect(SyncOperation.delete.toJson(), 'delete');
      });

      test('fromJson parses valid strings correctly', () {
        expect(SyncOperation.fromJson('create'), SyncOperation.create);
        expect(SyncOperation.fromJson('update'), SyncOperation.update);
        expect(SyncOperation.fromJson('delete'), SyncOperation.delete);
      });

      test('toJson and fromJson are reversible', () {
        for (final operation in SyncOperation.values) {
          final json = operation.toJson();
          final parsed = SyncOperation.fromJson(json);
          expect(parsed, operation);
        }
      });

      test('fromJson throws on unknown value', () {
        // firstWhere without orElse throws StateError
        expect(
          () => SyncOperation.fromJson('unknown'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('SyncStatus', () {
      test('toJson returns correct string for all values', () {
        expect(SyncStatus.success.toJson(), 'success');
        expect(SyncStatus.failure.toJson(), 'failure');
        expect(SyncStatus.pending.toJson(), 'pending');
        expect(SyncStatus.conflict.toJson(), 'conflict');
      });

      test('fromJson parses valid strings correctly', () {
        expect(SyncStatus.fromJson('success'), SyncStatus.success);
        expect(SyncStatus.fromJson('failure'), SyncStatus.failure);
        expect(SyncStatus.fromJson('pending'), SyncStatus.pending);
        expect(SyncStatus.fromJson('conflict'), SyncStatus.conflict);
      });

      test('toJson and fromJson are reversible', () {
        for (final status in SyncStatus.values) {
          final json = status.toJson();
          final parsed = SyncStatus.fromJson(json);
          expect(parsed, status);
        }
      });

      test('fromJson throws on unknown value', () {
        // firstWhere without orElse throws StateError
        expect(
          () => SyncStatus.fromJson('unknown'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Edge Cases', () {
      test('handles case sensitivity correctly', () {
        // Enum names are case-sensitive
        expect(ActivityType.fromJson('Running'), ActivityType.other); // Capital R = unknown
        expect(TrackingMode.fromJson('Manual'), TrackingMode.manual); // Capital M = unknown
        expect(SessionStatus.fromJson('ACTIVE'), SessionStatus.completed); // All caps = unknown
      });

      test('handles whitespace in enum values', () {
        expect(ActivityType.fromJson(' running '), ActivityType.other); // Whitespace = unknown
        expect(TrackingMode.fromJson('manual '), TrackingMode.manual); // Trailing space = unknown
      });

      test('ActivityType has expected number of values', () {
        // If new activity types are added, this test will catch it
        expect(ActivityType.values.length, 12);
      });

      test('TrackingMode has expected number of values', () {
        expect(TrackingMode.values.length, 2);
      });

      test('SessionStatus has expected number of values', () {
        expect(SessionStatus.values.length, 4);
      });

      test('SyncOperation has expected number of values', () {
        expect(SyncOperation.values.length, 3);
      });

      test('SyncStatus has expected number of values', () {
        expect(SyncStatus.values.length, 4);
      });
    });
  });
}