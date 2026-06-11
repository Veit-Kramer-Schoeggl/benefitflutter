import 'dart:math' show exp;

/// Result of step count validation
///
/// Based on z-score comparison between actual and expected steps.
enum StepValidationResult {
  /// Z-score 0-1: Normal variation, fully valid
  valid,

  /// Z-score 1-2: Slightly unusual but acceptable
  acceptedWithNote,

  /// Z-score 2-3: Suspicious, flag for review
  suspicious,

  /// Z-score >3: Likely invalid (gaming or vehicle)
  rejected,
}

/// Step length estimation and cross-validation configuration
///
/// Uses height, gender, and age to estimate expected step length,
/// then validates GPS distance against Health Connect/HealthKit
/// step count using z-score statistical analysis.
///
/// ## How It Works
/// 1. Calculate expected step length from user biometrics
/// 2. Calculate expected steps for GPS distance traveled
/// 3. Compare actual steps (from Health API) to expected
/// 4. Calculate z-score to determine validity
///
/// ## Step Length Research
/// Step length follows a Gaussian (normal) distribution within
/// demographic groups. Height is the primary predictor (~70% variance).
///
/// Key factors:
/// - Height: step_length ≈ height × 0.415 for walking
/// - Gender: Males ~3% longer at same height
/// - Age: ~1.5% decline per decade after 60
/// - Activity: Running stride ~1.5-2.5x walking
///
/// ## Usage
/// ```dart
/// // Calculate expected step length
/// final stepLength = StepValidationConfig.calculateStepLength(
///   heightCm: 175,
///   gender: 'male',
///   age: 35,
///   activityType: 'walking',
/// );
///
/// // Validate actual vs expected
/// final expected = StepValidationConfig.expectedSteps(
///   distanceMeters: 1500,
///   stepLengthCm: stepLength,
/// );
///
/// final result = StepValidationConfig.validateSteps(
///   actualSteps: healthConnectSteps,
///   expectedSteps: expected,
/// );
/// ```
///
/// ## Related
/// - [TrackingConfig] - Overall scoring configuration
class StepValidationConfig {
  StepValidationConfig._();

  // ============================================================
  // STEP LENGTH MULTIPLIERS BY ACTIVITY
  // ============================================================

  /// Walking: step_length = height_cm × 0.415
  ///
  /// Based on biomechanics research. Standard deviation ~12%.
  static const double walkingStepMultiplier = 0.415;

  /// Running base multiplier at jogging pace (8 km/h)
  ///
  /// step_length = height_cm × (0.65 + speed_factor)
  static const double runningStepMultiplierBase = 0.65;

  /// Running speed adjustment: +0.03 per km/h above reference
  ///
  /// Stride length increases with running speed.
  static const double runningStepMultiplierPerKmh = 0.03;

  /// Reference jogging speed (km/h) for running calculations
  static const double joggingReferenceSpeedKmh = 8.0;

  /// Maximum running multiplier (at sprint speeds)
  static const double maxRunningMultiplier = 1.0;

  // ============================================================
  // GENDER ADJUSTMENTS
  // ============================================================

  /// Male baseline (no adjustment)
  static const double maleGenderFactor = 1.0;

  /// Female: ~3% shorter steps at same height
  ///
  /// Due to slightly different leg-to-height ratio on average.
  static const double femaleGenderFactor = 0.97;

  // ============================================================
  // AGE ADJUSTMENTS
  // ============================================================

  /// Age at which stride length starts declining
  static const int ageDeclineStartAge = 60;

  /// Decline rate: 1.5% per decade after start age
  ///
  /// Natural decline in stride length with age.
  static const double ageDeclinePerDecade = 0.015;

  /// Maximum age adjustment (prevents excessive reduction)
  static const int maxAgeDeclineYears = 40;

  // ============================================================
  // VALIDATION THRESHOLDS (Z-SCORE BASED)
  // ============================================================

  /// Natural variation in step length (±12%)
  ///
  /// Used to calculate standard deviation for z-score.
  static const double naturalVariationSigma = 0.12;

  /// Z-score below this: accept without question
  ///
  /// 68% of valid data falls within 1 standard deviation.
  static const double acceptThresholdZScore = 1.0;

  /// Z-score below this: accept with note
  ///
  /// 95% of valid data falls within 2 standard deviations.
  static const double noteThresholdZScore = 2.0;

  /// Z-score below this: flag for review
  ///
  /// 99.7% of valid data falls within 3 standard deviations.
  /// Beyond this is highly suspicious.
  static const double flagThresholdZScore = 3.0;

  // ============================================================
  // TRUST ADJUSTMENTS BASED ON VALIDATION
  // ============================================================

  /// Bonus when cross-validation confirms data (+5%)
  static const double validatedBonus = 0.05;

  /// Penalty when data is suspicious (-30%)
  static const double suspiciousPenalty = 0.30;

  /// Penalty when data is rejected (-80%)
  static const double rejectedPenalty = 0.80;

  // ============================================================
  // CALCULATION METHODS
  // ============================================================

  /// Calculate expected step length in centimeters
  ///
  /// Uses height, gender, age, and activity type to estimate
  /// the user's typical step length.
  ///
  /// For running, [speedKmh] should be provided for accuracy.
  static double calculateStepLength({
    required double heightCm,
    required String gender,
    required int age,
    required String activityType,
    double? speedKmh,
  }) {
    double baseMultiplier;

    if (activityType.toLowerCase() == 'running' && speedKmh != null) {
      // Running: varies with speed
      final speedFactor =
          (speedKmh - joggingReferenceSpeedKmh) * runningStepMultiplierPerKmh;
      baseMultiplier = (runningStepMultiplierBase + speedFactor).clamp(
        runningStepMultiplierBase,
        maxRunningMultiplier,
      );
    } else {
      // Walking (default)
      baseMultiplier = walkingStepMultiplier;
    }

    // Gender factor
    final genderFactor = gender.toLowerCase() == 'male'
        ? maleGenderFactor
        : femaleGenderFactor;

    // Age factor (decline after 60)
    final yearsOverThreshold = (age - ageDeclineStartAge).clamp(
      0,
      maxAgeDeclineYears,
    );
    final decadesOver = yearsOverThreshold / 10.0;
    final ageFactor = 1.0 - (decadesOver * ageDeclinePerDecade);

    return heightCm * baseMultiplier * genderFactor * ageFactor;
  }

  /// Calculate expected steps for a given distance
  ///
  /// [distanceMeters] - GPS-measured distance traveled
  /// [stepLengthCm] - Expected step length from [calculateStepLength]
  static double expectedSteps({
    required double distanceMeters,
    required double stepLengthCm,
  }) {
    if (stepLengthCm <= 0) return 0;
    return (distanceMeters * 100) / stepLengthCm;
  }

  /// Calculate z-score for step count validation
  ///
  /// Z-score measures how many standard deviations the actual
  /// value is from the expected value.
  ///
  /// - z = 0: Exactly as expected
  /// - z = 1: Within normal variation (68% of data)
  /// - z = 2: Unusual (95% of data within this)
  /// - z = 3: Very unusual (99.7% of data within this)
  /// - z > 3: Highly suspicious
  static double calculateZScore({
    required int actualSteps,
    required double expectedSteps,
  }) {
    if (expectedSteps <= 0) return double.infinity;

    final sigma = expectedSteps * naturalVariationSigma;
    if (sigma <= 0) return double.infinity;

    return (actualSteps - expectedSteps).abs() / sigma;
  }

  /// Convert z-score to confidence (0.0 - 1.0)
  ///
  /// Uses normal distribution probability density function.
  /// Higher z-score = lower confidence.
  ///
  /// - z = 0 → confidence = 1.0
  /// - z = 1 → confidence ≈ 0.61
  /// - z = 2 → confidence ≈ 0.14
  /// - z = 3 → confidence ≈ 0.01
  static double zScoreToConfidence(double zScore) {
    if (zScore < 0) zScore = zScore.abs();
    return exp(-0.5 * zScore * zScore);
  }

  /// Determine validation outcome from z-score
  ///
  /// Maps z-score to a [StepValidationResult] category.
  static StepValidationResult validateSteps({
    required int actualSteps,
    required double expectedSteps,
  }) {
    final zScore = calculateZScore(
      actualSteps: actualSteps,
      expectedSteps: expectedSteps,
    );

    if (zScore <= acceptThresholdZScore) {
      return StepValidationResult.valid;
    } else if (zScore <= noteThresholdZScore) {
      return StepValidationResult.acceptedWithNote;
    } else if (zScore <= flagThresholdZScore) {
      return StepValidationResult.suspicious;
    } else {
      return StepValidationResult.rejected;
    }
  }

  /// Get trust adjustment based on validation result
  ///
  /// Returns a multiplier to apply to the trust score:
  /// - valid: 1.0 + [validatedBonus] (bonus for confirmed data)
  /// - acceptedWithNote: 1.0 (no adjustment)
  /// - suspicious: 1.0 - [suspiciousPenalty]
  /// - rejected: 1.0 - [rejectedPenalty]
  static double getTrustAdjustment(StepValidationResult result) {
    switch (result) {
      case StepValidationResult.valid:
        return 1.0 + validatedBonus;
      case StepValidationResult.acceptedWithNote:
        return 1.0;
      case StepValidationResult.suspicious:
        return 1.0 - suspiciousPenalty;
      case StepValidationResult.rejected:
        return 1.0 - rejectedPenalty;
    }
  }

  /// Full validation with trust adjustment
  ///
  /// Convenience method that combines step length calculation,
  /// validation, and trust adjustment.
  ///
  /// Returns the multiplier to apply to the sensor trust score.
  static double validateAndAdjust({
    required double distanceMeters,
    required int actualSteps,
    required double heightCm,
    required String gender,
    required int age,
    required String activityType,
    double? speedKmh,
  }) {
    final stepLength = calculateStepLength(
      heightCm: heightCm,
      gender: gender,
      age: age,
      activityType: activityType,
      speedKmh: speedKmh,
    );

    final expected = expectedSteps(
      distanceMeters: distanceMeters,
      stepLengthCm: stepLength,
    );

    final result = validateSteps(
      actualSteps: actualSteps,
      expectedSteps: expected,
    );

    return getTrustAdjustment(result);
  }
}
