import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/config/tracking_config.dart';

void main() {
  group('TrackingConfig', () {
    group('Sensor Trust Multipliers', () {
      test('all multipliers are positive', () {
        expect(TrackingConfig.gpsOnlyMultiplier, greaterThan(0));
        expect(TrackingConfig.gpsPedometerMultiplier, greaterThan(0));
        expect(TrackingConfig.gpsBarometerMultiplier, greaterThan(0));
        expect(TrackingConfig.gpsWristHrMultiplier, greaterThan(0));
        expect(TrackingConfig.gpsChestHrMultiplier, greaterThan(0));
        expect(TrackingConfig.fullSensorMultiplier, greaterThan(0));
      });

      test('all multipliers are at most 1.0', () {
        expect(TrackingConfig.gpsOnlyMultiplier, lessThanOrEqualTo(1.0));
        expect(TrackingConfig.gpsPedometerMultiplier, lessThanOrEqualTo(1.0));
        expect(TrackingConfig.gpsBarometerMultiplier, lessThanOrEqualTo(1.0));
        expect(TrackingConfig.gpsWristHrMultiplier, lessThanOrEqualTo(1.0));
        expect(TrackingConfig.gpsChestHrMultiplier, lessThanOrEqualTo(1.0));
        expect(TrackingConfig.fullSensorMultiplier, lessThanOrEqualTo(1.0));
      });

      test('multipliers increase with more sensors', () {
        // GPS only < GPS + Pedometer
        expect(
          TrackingConfig.gpsOnlyMultiplier,
          lessThan(TrackingConfig.gpsPedometerMultiplier),
        );

        // GPS + Pedometer < GPS + Barometer
        expect(
          TrackingConfig.gpsPedometerMultiplier,
          lessThan(TrackingConfig.gpsBarometerMultiplier),
        );

        // GPS + Chest HR > GPS + Wrist HR
        expect(
          TrackingConfig.gpsChestHrMultiplier,
          greaterThan(TrackingConfig.gpsWristHrMultiplier),
        );

        // Full sensor is highest
        expect(
          TrackingConfig.fullSensorMultiplier,
          greaterThanOrEqualTo(TrackingConfig.gpsChestHrMultiplier),
        );
      });
    });

    group('Anti-Gaming Filters', () {
      test('speed limits are reasonable', () {
        // Min speed should be very low (catch GPS drift)
        expect(TrackingConfig.minValidSpeedKmh, greaterThan(0));
        expect(TrackingConfig.minValidSpeedKmh, lessThan(1));

        // Max speed should allow fast cycling but catch vehicles
        expect(TrackingConfig.maxValidSpeedKmh, greaterThan(20));
        expect(TrackingConfig.maxValidSpeedKmh, lessThan(50));
      });
    });

    group('Activity Multipliers', () {
      test('walking is baseline (1.0)', () {
        expect(TrackingConfig.walkingMultiplier, equals(1.0));
      });

      test('running and cycling have bonus', () {
        expect(
          TrackingConfig.runningMultiplier,
          greaterThan(TrackingConfig.walkingMultiplier),
        );
        expect(
          TrackingConfig.cyclingMultiplier,
          greaterThan(TrackingConfig.walkingMultiplier),
        );
      });

      test('daily movement has no bonus', () {
        expect(TrackingConfig.dailyMovementMultiplier, equals(1.0));
      });
    });

    group('Continuous Tracking Defaults', () {
      test('continuous tracking is disabled by default', () {
        expect(TrackingConfig.continuousEnabledByDefault, isFalse);
      });

      test('default reset points are valid 24h times', () {
        expect(TrackingConfig.defaultResetPoints, isNotEmpty);

        for (final time in TrackingConfig.defaultResetPoints) {
          expect(time, matches(RegExp(r'^\d{2}:\d{2}$')));
        }
      });
    });

    group('isValidSpeed', () {
      test('returns true for normal walking speed', () {
        expect(TrackingConfig.isValidSpeed(5.0), isTrue);
      });

      test('returns true for normal running speed', () {
        expect(TrackingConfig.isValidSpeed(12.0), isTrue);
      });

      test('returns true for cycling speed', () {
        expect(TrackingConfig.isValidSpeed(20.0), isTrue);
      });

      test('returns false for stationary (too slow)', () {
        expect(TrackingConfig.isValidSpeed(0.1), isFalse);
      });

      test('returns false for vehicle speed (too fast)', () {
        expect(TrackingConfig.isValidSpeed(30.0), isFalse);
        expect(TrackingConfig.isValidSpeed(50.0), isFalse);
      });

      test('boundary conditions', () {
        // At min boundary
        expect(
          TrackingConfig.isValidSpeed(TrackingConfig.minValidSpeedKmh),
          isTrue,
        );
        // Just below min
        expect(
          TrackingConfig.isValidSpeed(TrackingConfig.minValidSpeedKmh - 0.1),
          isFalse,
        );
        // At max boundary
        expect(
          TrackingConfig.isValidSpeed(TrackingConfig.maxValidSpeedKmh),
          isTrue,
        );
        // Just above max
        expect(
          TrackingConfig.isValidSpeed(TrackingConfig.maxValidSpeedKmh + 0.1),
          isFalse,
        );
      });
    });

    group('calculateScore', () {
      test('applies all multipliers correctly', () {
        final score = TrackingConfig.calculateScore(
          baseDistancePoints: 100,
          sensorTrustMultiplier: 0.5,
          deviceMultiplier: 1.0,
          activityMultiplier: 1.3,
        );

        expect(score, equals(65.0)); // 100 * 0.5 * 1.0 * 1.3
      });

      test('returns 0 when base points are 0', () {
        final score = TrackingConfig.calculateScore(
          baseDistancePoints: 0,
          sensorTrustMultiplier: 0.9,
          deviceMultiplier: 1.0,
          activityMultiplier: 1.0,
        );

        expect(score, equals(0.0));
      });

      test('device multiplier affects score', () {
        final normalScore = TrackingConfig.calculateScore(
          baseDistancePoints: 100,
          sensorTrustMultiplier: 0.5,
          deviceMultiplier: 1.0,
          activityMultiplier: 1.0,
        );

        final reducedScore = TrackingConfig.calculateScore(
          baseDistancePoints: 100,
          sensorTrustMultiplier: 0.5,
          deviceMultiplier: 0.8,
          activityMultiplier: 1.0,
        );

        expect(reducedScore, lessThan(normalScore));
        expect(reducedScore, equals(40.0)); // 100 * 0.5 * 0.8 * 1.0
      });
    });

    group('getActivityMultiplier', () {
      test('returns correct multiplier for walking', () {
        expect(TrackingConfig.getActivityMultiplier('walking'), equals(1.0));
        expect(TrackingConfig.getActivityMultiplier('Walking'), equals(1.0));
        expect(TrackingConfig.getActivityMultiplier('WALKING'), equals(1.0));
      });

      test('returns correct multiplier for running', () {
        expect(TrackingConfig.getActivityMultiplier('running'), equals(1.3));
      });

      test('returns correct multiplier for cycling', () {
        expect(TrackingConfig.getActivityMultiplier('cycling'), equals(1.2));
      });

      test('returns daily movement multiplier for unknown types', () {
        expect(TrackingConfig.getActivityMultiplier('swimming'), equals(1.0));
        expect(TrackingConfig.getActivityMultiplier('unknown'), equals(1.0));
        expect(TrackingConfig.getActivityMultiplier(''), equals(1.0));
      });
    });
  });
}
