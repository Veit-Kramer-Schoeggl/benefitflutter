import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/session/domain/activity_segment.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';

void main() {
  group('DetectionSource', () {
    test('fromJson parses valid values', () {
      expect(
        DetectionSource.fromJson('manual'),
        equals(DetectionSource.manual),
      );
      expect(DetectionSource.fromJson('auto'), equals(DetectionSource.auto));
      expect(
        DetectionSource.fromJson('corrected'),
        equals(DetectionSource.corrected),
      );
    });

    test('fromJson is case insensitive', () {
      expect(
        DetectionSource.fromJson('MANUAL'),
        equals(DetectionSource.manual),
      );
      expect(DetectionSource.fromJson('Auto'), equals(DetectionSource.auto));
    });

    test('fromJson returns manual for unknown values', () {
      expect(
        DetectionSource.fromJson('unknown'),
        equals(DetectionSource.manual),
      );
      expect(DetectionSource.fromJson(null), equals(DetectionSource.manual));
    });

    test('toJson returns string name', () {
      expect(DetectionSource.manual.toJson(), equals('manual'));
      expect(DetectionSource.auto.toJson(), equals('auto'));
      expect(DetectionSource.corrected.toJson(), equals('corrected'));
    });
  });

  group('ActivitySegment', () {
    group('constructor', () {
      test('creates segment with required fields', () {
        final startTime = DateTime.now();
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-123',
          activityType: ActivityType.walking,
          startTime: startTime,
          detectionSource: DetectionSource.manual,
        );

        expect(segment.id, equals('seg-1'));
        expect(segment.sessionId, equals('session-123'));
        expect(segment.activityType, equals(ActivityType.walking));
        expect(segment.startTime, equals(startTime));
        expect(segment.detectionSource, equals(DetectionSource.manual));
      });

      test('optional fields default to null', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-123',
          activityType: ActivityType.running,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.auto,
        );

        expect(segment.endTime, isNull);
        expect(segment.distanceMeters, isNull);
        expect(segment.confidence, isNull);
      });
    });

    group('fromJson', () {
      test('parses JSON with all fields', () {
        final json = {
          'id': 'seg-1',
          'session_id': 'session-1',
          'activity_type': 'running',
          'start_time': 1700000000000,
          'end_time': 1700001800000,
          'distance_meters': 5000.5,
          'detection_source': 'auto',
          'confidence': 0.85,
          'created_at': 1700000000000,
          'updated_at': 1700001800000,
        };

        final segment = ActivitySegment.fromJson(json);

        expect(segment.id, equals('seg-1'));
        expect(segment.sessionId, equals('session-1'));
        expect(segment.activityType, equals(ActivityType.running));
        expect(segment.distanceMeters, equals(5000.5));
        expect(segment.detectionSource, equals(DetectionSource.auto));
        expect(segment.confidence, equals(0.85));
      });

      test('parses JSON with null optional fields', () {
        final json = {
          'id': 'seg-2',
          'session_id': 'session-2',
          'activity_type': 'walking',
          'start_time': 1700000000000,
          'detection_source': 'manual',
          'created_at': 1700000000000,
          'updated_at': 1700000000000,
        };

        final segment = ActivitySegment.fromJson(json);

        expect(segment.endTime, isNull);
        expect(segment.distanceMeters, isNull);
        expect(segment.confidence, isNull);
      });
    });

    group('toJson', () {
      test('converts to JSON with all fields', () {
        final startTime = DateTime.fromMillisecondsSinceEpoch(1700000000000);
        final endTime = DateTime.fromMillisecondsSinceEpoch(1700001800000);
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.cycling,
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 10000.0,
          detectionSource: DetectionSource.corrected,
          confidence: 0.7,
          createdAt: startTime,
          updatedAt: endTime,
        );

        final json = segment.toJson();

        expect(json['id'], equals('seg-1'));
        expect(json['session_id'], equals('session-1'));
        expect(json['activity_type'], equals('cycling'));
        expect(json['start_time'], equals(1700000000000));
        expect(json['end_time'], equals(1700001800000));
        expect(json['distance_meters'], equals(10000.0));
        expect(json['detection_source'], equals('corrected'));
        expect(json['confidence'], equals(0.7));
      });

      test('roundtrip conversion', () {
        final original = ActivitySegment(
          id: 'seg-rt',
          sessionId: 'session-rt',
          activityType: ActivityType.running,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
          distanceMeters: 8500.0,
          detectionSource: DetectionSource.auto,
          confidence: 0.92,
        );

        final json = original.toJson();
        final restored = ActivitySegment.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.sessionId, equals(original.sessionId));
        expect(restored.activityType, equals(original.activityType));
        expect(restored.distanceMeters, equals(original.distanceMeters));
        expect(restored.detectionSource, equals(original.detectionSource));
        expect(restored.confidence, equals(original.confidence));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.auto,
        );

        final copy = original.copyWith(
          activityType: ActivityType.running,
          distanceMeters: 5000.0,
        );

        expect(copy.id, equals(original.id));
        expect(copy.activityType, equals(ActivityType.running));
        expect(copy.distanceMeters, equals(5000.0));
        expect(copy.startTime, equals(original.startTime));
      });
    });

    group('duration getter', () {
      test('returns null when endTime is null', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment.duration, isNull);
        expect(segment.durationSeconds, isNull);
      });

      test('returns correct duration when endTime is set', () {
        final startTime = DateTime.now().subtract(const Duration(minutes: 30));
        final endTime = DateTime.now();
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.running,
          startTime: startTime,
          endTime: endTime,
          detectionSource: DetectionSource.manual,
        );

        final duration = segment.duration!;
        expect(duration.inMinutes, greaterThanOrEqualTo(29));
        expect(duration.inMinutes, lessThanOrEqualTo(31));
      });
    });

    group('isOngoing getter', () {
      test('returns true when endTime is null', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment.isOngoing, isTrue);
      });

      test('returns false when endTime is set', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment.isOngoing, isFalse);
      });
    });

    group('detection source helpers', () {
      test('isManual returns true for manual source', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment.isManual, isTrue);
        expect(segment.isAutoDetected, isFalse);
        expect(segment.isCorrected, isFalse);
      });

      test('isAutoDetected returns true for auto source', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.running,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.auto,
        );

        expect(segment.isManual, isFalse);
        expect(segment.isAutoDetected, isTrue);
        expect(segment.isCorrected, isFalse);
      });

      test('isCorrected returns true for corrected source', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.cycling,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.corrected,
        );

        expect(segment.isManual, isFalse);
        expect(segment.isAutoDetected, isFalse);
        expect(segment.isCorrected, isTrue);
      });
    });

    group('formattedDuration getter', () {
      test('returns ongoing when no endTime', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment.formattedDuration, equals('ongoing'));
      });

      test('formats minutes only for short durations', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now().subtract(const Duration(minutes: 45)),
          endTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment.formattedDuration, matches(RegExp(r'\d+m')));
      });

      test('formats hours and minutes for long durations', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.running,
          startTime: DateTime.now().subtract(
            const Duration(hours: 2, minutes: 15),
          ),
          endTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment.formattedDuration, matches(RegExp(r'\d+h \d+m')));
      });
    });

    group('formattedDistance getter', () {
      test('returns -- when distance is null', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment.formattedDistance, equals('--'));
      });

      test('formats distance in km', () {
        final segment = ActivitySegment(
          id: 'seg-1',
          sessionId: 'session-1',
          activityType: ActivityType.running,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
          distanceMeters: 5500.0,
        );

        expect(segment.formattedDistance, equals('5.50 km'));
      });
    });

    group('equality', () {
      test('segments with same id are equal', () {
        final segment1 = ActivitySegment(
          id: 'same-id',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        final segment2 = ActivitySegment(
          id: 'same-id',
          sessionId: 'session-2',
          activityType: ActivityType.running,
          startTime: DateTime.now().add(const Duration(hours: 1)),
          detectionSource: DetectionSource.auto,
        );

        expect(segment1, equals(segment2));
        expect(segment1.hashCode, equals(segment2.hashCode));
      });

      test('segments with different ids are not equal', () {
        final segment1 = ActivitySegment(
          id: 'id-1',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        final segment2 = ActivitySegment(
          id: 'id-2',
          sessionId: 'session-1',
          activityType: ActivityType.walking,
          startTime: DateTime.now(),
          detectionSource: DetectionSource.manual,
        );

        expect(segment1, isNot(equals(segment2)));
      });
    });
  });
}
