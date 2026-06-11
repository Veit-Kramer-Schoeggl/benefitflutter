import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/config/step_validation_config.dart';

void main() {
  group('StepValidationConfig', () {
    group('calculateStepLength', () {
      test('calculates step length for average male walking', () {
        final stepLength = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'walking',
        );
        // Expected: 175 * 0.415 * 1.0 * 1.0 = 72.625 cm
        expect(stepLength, closeTo(72.625, 0.01));
      });

      test('calculates step length for average female walking', () {
        final stepLength = StepValidationConfig.calculateStepLength(
          heightCm: 165,
          gender: 'female',
          age: 35,
          activityType: 'walking',
        );
        // Expected: 165 * 0.415 * 0.97 * 1.0 = 66.42 cm
        expect(stepLength, closeTo(66.42, 0.1));
      });

      test('female factor reduces step length', () {
        final male = StepValidationConfig.calculateStepLength(
          heightCm: 170,
          gender: 'male',
          age: 30,
          activityType: 'walking',
        );
        final female = StepValidationConfig.calculateStepLength(
          heightCm: 170,
          gender: 'female',
          age: 30,
          activityType: 'walking',
        );
        expect(female, lessThan(male));
        expect(female / male, closeTo(0.97, 0.001));
      });

      test('age factor reduces step length after 60', () {
        final young = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 50,
          activityType: 'walking',
        );
        final older = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 70,
          activityType: 'walking',
        );
        expect(older, lessThan(young));
      });

      test('age factor does not apply before 60', () {
        final age30 = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 30,
          activityType: 'walking',
        );
        final age59 = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 59,
          activityType: 'walking',
        );
        expect(age30, equals(age59));
      });

      test('running increases step length', () {
        final walking = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'walking',
        );
        final running = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'running',
          speedKmh: 10.0,
        );
        expect(running, greaterThan(walking));
      });

      test('running step length increases with speed', () {
        final slowRun = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'running',
          speedKmh: 8.0,
        );
        final fastRun = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'running',
          speedKmh: 15.0,
        );
        expect(fastRun, greaterThan(slowRun));
      });

      test('gender is case insensitive', () {
        final male1 = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'walking',
        );
        final male2 = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'MALE',
          age: 35,
          activityType: 'walking',
        );
        expect(male1, equals(male2));
      });

      test('activity type is case insensitive', () {
        final running1 = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'running',
          speedKmh: 10.0,
        );
        final running2 = StepValidationConfig.calculateStepLength(
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'Running',
          speedKmh: 10.0,
        );
        expect(running1, equals(running2));
      });
    });

    group('expectedSteps', () {
      test('calculates expected steps for 1km with 70cm step', () {
        final steps = StepValidationConfig.expectedSteps(
          distanceMeters: 1000,
          stepLengthCm: 70,
        );
        // 1000m * 100cm/m / 70cm = 1428.57 steps
        expect(steps, closeTo(1428.57, 0.1));
      });

      test('returns 0 when step length is 0', () {
        final steps = StepValidationConfig.expectedSteps(
          distanceMeters: 1000,
          stepLengthCm: 0,
        );
        expect(steps, equals(0));
      });

      test('returns 0 when step length is negative', () {
        final steps = StepValidationConfig.expectedSteps(
          distanceMeters: 1000,
          stepLengthCm: -50,
        );
        expect(steps, equals(0));
      });

      test('handles short distances', () {
        final steps = StepValidationConfig.expectedSteps(
          distanceMeters: 10,
          stepLengthCm: 70,
        );
        // 10m * 100cm/m / 70cm = 14.29 steps
        expect(steps, closeTo(14.29, 0.1));
      });
    });

    group('calculateZScore', () {
      test('returns 0 when actual equals expected', () {
        final zScore = StepValidationConfig.calculateZScore(
          actualSteps: 1000,
          expectedSteps: 1000,
        );
        expect(zScore, equals(0));
      });

      test('returns positive for deviation above expected', () {
        final zScore = StepValidationConfig.calculateZScore(
          actualSteps: 1200,
          expectedSteps: 1000,
        );
        expect(zScore, greaterThan(0));
      });

      test('returns positive for deviation below expected', () {
        final zScore = StepValidationConfig.calculateZScore(
          actualSteps: 800,
          expectedSteps: 1000,
        );
        expect(zScore, greaterThan(0));
      });

      test('higher deviation gives higher z-score', () {
        final smallDeviation = StepValidationConfig.calculateZScore(
          actualSteps: 1050,
          expectedSteps: 1000,
        );
        final largeDeviation = StepValidationConfig.calculateZScore(
          actualSteps: 1200,
          expectedSteps: 1000,
        );
        expect(largeDeviation, greaterThan(smallDeviation));
      });

      test('returns infinity when expected is 0', () {
        final zScore = StepValidationConfig.calculateZScore(
          actualSteps: 100,
          expectedSteps: 0,
        );
        expect(zScore, equals(double.infinity));
      });

      test('z-score of 1 corresponds to ~12% deviation', () {
        // With sigma = 0.12, z=1 means deviation = 12% of expected
        final zScore = StepValidationConfig.calculateZScore(
          actualSteps: 1120, // 12% above 1000
          expectedSteps: 1000,
        );
        expect(zScore, closeTo(1.0, 0.01));
      });
    });

    group('zScoreToConfidence', () {
      test('z-score 0 gives confidence 1.0', () {
        expect(StepValidationConfig.zScoreToConfidence(0), equals(1.0));
      });

      test('z-score 1 gives confidence ~0.61', () {
        expect(
          StepValidationConfig.zScoreToConfidence(1),
          closeTo(0.606, 0.01),
        );
      });

      test('z-score 2 gives confidence ~0.14', () {
        expect(
          StepValidationConfig.zScoreToConfidence(2),
          closeTo(0.135, 0.01),
        );
      });

      test('z-score 3 gives confidence ~0.01', () {
        expect(
          StepValidationConfig.zScoreToConfidence(3),
          closeTo(0.011, 0.01),
        );
      });

      test('handles negative z-scores', () {
        expect(
          StepValidationConfig.zScoreToConfidence(-1),
          closeTo(StepValidationConfig.zScoreToConfidence(1), 0.001),
        );
      });

      test('confidence decreases with higher z-score', () {
        final conf0 = StepValidationConfig.zScoreToConfidence(0);
        final conf1 = StepValidationConfig.zScoreToConfidence(1);
        final conf2 = StepValidationConfig.zScoreToConfidence(2);
        final conf3 = StepValidationConfig.zScoreToConfidence(3);

        expect(conf1, lessThan(conf0));
        expect(conf2, lessThan(conf1));
        expect(conf3, lessThan(conf2));
      });
    });

    group('validateSteps', () {
      test('validates normal step count (z < 1)', () {
        // 1000 expected, 1050 actual = 5% deviation = z ~0.42
        final result = StepValidationConfig.validateSteps(
          actualSteps: 1050,
          expectedSteps: 1000,
        );
        expect(result, equals(StepValidationResult.valid));
      });

      test('accepts with note for slight deviation (1 < z < 2)', () {
        // 1000 expected, 1150 actual = 15% deviation = z ~1.25
        final result = StepValidationConfig.validateSteps(
          actualSteps: 1150,
          expectedSteps: 1000,
        );
        expect(result, equals(StepValidationResult.acceptedWithNote));
      });

      test('flags suspicious for larger deviation (2 < z < 3)', () {
        // 1000 expected, 1300 actual = 30% deviation = z ~2.5
        final result = StepValidationConfig.validateSteps(
          actualSteps: 1300,
          expectedSteps: 1000,
        );
        expect(result, equals(StepValidationResult.suspicious));
      });

      test('rejects for extreme deviation (z > 3)', () {
        // 1000 expected, 500 actual = 50% deviation = z ~4.17
        final result = StepValidationConfig.validateSteps(
          actualSteps: 500,
          expectedSteps: 1000,
        );
        expect(result, equals(StepValidationResult.rejected));
      });

      test('boundary: exactly at accept threshold', () {
        // z = 1.0 means 12% deviation (1120 for 1000 expected)
        final result = StepValidationConfig.validateSteps(
          actualSteps: 1120,
          expectedSteps: 1000,
        );
        expect(result, equals(StepValidationResult.valid));
      });

      test('boundary: just above accept threshold', () {
        // z = 1.01 means ~12.1% deviation
        final result = StepValidationConfig.validateSteps(
          actualSteps: 1122,
          expectedSteps: 1000,
        );
        expect(result, equals(StepValidationResult.acceptedWithNote));
      });
    });

    group('getTrustAdjustment', () {
      test('valid result gives bonus', () {
        final adjustment = StepValidationConfig.getTrustAdjustment(
          StepValidationResult.valid,
        );
        expect(adjustment, greaterThan(1.0));
        expect(adjustment, equals(1.0 + StepValidationConfig.validatedBonus));
      });

      test('acceptedWithNote gives no adjustment', () {
        final adjustment = StepValidationConfig.getTrustAdjustment(
          StepValidationResult.acceptedWithNote,
        );
        expect(adjustment, equals(1.0));
      });

      test('suspicious result gives penalty', () {
        final adjustment = StepValidationConfig.getTrustAdjustment(
          StepValidationResult.suspicious,
        );
        expect(adjustment, lessThan(1.0));
        expect(
          adjustment,
          equals(1.0 - StepValidationConfig.suspiciousPenalty),
        );
      });

      test('rejected result gives large penalty', () {
        final adjustment = StepValidationConfig.getTrustAdjustment(
          StepValidationResult.rejected,
        );
        expect(adjustment, lessThan(0.5));
        expect(adjustment, equals(1.0 - StepValidationConfig.rejectedPenalty));
      });

      test('rejected penalty is larger than suspicious penalty', () {
        expect(
          StepValidationConfig.rejectedPenalty,
          greaterThan(StepValidationConfig.suspiciousPenalty),
        );
      });
    });

    group('validateAndAdjust', () {
      test('returns bonus for valid data', () {
        // 1.5km walk, 175cm male, 35yo
        // Expected: 1500m / 0.72625m = ~2066 steps
        // Actual: 2100 (close to expected)
        final adjustment = StepValidationConfig.validateAndAdjust(
          distanceMeters: 1500,
          actualSteps: 2100,
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'walking',
        );
        expect(adjustment, greaterThan(1.0));
      });

      test('returns penalty for suspicious data', () {
        // Same distance but very few steps - suspicious
        final adjustment = StepValidationConfig.validateAndAdjust(
          distanceMeters: 1500,
          actualSteps: 500, // Way too few
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'walking',
        );
        expect(adjustment, lessThan(1.0));
      });

      test('accounts for running activity', () {
        // Running should expect fewer steps (longer stride)
        final walking = StepValidationConfig.validateAndAdjust(
          distanceMeters: 1000,
          actualSteps: 1000, // Low for walking
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'walking',
        );
        final running = StepValidationConfig.validateAndAdjust(
          distanceMeters: 1000,
          actualSteps: 1000, // More reasonable for running
          heightCm: 175,
          gender: 'male',
          age: 35,
          activityType: 'running',
          speedKmh: 10.0,
        );
        // Running should be more valid with same step count
        expect(running, greaterThanOrEqualTo(walking));
      });
    });

    group('Constants validation', () {
      test('thresholds are in increasing order', () {
        expect(
          StepValidationConfig.acceptThresholdZScore,
          lessThan(StepValidationConfig.noteThresholdZScore),
        );
        expect(
          StepValidationConfig.noteThresholdZScore,
          lessThan(StepValidationConfig.flagThresholdZScore),
        );
      });

      test('penalties are in increasing order', () {
        expect(StepValidationConfig.validatedBonus, greaterThan(0));
        expect(
          StepValidationConfig.suspiciousPenalty,
          lessThan(StepValidationConfig.rejectedPenalty),
        );
      });

      test('natural variation sigma is reasonable', () {
        expect(StepValidationConfig.naturalVariationSigma, greaterThan(0));
        expect(StepValidationConfig.naturalVariationSigma, lessThan(0.5));
      });

      test('step multipliers are reasonable', () {
        expect(StepValidationConfig.walkingStepMultiplier, greaterThan(0.3));
        expect(StepValidationConfig.walkingStepMultiplier, lessThan(0.6));
        expect(
          StepValidationConfig.runningStepMultiplierBase,
          greaterThan(StepValidationConfig.walkingStepMultiplier),
        );
      });
    });
  });
}
