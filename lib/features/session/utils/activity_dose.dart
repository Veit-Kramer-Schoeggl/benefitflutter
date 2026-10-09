import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/features/session/domain/activity_entry.dart';

/// Model rows of the independent-years table.
enum ModelSex { male, female }

/// Model estimate in months of independent life: main value and its band
/// ([low]–[high]). [capped] is set when the weekly dose was limited to
/// [ActivityDose.maxModelMetHours].
typedef GainEstimate = ({int months, int low, int high, bool capped});

/// Weekly activity dose (MET-hours) and the "independent years" model from
/// the team's bachelor thesis.
///
/// Independent years ("selbstständige Jahre") are years without permanent
/// Austrian long-term care allowance (Pflegegeld, level >= 1). They are NOT
/// "healthy life years", an EU indicator that measures something else.
///
/// Source: Bachelorarbeit, analysis/verlaufskurven.md, generated block
/// "Gewinn nach Dosis" (Abb. 4), model run 2026-10-02. All model numbers are
/// preliminary.
class ActivityDose {
  // Private constructor to prevent instantiation
  ActivityDose._();

  // ===== DOSE AXIS (MET-hours per week) =====

  /// WHO recommendation: 150 min of moderate activity per week x 4.5 MET.
  static const double recommendedMetHours = 11.25;

  // MET per activity (thesis constants)
  static const double walkingMet = 4.0;
  static const double cyclingMet = 6.8;
  static const double moderateMet = 4.5;

  /// Vigorous = 2 x moderate. An assumption, used for running: the thesis
  /// has no checked running value.
  static const double vigorousMet = 2 * moderateMet;

  // Average-speed thresholds (km/h). App-level assumptions, NOT from the
  // thesis: the UI records every session as "running", so walking vs.
  // running is inferred from the speed.
  static const double _minWalkingKmh = 2.0; // below: stationary / GPS drift
  static const double _minRunningKmh = 7.0;
  static const double _maxRunningKmh = 25.0; // above: vehicle
  static const double _maxCyclingKmh = 40.0; // above: vehicle

  /// MET value of [entry]:
  /// - walking, hiking: [walkingMet]
  /// - cycling: [cyclingMet] (0 above 40 km/h)
  /// - swimming, strength training, yoga, dancing, martial arts, team sports:
  ///   [moderateMet]
  /// - running, trail running, other, "Manual Entry" and unknown types: by
  ///   average speed (see [_metFromSpeed])
  static double metForEntry(ActivityEntry entry) {
    final speedKmh = _averageSpeedKmh(entry);

    // Unknown strings (e.g. "Manual Entry") map to ActivityType.other.
    return switch (ActivityType.fromJson(entry.activityType)) {
      ActivityType.walking || ActivityType.hiking => walkingMet,
      ActivityType.cycling =>
        speedKmh != null && speedKmh > _maxCyclingKmh ? 0.0 : cyclingMet,
      ActivityType.swimming ||
      ActivityType.strengthTraining ||
      ActivityType.yoga ||
      ActivityType.dancing ||
      ActivityType.martialArts ||
      ActivityType.teamSports => moderateMet,
      ActivityType.running ||
      ActivityType.trailRunning ||
      ActivityType.other => _metFromSpeed(speedKmh),
    };
  }

  /// MET-hours of [entry]: MET x active hours.
  static double metHoursForEntry(ActivityEntry entry) {
    return metForEntry(entry) * _activeHours(entry);
  }

  /// Speed rule (app-level assumption, NOT from the thesis). Without a speed
  /// (GPS off, manual entry without km) it counts as walking (conservative).
  static double _metFromSpeed(double? speedKmh) {
    if (speedKmh == null) return walkingMet;
    if (speedKmh > _maxRunningKmh) return 0.0; // vehicle
    if (speedKmh >= _minRunningKmh) return vigorousMet;
    if (speedKmh >= _minWalkingKmh) return walkingMet;
    return 0.0; // stationary / GPS drift
  }

  /// Active hours of [entry]; the recorded duration already excludes pauses.
  static double _activeHours(ActivityEntry entry) {
    final seconds = entry.duration?.inSeconds ?? 0;
    return seconds > 0 ? seconds / 3600.0 : 0.0;
  }

  /// Average speed in km/h, or null without distance or duration.
  static double? _averageSpeedKmh(ActivityEntry entry) {
    final distanceKm = entry.distanceKm;
    final hours = _activeHours(entry);
    if (distanceKm == null || distanceKm <= 0 || hours <= 0) return null;
    return distanceKm / hours;
  }

  // ===== MODEL (preliminary) =====

  /// Below this weekly dose the model shows no number.
  static const double minModelMetHours = 2.0;

  /// Doses above twice the recommendation are capped: beyond it the upper
  /// band is not reliable, so the 25 and 30 rows are never read.
  static const double maxModelMetHours = 2 * recommendedMetHours;

  /// Support points of the dose axis (MET-hours per week).
  static const List<double> _doseAxis = [
    2,
    4,
    6,
    9,
    11.25,
    15,
    18.75,
    22.5,
    25,
    30,
  ];

  /// Gain in months of independent life per [_doseAxis] point: (main, low,
  /// high). Start age 40, the weekly dose kept up permanently vs. staying
  /// inactive. Preliminary values from "Gewinn nach Dosis" (Abb. 4).
  static const Map<ModelSex, List<(int, int, int)>> _gainMonths = {
    ModelSex.male: [
      (8, 3, 12),
      (11, 6, 15),
      (13, 9, 20),
      (16, 11, 26),
      (18, 12, 32),
      (22, 14, 39),
      (25, 16, 46),
      (28, 18, 54),
      (30, 19, 58),
      (33, 20, 68),
    ],
    ModelSex.female: [
      (5, 2, 10),
      (7, 5, 12),
      (10, 6, 17),
      (12, 8, 24),
      (15, 9, 29),
      (18, 11, 38),
      (22, 13, 47),
      (25, 14, 56),
      (27, 15, 62),
      (30, 17, 74),
    ],
  };

  /// Gain in months of independent life for a weekly dose kept up from age
  /// 40, or null below [minModelMetHours]. Interpolates linearly between the
  /// support points only (never beyond them) and rounds to whole months.
  static GainEstimate? estimateGainMonths(
    double metHoursPerWeek,
    ModelSex sex,
  ) {
    if (metHoursPerWeek.isNaN || metHoursPerWeek < minModelMetHours) {
      return null;
    }
    final capped = metHoursPerWeek > maxModelMetHours;
    final dose = capped ? maxModelMetHours : metHoursPerWeek;

    // Segment [_doseAxis[i], _doseAxis[i + 1]] that contains the dose
    var i = 0;
    while (_doseAxis[i + 1] < dose) {
      i++;
    }
    final t = (dose - _doseAxis[i]) / (_doseAxis[i + 1] - _doseAxis[i]);
    final (months0, low0, high0) = _gainMonths[sex]![i];
    final (months1, low1, high1) = _gainMonths[sex]![i + 1];
    int lerp(int from, int to) => (from + (to - from) * t).round();

    return (
      months: lerp(months0, months1),
      low: lerp(low0, low1),
      high: lerp(high0, high1),
      capped: capped,
    );
  }

  /// Model row for a profile gender ('male' | 'female' | 'other' | null);
  /// null when the profile names neither row.
  static ModelSex? modelSexForGender(String? gender) {
    return switch (gender) {
      'male' => ModelSex.male,
      'female' => ModelSex.female,
      _ => null,
    };
  }
}
