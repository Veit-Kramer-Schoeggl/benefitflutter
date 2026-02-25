import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/wearable_integration/domain/health_data_type.dart';

void main() {
  group('HealthDataType', () {
    group('toJson / fromJson', () {
      test('toJson returns enum name', () {
        expect(HealthDataType.steps.toJson(), 'steps');
        expect(HealthDataType.heartRate.toJson(), 'heartRate');
        expect(HealthDataType.weight.toJson(), 'weight');
      });

      test('fromJson creates correct enum value', () {
        expect(HealthDataType.fromJson('steps'), HealthDataType.steps);
        expect(HealthDataType.fromJson('heartRate'), HealthDataType.heartRate);
        expect(HealthDataType.fromJson('weight'), HealthDataType.weight);
      });

      test('fromJson throws on unknown value', () {
        expect(
          () => HealthDataType.fromJson('unknown'),
          throwsArgumentError,
        );
      });

      test('round-trip conversion works', () {
        for (final type in HealthDataType.values) {
          final json = type.toJson();
          final restored = HealthDataType.fromJson(json);
          expect(restored, type);
        }
      });
    });

    group('displayName', () {
      test('returns human-readable names', () {
        expect(HealthDataType.steps.displayName, 'Steps');
        expect(HealthDataType.heartRate.displayName, 'Heart Rate');
        expect(HealthDataType.heartRateVariability.displayName, 'Heart Rate Variability');
        expect(HealthDataType.distance.displayName, 'Distance');
        expect(HealthDataType.calories.displayName, 'Calories');
        expect(HealthDataType.sleep.displayName, 'Sleep');
        expect(HealthDataType.weight.displayName, 'Weight');
        expect(HealthDataType.bloodOxygen.displayName, 'Blood Oxygen');
        expect(HealthDataType.vo2Max.displayName, 'VO2 Max');
        expect(HealthDataType.restingHeartRate.displayName, 'Resting Heart Rate');
        expect(HealthDataType.activeEnergyBurned.displayName, 'Active Energy');
        expect(HealthDataType.workout.displayName, 'Workout');
      });
    });
  });

  group('HealthDataPoint', () {
    final testTime = DateTime(2025, 12, 9, 10, 0);
    final testEndTime = DateTime(2025, 12, 9, 11, 0);

    group('Constructor', () {
      test('generates ID if not provided', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.id, isNotEmpty);
        expect(point.id.length, 36); // UUID length
      });

      test('uses provided ID', () {
        final point = HealthDataPoint(
          id: 'custom-id',
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.id, 'custom-id');
      });

      test('sets syncedAt to now if not provided', () {
        final before = DateTime.now();
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );
        final after = DateTime.now();

        expect(point.syncedAt.isAfter(before) || point.syncedAt.isAtSameMomentAs(before), true);
        expect(point.syncedAt.isBefore(after) || point.syncedAt.isAtSameMomentAs(after), true);
      });

      test('sets createdAt to now if not provided', () {
        final before = DateTime.now();
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );
        final after = DateTime.now();

        expect(point.createdAt.isAfter(before) || point.createdAt.isAtSameMomentAs(before), true);
        expect(point.createdAt.isBefore(after) || point.createdAt.isAtSameMomentAs(after), true);
      });
    });

    group('copyWith', () {
      late HealthDataPoint original;

      setUp(() {
        original = HealthDataPoint(
          id: 'test-id',
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
          sourceApp: 'Google Fit',
          syncedAt: testTime,
          createdAt: testTime,
        );
      });

      test('creates copy with same values when no params provided', () {
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.userId, original.userId);
        expect(copy.dataType, original.dataType);
        expect(copy.value, original.value);
      });

      test('updates only specified fields', () {
        final copy = original.copyWith(
          value: '6000',
          sourceApp: 'Garmin Connect',
        );

        expect(copy.id, original.id);
        expect(copy.userId, original.userId);
        expect(copy.value, '6000'); // Changed
        expect(copy.sourceApp, 'Garmin Connect'); // Changed
      });
    });

    group('toJson / fromJson', () {
      test('converts to JSON correctly', () {
        final point = HealthDataPoint(
          id: 'test-id',
          userId: 'user1',
          dataType: HealthDataType.heartRate,
          value: '72',
          startTime: testTime,
          endTime: testEndTime,
          sourceApp: 'Google Fit',
          metadata: {'quality': 'high'},
          syncedAt: testTime,
          createdAt: testTime,
        );

        final json = point.toJson();

        expect(json['id'], 'test-id');
        expect(json['user_id'], 'user1');
        expect(json['data_type'], 'heartRate');
        expect(json['value'], '72');
        expect(json['start_time'], testTime.millisecondsSinceEpoch);
        expect(json['end_time'], testEndTime.millisecondsSinceEpoch);
        expect(json['source_app'], 'Google Fit');
        expect(json['metadata'], isNotNull);
        expect(json['synced_at'], testTime.millisecondsSinceEpoch);
        expect(json['created_at'], testTime.millisecondsSinceEpoch);
      });

      test('converts from JSON correctly', () {
        final json = {
          'id': 'test-id',
          'user_id': 'user1',
          'data_type': 'heartRate',
          'value': '72',
          'start_time': testTime.millisecondsSinceEpoch,
          'end_time': testEndTime.millisecondsSinceEpoch,
          'source_app': 'Google Fit',
          'metadata': '{"quality":"high"}',
          'synced_at': testTime.millisecondsSinceEpoch,
          'created_at': testTime.millisecondsSinceEpoch,
        };

        final point = HealthDataPoint.fromJson(json);

        expect(point.id, 'test-id');
        expect(point.userId, 'user1');
        expect(point.dataType, HealthDataType.heartRate);
        expect(point.value, '72');
        expect(point.startTime, testTime);
        expect(point.endTime, testEndTime);
        expect(point.sourceApp, 'Google Fit');
        expect(point.metadata, {'quality': 'high'});
        expect(point.syncedAt, testTime);
        expect(point.createdAt, testTime);
      });

      test('round-trip conversion works', () {
        final original = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
          sourceApp: 'Google Fit',
          metadata: {'test': 'data'},
        );

        final json = original.toJson();
        final restored = HealthDataPoint.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.userId, original.userId);
        expect(restored.dataType, original.dataType);
        expect(restored.value, original.value);
        expect(restored.sourceApp, original.sourceApp);
      });

      test('handles null metadata', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        final json = point.toJson();
        expect(json['metadata'], isNull);

        final restored = HealthDataPoint.fromJson(json);
        expect(restored.metadata, isNull);
      });
    });

    group('Value Getters', () {
      test('numericValue parses valid numbers', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.heartRate,
          value: '72.5',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.numericValue, 72.5);
      });

      test('numericValue returns null for invalid numbers', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.sleep,
          value: '{"duration": 480}',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.numericValue, isNull);
      });

      test('intValue parses valid integers', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.intValue, 5000);
      });

      test('intValue returns null for non-integers', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.sleep,
          value: '{"duration": 480}',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.intValue, isNull);
      });

      test('complexValue parses valid JSON', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.sleep,
          value: '{"duration": 480, "quality": "good"}',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.complexValue, isNotNull);
        expect(point.complexValue!['duration'], 480);
        expect(point.complexValue!['quality'], 'good');
      });

      test('complexValue returns null for simple values', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.complexValue, isNull);
      });
    });

    group('Duration', () {
      test('calculates duration correctly', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.workout,
          value: '100',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point.duration, const Duration(hours: 1));
      });
    });

    group('Time Checks', () {
      test('isToday returns true for today', () {
        final now = DateTime.now();
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: now,
          endTime: now,
        );

        expect(point.isToday, true);
      });

      test('isToday returns false for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: yesterday,
          endTime: yesterday,
        );

        expect(point.isToday, false);
      });

      test('isThisWeek returns true for this week', () {
        final now = DateTime.now();
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: now,
          endTime: now,
        );

        expect(point.isThisWeek, true);
      });

      test('isThisWeek returns false for last week', () {
        final lastWeek = DateTime.now().subtract(const Duration(days: 8));
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: lastWeek,
          endTime: lastWeek,
        );

        expect(point.isThisWeek, false);
      });
    });

    group('Equality', () {
      test('points with same id and userId are equal', () {
        final point1 = HealthDataPoint(
          id: 'test-id',
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        final point2 = HealthDataPoint(
          id: 'test-id',
          userId: 'user1',
          dataType: HealthDataType.heartRate, // Different type
          value: '72', // Different value
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point1 == point2, true);
        expect(point1.hashCode, point2.hashCode);
      });

      test('points with different ids are not equal', () {
        final point1 = HealthDataPoint(
          id: 'test-id-1',
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        final point2 = HealthDataPoint(
          id: 'test-id-2',
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point1 == point2, false);
      });

      test('points with different userIds are not equal', () {
        final point1 = HealthDataPoint(
          id: 'test-id',
          userId: 'user1',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        final point2 = HealthDataPoint(
          id: 'test-id',
          userId: 'user2',
          dataType: HealthDataType.steps,
          value: '5000',
          startTime: testTime,
          endTime: testEndTime,
        );

        expect(point1 == point2, false);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final point = HealthDataPoint(
          userId: 'user1',
          dataType: HealthDataType.heartRate,
          value: '72',
          startTime: testTime,
          endTime: testEndTime,
          sourceApp: 'Google Fit',
        );

        final str = point.toString();
        expect(str, contains('Heart Rate'));
        expect(str, contains('72'));
        expect(str, contains('Google Fit'));
      });
    });
  });
}
