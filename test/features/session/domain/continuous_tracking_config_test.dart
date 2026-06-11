import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/session/domain/continuous_tracking_config.dart';

void main() {
  group('ContinuousTrackingConfig', () {
    group('constructor', () {
      test('creates config with required fields', () {
        final config = ContinuousTrackingConfig(
          id: 'test-id',
          userId: 'user-123',
          isEnabled: true,
          resetPoints: ['03:00'],
          activityDetection: 'hybrid',
          gpsIntervalSeconds: 300,
          minDisplacementMeters: 100,
        );

        expect(config.id, equals('test-id'));
        expect(config.userId, equals('user-123'));
        expect(config.isEnabled, isTrue);
        expect(config.resetPoints, equals(['03:00']));
        expect(config.activityDetection, equals('hybrid'));
        expect(config.gpsIntervalSeconds, equals(300));
        expect(config.minDisplacementMeters, equals(100));
      });

      test('sets timestamps when not provided', () {
        final before = DateTime.now();
        final config = ContinuousTrackingConfig(
          id: 'test-id',
          userId: 'user-123',
          isEnabled: false,
          resetPoints: ['03:00'],
          activityDetection: 'manual',
          gpsIntervalSeconds: 300,
          minDisplacementMeters: 100,
        );
        final after = DateTime.now();

        expect(
          config.createdAt.isAfter(before) || config.createdAt == before,
          isTrue,
        );
        expect(
          config.createdAt.isBefore(after) || config.createdAt == after,
          isTrue,
        );
      });
    });

    group('defaultFor', () {
      test('creates default config for user', () {
        final config = ContinuousTrackingConfig.defaultFor('user-456');

        expect(config.id, equals('ctc-user-456'));
        expect(config.userId, equals('user-456'));
        expect(config.isEnabled, isFalse);
        expect(config.resetPoints, equals(['03:00']));
        expect(config.activityDetection, equals('hybrid'));
        expect(config.gpsIntervalSeconds, equals(300));
        expect(config.minDisplacementMeters, equals(100));
      });
    });

    group('fromJson', () {
      test('parses JSON with integer booleans', () {
        final json = {
          'id': 'config-1',
          'user_id': 'user-1',
          'is_enabled': 1,
          'reset_points': '["03:00","15:00"]',
          'activity_detection': 'auto',
          'gps_interval_seconds': 600,
          'min_displacement_meters': 200,
          'created_at': 1700000000000,
          'updated_at': 1700000000000,
        };

        final config = ContinuousTrackingConfig.fromJson(json);

        expect(config.id, equals('config-1'));
        expect(config.userId, equals('user-1'));
        expect(config.isEnabled, isTrue);
        expect(config.resetPoints, equals(['03:00', '15:00']));
        expect(config.activityDetection, equals('auto'));
        expect(config.gpsIntervalSeconds, equals(600));
        expect(config.minDisplacementMeters, equals(200));
      });

      test('parses JSON with boolean values', () {
        final json = {
          'id': 'config-2',
          'user_id': 'user-2',
          'is_enabled': true,
          'reset_points': ['06:00'],
          'activity_detection': 'manual',
          'gps_interval_seconds': 300,
          'min_displacement_meters': 100,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final config = ContinuousTrackingConfig.fromJson(json);

        expect(config.isEnabled, isTrue);
        expect(config.resetPoints, equals(['06:00']));
      });

      test('handles missing reset_points', () {
        final json = {
          'id': 'config-3',
          'user_id': 'user-3',
          'is_enabled': 0,
          'activity_detection': 'hybrid',
          'gps_interval_seconds': 300,
          'min_displacement_meters': 100,
          'created_at': 1700000000000,
          'updated_at': 1700000000000,
        };

        final config = ContinuousTrackingConfig.fromJson(json);

        expect(config.resetPoints, equals(['03:00']));
      });

      test('handles invalid reset_points JSON', () {
        final json = {
          'id': 'config-4',
          'user_id': 'user-4',
          'is_enabled': 0,
          'reset_points': 'invalid json',
          'activity_detection': 'hybrid',
          'gps_interval_seconds': 300,
          'min_displacement_meters': 100,
          'created_at': 1700000000000,
          'updated_at': 1700000000000,
        };

        final config = ContinuousTrackingConfig.fromJson(json);

        expect(config.resetPoints, equals(['03:00']));
      });
    });

    group('toJson', () {
      test('converts to JSON with integer booleans', () {
        final config = ContinuousTrackingConfig(
          id: 'config-1',
          userId: 'user-1',
          isEnabled: true,
          resetPoints: ['03:00', '15:00'],
          activityDetection: 'hybrid',
          gpsIntervalSeconds: 300,
          minDisplacementMeters: 100,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        );

        final json = config.toJson();

        expect(json['id'], equals('config-1'));
        expect(json['user_id'], equals('user-1'));
        expect(json['is_enabled'], equals(1));
        expect(json['reset_points'], equals('["03:00","15:00"]'));
        expect(json['activity_detection'], equals('hybrid'));
        expect(json['gps_interval_seconds'], equals(300));
        expect(json['min_displacement_meters'], equals(100));
        expect(json['created_at'], equals(1700000000000));
      });

      test('roundtrip conversion', () {
        final original = ContinuousTrackingConfig(
          id: 'config-rt',
          userId: 'user-rt',
          isEnabled: true,
          resetPoints: ['04:00', '16:00'],
          activityDetection: 'auto',
          gpsIntervalSeconds: 450,
          minDisplacementMeters: 150,
        );

        final json = original.toJson();
        final restored = ContinuousTrackingConfig.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.isEnabled, equals(original.isEnabled));
        expect(restored.resetPoints, equals(original.resetPoints));
        expect(restored.activityDetection, equals(original.activityDetection));
        expect(
          restored.gpsIntervalSeconds,
          equals(original.gpsIntervalSeconds),
        );
        expect(
          restored.minDisplacementMeters,
          equals(original.minDisplacementMeters),
        );
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = ContinuousTrackingConfig.defaultFor('user-1');
        final copy = original.copyWith(
          isEnabled: true,
          activityDetection: 'auto',
        );

        expect(copy.id, equals(original.id));
        expect(copy.userId, equals(original.userId));
        expect(copy.isEnabled, isTrue);
        expect(copy.activityDetection, equals('auto'));
        expect(copy.resetPoints, equals(original.resetPoints));
      });

      test('preserves original when no changes', () {
        final original = ContinuousTrackingConfig.defaultFor('user-1');
        final copy = original.copyWith();

        expect(copy.id, equals(original.id));
        expect(copy.isEnabled, equals(original.isEnabled));
      });

      test('updates updatedAt timestamp', () {
        final original = ContinuousTrackingConfig(
          id: 'config-1',
          userId: 'user-1',
          isEnabled: false,
          resetPoints: ['03:00'],
          activityDetection: 'hybrid',
          gpsIntervalSeconds: 300,
          minDisplacementMeters: 100,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        );

        final copy = original.copyWith(isEnabled: true);

        expect(copy.updatedAt.isAfter(original.updatedAt), isTrue);
      });
    });

    group('helper getters', () {
      test('gpsInterval returns Duration', () {
        final config = ContinuousTrackingConfig.defaultFor('user-1');

        expect(config.gpsInterval, equals(const Duration(seconds: 300)));
      });

      test('isManualDetection returns true for manual mode', () {
        final config = ContinuousTrackingConfig.defaultFor(
          'user-1',
        ).copyWith(activityDetection: 'manual');

        expect(config.isManualDetection, isTrue);
        expect(config.isAutoDetection, isFalse);
        expect(config.isHybridDetection, isFalse);
      });

      test('isAutoDetection returns true for auto mode', () {
        final config = ContinuousTrackingConfig.defaultFor(
          'user-1',
        ).copyWith(activityDetection: 'auto');

        expect(config.isManualDetection, isFalse);
        expect(config.isAutoDetection, isTrue);
        expect(config.isHybridDetection, isFalse);
      });

      test('isHybridDetection returns true for hybrid mode', () {
        final config = ContinuousTrackingConfig.defaultFor('user-1');

        expect(config.isManualDetection, isFalse);
        expect(config.isAutoDetection, isFalse);
        expect(config.isHybridDetection, isTrue);
      });
    });

    group('equality', () {
      test('configs with same id are equal', () {
        final config1 = ContinuousTrackingConfig(
          id: 'same-id',
          userId: 'user-1',
          isEnabled: true,
          resetPoints: ['03:00'],
          activityDetection: 'hybrid',
          gpsIntervalSeconds: 300,
          minDisplacementMeters: 100,
        );

        final config2 = ContinuousTrackingConfig(
          id: 'same-id',
          userId: 'user-2',
          isEnabled: false,
          resetPoints: ['06:00'],
          activityDetection: 'auto',
          gpsIntervalSeconds: 600,
          minDisplacementMeters: 200,
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('configs with different ids are not equal', () {
        final config1 = ContinuousTrackingConfig.defaultFor('user-1');
        final config2 = ContinuousTrackingConfig.defaultFor('user-2');

        expect(config1, isNot(equals(config2)));
      });
    });
  });
}
