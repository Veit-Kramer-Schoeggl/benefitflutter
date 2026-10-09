import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/seed/seed_data.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/session/domain/session.dart';

/// Generated multi-year activity history for the two seed users.
///
/// The hand-written sessions in [SeedData] cover the last seven days. This
/// fills everything before that back to [historyStart], so the Progress
/// statistics (yearly, monthly, weekly, totals) have years of data to show.
///
/// Deterministic for a given Dart SDK: a fixed-seed [math.Random] walks the
/// calendar forward from [historyStart], so a day older than the hand-written
/// week always gets the same session, whenever the seed runs. Only the end of
/// the window moves with `now`. Routes use a random generator seeded from a
/// hash of the session id, so they are stable as well. (dart:math does not
/// promise the same seeded sequence across SDK releases.)
///
/// The volumes are tuned to the Progress charts: every year from 2021 has
/// distance (the yearly chart spans six years), no year comes near the
/// ~7,000 km at which the chart's 30-px y-axis would need a 5-digit label, and
/// running paces stay inside the 7-25 km/h band that `ActivityDose` scores as
/// vigorous.
class SeedHistory {
  SeedHistory._();

  /// First day of generated history.
  static final DateTime historyStart = DateTime(2021, 1, 1);

  /// Days 1..7 before today belong to the hand-written sessions in [SeedData].
  static const int handWrittenDays = 7;

  /// Sessions that start within this many days (today included) get a route.
  static const int routeDays = 28;

  /// All generated sessions: each user's history oldest first, then today's.
  ///
  /// Memoised per calendar day: one seeding run asks for the sessions several
  /// times (sessions, routes, summary), and generating years of history each
  /// time would add up on the splash screen. Static state survives a hot
  /// reload, so hot-restart after editing the generator before using the
  /// debug "Reset Seed Data" button.
  static List<Session> sessions(DateTime now) {
    final key = '${_dayKey(now)}-${_hasTodaySession(now)}';
    final cached = _cache;
    if (cached != null && cached.$1 == key) return cached.$2;
    final generated = List<Session>.unmodifiable([
      ..._history(_developer, now),
      ..._history(_runner, now),
      ..._today(now),
    ]);
    _cache = (key, generated);
    return generated;
  }

  static (String, List<Session>)? _cache;

  @visibleForTesting
  static void debugResetCache() => _cache = null;

  /// GPS routes for every completed distance session of the seed users that
  /// started in the last [routeDays] days, hand-written ones included.
  ///
  /// Each route is a closed loop starting at a park in the user's city (the
  /// city of their seeded preferences, mapped in [_cityFor]); long rides loop
  /// through the wider city. Resampled so its length matches `distanceMeters`
  /// and its timestamps span `durationSeconds`.
  static List<GpsPoint> routesFor(List<Session> sessions, DateTime now) {
    final from = DateTime(now.year, now.month, now.day - (routeDays - 1));
    final points = <GpsPoint>[];
    for (final session in sessions) {
      final distance = session.distanceMeters;
      final duration = session.durationSeconds;
      final city = _cityFor(session.userId);
      if (city == null ||
          session.status != SessionStatus.completed ||
          distance == null ||
          distance <= 0 ||
          duration == null ||
          duration <= 0 ||
          session.startTime.isBefore(from) ||
          session.startTime.isAfter(now)) {
        continue;
      }
      points.addAll(_route(session, city, distance, duration));
    }
    return points;
  }

  // ========================================
  // HISTORY
  // ========================================

  /// Relative activity per calendar month (Jan..Dec): quiet winters, busy
  /// summers. Mean is about 0.94.
  static const List<double> _season = [
    0.60, 0.65, 0.85, 1.00, 1.15, 1.25, //
    1.25, 1.15, 1.10, 0.95, 0.75, 0.60,
  ];

  static List<Session> _history(_Persona persona, DateTime now) {
    final rng = math.Random(persona.randomSeed);
    final lastDay = DateTime(
      now.year,
      now.month,
      now.day - (handWrittenDays + 1),
    );
    final sessions = <Session>[];
    var vacations = <_DayRange>[];
    var plannedYear = 0;

    for (
      var day = historyStart;
      !day.isAfter(lastDay);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (day.year != plannedYear) {
        plannedYear = day.year;
        vacations = _planVacations(rng, day.year);
      }
      final rate = persona.weeklySessions(day.year) * _season[day.month - 1];
      final chance = rate / 7 * persona.weekdayWeights[day.weekday - 1];
      // Draw before the vacation check so a day consumes the same numbers
      // either way and later days stay put.
      final roll = rng.nextDouble();
      if (roll >= chance || vacations.any((v) => v.contains(day))) continue;
      sessions.add(_session(persona, day, rng));
    }
    return sessions;
  }

  /// One or two breaks a year (holidays, a cold) with no activity at all.
  static List<_DayRange> _planVacations(math.Random rng, int year) {
    final count = rng.nextDouble() < 0.5 ? 1 : 2;
    return [
      for (var i = 0; i < count; i++)
        _DayRange.starting(
          DateTime(year, 2 + rng.nextInt(10), 1 + rng.nextInt(28)),
          days: 7 + rng.nextInt(9),
        ),
    ];
  }

  static Session _session(_Persona persona, DateTime day, math.Random rng) {
    final weekend = day.weekday >= DateTime.saturday;
    final type = persona.pickType(rng, day, weekend: weekend);
    final paceFactor = 1 + 0.012 * (day.year - historyStart.year).clamp(0, 6);

    final int startMinute;
    if (weekend) {
      startMinute = 8 * 60 + 5 * rng.nextInt(43); // 08:00-11:30
    } else if (rng.nextDouble() < persona.morningShare) {
      startMinute = 6 * 60 + 30 + 5 * rng.nextInt(16); // 06:30-07:45
    } else {
      startMinute = 17 * 60 + 30 + 5 * rng.nextInt(28); // 17:30-19:45
    }
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startMinute ~/ 60,
      startMinute % 60,
    );

    final double? distanceMeters;
    final int durationSeconds;
    if (type == ActivityType.yoga) {
      distanceMeters = null;
      durationSeconds = (45 + 5 * rng.nextInt(7)) * 60; // 45-75 min
    } else {
      final effort = persona.effort(rng, type, day, weekend: weekend);
      final km = _between(rng, effort.minKm, effort.maxKm);
      final kmh = _between(rng, effort.minKmh, effort.maxKmh) * paceFactor;
      distanceMeters = (km * 1000).roundToDouble();
      durationSeconds = (km / kmh * 3600).round();
    }
    // A few minutes of stops (traffic lights, stretching) on top of the
    // active time, so end - start >= duration as in a real recording.
    final pauseSeconds = distanceMeters == null ? 0 : 60 * rng.nextInt(4);
    final end = start.add(Duration(seconds: durationSeconds + pauseSeconds));

    return Session(
      id: '${persona.idPrefix}-${_dayKey(day)}',
      userId: persona.userId,
      trackingMode: TrackingMode.manual,
      activityType: type,
      status: SessionStatus.completed,
      startTime: start,
      endTime: end,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      trackingDate: DateTime(day.year, day.month, day.day),
      createdAt: end,
    );
  }

  /// One session early today per user, so the TODAY group and the current
  /// week have data even on a Monday. Only from 08:30, when both are over.
  static List<Session> _today(DateTime now) {
    if (!_hasTodaySession(now)) return const [];
    final today = DateTime(now.year, now.month, now.day);
    return [
      _todaySession(
        _runner,
        today,
        ActivityType.running,
        const _Effort(6, 7.5, 10.5, 11.5),
        hour: 6,
        minute: 45,
      ),
      _todaySession(
        _developer,
        today,
        ActivityType.walking,
        const _Effort(2.6, 3.4, 4.8, 5.4),
        hour: 7,
        minute: 15,
      ),
    ];
  }

  static Session _todaySession(
    _Persona persona,
    DateTime today,
    ActivityType type,
    _Effort effort, {
    required int hour,
    required int minute,
  }) {
    final rng = math.Random(
      _stableHash('today-${persona.idPrefix}-${_dayKey(today)}'),
    );
    final km = _between(rng, effort.minKm, effort.maxKm);
    final kmh = _between(rng, effort.minKmh, effort.maxKmh);
    final durationSeconds = (km / kmh * 3600).round();
    final start = DateTime(today.year, today.month, today.day, hour, minute);
    final end = start.add(Duration(seconds: durationSeconds));
    return Session(
      id: '${persona.idPrefix}-${_dayKey(today)}',
      userId: persona.userId,
      trackingMode: TrackingMode.manual,
      activityType: type,
      status: SessionStatus.completed,
      startTime: start,
      endTime: end,
      durationSeconds: durationSeconds,
      distanceMeters: (km * 1000).roundToDouble(),
      trackingDate: today,
      createdAt: end,
    );
  }

  static bool _hasTodaySession(DateTime now) =>
      !now.isBefore(DateTime(now.year, now.month, now.day, 8, 30));

  // ========================================
  // ROUTES
  // ========================================

  static _City? _cityFor(String userId) => switch (userId) {
    SeedData.testUserId => _vienna, // prefs-1: defaultLocationCity 'Vienna'
    SeedData.testUserId2 => _berlin, // prefs-2: defaultLocationCity 'Berlin'
    _ => null,
  };

  static const _vienna = _City(
    altitude: 170,
    centers: [
      (48.2120, 16.4050), // Prater, Hauptallee
      (48.2300, 16.4080), // Donauinsel
      (48.1830, 16.3120), // Schönbrunn
    ],
  );

  static const _berlin = _City(
    altitude: 38,
    centers: [
      (52.5145, 13.3501), // Tiergarten
      (52.4730, 13.4030), // Tempelhofer Feld
      (52.4880, 13.4690), // Treptower Park
    ],
  );

  static const double _metersPerDegreeLat = 111320;

  static List<GpsPoint> _route(
    Session session,
    _City city,
    double distance,
    int duration,
  ) {
    final rng = math.Random(_stableHash(session.id));
    final (centerLat, centerLon) =
        city.centers[rng.nextInt(city.centers.length)];
    // Nudge the centre so loops from the same park do not stack exactly.
    final lat0 = centerLat + (rng.nextDouble() - 0.5) * 0.004;
    final lon0 = centerLon + (rng.nextDouble() - 0.5) * 0.006;
    final aspect = 0.55 + rng.nextDouble() * 0.45;
    final rotation = rng.nextDouble() * math.pi;
    final phase2 = rng.nextDouble() * 2 * math.pi;
    final phase3 = rng.nextDouble() * 2 * math.pi;
    final phase5 = rng.nextDouble() * 2 * math.pi;
    final altitudePhase = rng.nextDouble() * 2 * math.pi;

    // A wobbly ellipse in local metres around (0, 0). Its size does not
    // matter yet: it is scaled to the session distance below.
    const raw = 720;
    final xs = List<double>.filled(raw + 1, 0);
    final ys = List<double>.filled(raw + 1, 0);
    for (var i = 0; i <= raw; i++) {
      final theta = 2 * math.pi * i / raw;
      final r =
          1000 *
          (1 +
              0.16 * math.sin(2 * theta + phase2) +
              0.09 * math.sin(3 * theta + phase3) +
              0.05 * math.sin(5 * theta + phase5));
      final x = r * math.cos(theta);
      final y = r * aspect * math.sin(theta);
      xs[i] = x * math.cos(rotation) - y * math.sin(rotation);
      ys[i] = x * math.sin(rotation) + y * math.cos(rotation);
    }
    final cumulative = List<double>.filled(raw + 1, 0);
    for (var i = 1; i <= raw; i++) {
      cumulative[i] =
          cumulative[i - 1] +
          math.sqrt(
            math.pow(xs[i] - xs[i - 1], 2) + math.pow(ys[i] - ys[i - 1], 2),
          );
    }
    final scale = distance / cumulative[raw];

    // About one point every 120 m, like a sparse recording.
    final n = (distance / 120).round().clamp(24, 160);
    final metersPerDegreeLon =
        _metersPerDegreeLat * math.cos(lat0 * math.pi / 180);
    final start = session.startTime;
    final points = <GpsPoint>[];
    var segment = 1;
    double? previousLat;
    double? previousLon;
    for (var k = 0; k < n; k++) {
      // Walk along the loop to the point k/(n-1) of the way round.
      final target = cumulative[raw] * k / (n - 1);
      while (segment < raw && cumulative[segment] < target) {
        segment++;
      }
      final span = cumulative[segment] - cumulative[segment - 1];
      final t = span == 0 ? 0.0 : (target - cumulative[segment - 1]) / span;
      final x = (xs[segment - 1] + (xs[segment] - xs[segment - 1]) * t) * scale;
      final y = (ys[segment - 1] + (ys[segment] - ys[segment - 1]) * t) * scale;
      final lat = lat0 + y / _metersPerDegreeLat;
      final lon = lon0 + x / metersPerDegreeLon;

      final timestamp = start.add(
        Duration(milliseconds: (duration * 1000 * k / (n - 1)).round()),
      );
      double speed = 0;
      if (previousLat != null && previousLon != null) {
        final stepMeters = math.sqrt(
          math.pow((lat - previousLat) * _metersPerDegreeLat, 2) +
              math.pow((lon - previousLon) * metersPerDegreeLon, 2),
        );
        final stepSeconds = duration / (n - 1);
        speed = stepMeters / stepSeconds * _between(rng, 0.95, 1.05);
      }
      points.add(
        GpsPoint(
          id: 'gps-${session.id}-$k',
          sessionId: session.id,
          latitude: lat,
          longitude: lon,
          altitude:
              city.altitude +
              6 * math.sin(2 * math.pi * k / (n - 1) + altitudePhase) +
              _between(rng, -1, 1),
          accuracyMeters: _between(rng, 3, 9),
          speedMetersPerSecond: speed,
          timestamp: timestamp,
          createdAt: timestamp,
        ),
      );
      previousLat = lat;
      previousLon = lon;
    }
    return points;
  }

  // ========================================
  // HELPERS
  // ========================================

  static double _between(math.Random rng, double min, double max) =>
      min + (max - min) * rng.nextDouble();

  static String _dayKey(DateTime day) =>
      '${day.year}${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  /// FNV-1a over the UTF-16 code units. Unlike [String.hashCode] this is
  /// guaranteed to stay the same across runs and platforms.
  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      final x = hash ^ unit;
      // x * 0x01000193 (the FNV prime) as x * 0x193 + (x << 24): modulo 2^32
      // only the low byte of x survives the shift, and no intermediate passes
      // 2^53, so the result is exact on the web as well.
      hash = (x * 0x193 + ((x & 0xff) << 24)) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

// ==========================================
// PERSONAS
// ==========================================

/// Test Developer (test-user-123, Vienna): started out walking in 2021 and
/// slowly turned into a regular runner and commuter cyclist.
final _developer = _Persona(
  userId: SeedData.testUserId,
  idPrefix: 'gen-u1',
  randomSeed: 123,
  sessionsPerWeek: const {
    2021: 1.1,
    2022: 1.6,
    2023: 2.0,
    2024: 2.3,
    2025: 2.5,
    2026: 2.6,
  },
  weekdayWeights: const [0.8, 1.2, 0.7, 1.2, 0.6, 1.3, 1.2],
  morningShare: 0.35,
  mix: (year, month) {
    final progress = ((year - 2021) / 4).clamp(0.0, 1.0);
    return {
      ActivityType.walking: 0.60 - 0.30 * progress,
      ActivityType.cycling: 0.15 + 0.15 * progress,
      ActivityType.running: 0.25 + 0.15 * progress,
    };
  },
  effort: (rng, type, day, {required weekend}) => switch (type) {
    ActivityType.running => const _Effort(4, 10, 9, 11.5),
    ActivityType.cycling =>
      weekend && rng.nextDouble() < 0.25
          ? const _Effort(30, 45, 18, 24)
          : const _Effort(12, 28, 16, 23),
    _ => const _Effort(3, 7, 4.6, 5.6),
  },
);

/// Sarah Runner (test-user-321, Berlin): runs most days, long runs on
/// Sundays, yoga in between, the occasional ride or hike.
final _runner = _Persona(
  userId: SeedData.testUserId2,
  idPrefix: 'gen-u2',
  randomSeed: 321,
  sessionsPerWeek: const {
    2021: 2.4,
    2022: 2.8,
    2023: 3.1,
    2024: 3.3,
    2025: 3.5,
    2026: 3.5,
  },
  weekdayWeights: const [1.1, 0.9, 1.1, 0.8, 0.7, 1.0, 1.4],
  morningShare: 0.55,
  mix: (year, month) => const {
    ActivityType.running: 0.60,
    ActivityType.yoga: 0.15,
    ActivityType.cycling: 0.11,
    ActivityType.walking: 0.07,
    ActivityType.hiking: 0.07,
  },
  effort: (rng, type, day, {required weekend}) => switch (type) {
    ActivityType.running =>
      day.weekday == DateTime.sunday && rng.nextDouble() < 0.5
          ? const _Effort(16, 21.1, 10, 11.5)
          : const _Effort(7, 15, 10, 12.5),
    ActivityType.cycling =>
      weekend ? const _Effort(40, 60, 21, 27) : const _Effort(25, 40, 21, 27),
    ActivityType.hiking => const _Effort(8, 16, 4, 4.8),
    _ => const _Effort(3, 6, 4.8, 5.6),
  },
);

typedef _Mix = Map<ActivityType, double> Function(int year, int month);
typedef _EffortFor =
    _Effort Function(
      math.Random rng,
      ActivityType type,
      DateTime day, {
      required bool weekend,
    });

class _Persona {
  const _Persona({
    required this.userId,
    required this.idPrefix,
    required this.randomSeed,
    required this.sessionsPerWeek,
    required this.weekdayWeights,
    required this.morningShare,
    required this.mix,
    required _EffortFor effort,
  }) : _effort = effort;

  final String userId;
  final String idPrefix;
  final int randomSeed;

  /// Average sessions per week by year; later years keep the last value.
  final Map<int, double> sessionsPerWeek;

  /// Relative preference per weekday, Monday first; averages 1.
  final List<double> weekdayWeights;

  /// Share of weekday sessions done before work rather than after.
  final double morningShare;

  final _Mix mix;
  final _EffortFor _effort;

  double weeklySessions(int year) =>
      sessionsPerWeek[year] ??
      sessionsPerWeek[sessionsPerWeek.keys.reduce(math.max)]!;

  _Effort effort(
    math.Random rng,
    ActivityType type,
    DateTime day, {
    required bool weekend,
  }) => _effort(rng, type, day, weekend: weekend);

  /// Weighted pick from [mix]. Winters cut cycling, and hikes only happen on
  /// weekends (a weekday hike becomes a walk).
  ActivityType pickType(
    math.Random rng,
    DateTime day, {
    required bool weekend,
  }) {
    final winter = day.month == 12 || day.month <= 2;
    final weights = {
      for (final entry in mix(day.year, day.month).entries)
        entry.key: entry.key == ActivityType.cycling && winter
            ? entry.value * 0.35
            : entry.value,
    };
    final total = weights.values.fold(0.0, (sum, w) => sum + w);
    var roll = rng.nextDouble() * total;
    var picked = weights.keys.last;
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll < 0) {
        picked = entry.key;
        break;
      }
    }
    if (picked == ActivityType.hiking && !weekend) return ActivityType.walking;
    return picked;
  }
}

/// Distance and speed range for one activity.
class _Effort {
  const _Effort(this.minKm, this.maxKm, this.minKmh, this.maxKmh);

  final double minKm;
  final double maxKm;
  final double minKmh;
  final double maxKmh;
}

/// Parks to loop around and the city's typical altitude.
class _City {
  const _City({required this.altitude, required this.centers});

  final double altitude;
  final List<(double, double)> centers;
}

/// Inclusive range of calendar days.
class _DayRange {
  _DayRange.starting(this.first, {required int days})
    : last = DateTime(first.year, first.month, first.day + days - 1);

  final DateTime first;
  final DateTime last;

  bool contains(DateTime day) => !day.isBefore(first) && !day.isAfter(last);
}
