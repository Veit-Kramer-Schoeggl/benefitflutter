import 'dart:math' as math;

import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/seed/seed_data.dart';
import 'package:benefitflutter/core/seed/seed_history.dart';
import 'package:benefitflutter/features/session/data/gps_point_dao.dart';
import 'package:benefitflutter/features/session/data/session_dao.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/features/shared/database/database_helper.dart';
import 'package:benefitflutter/features/user/data/user_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Guards the generated seed history: deterministic, physically plausible,
/// inside the limits the Progress charts can render, and insertable as a
/// whole with foreign keys on.
void main() {
  // Friday evening: the hand-written week, history before it, a walk today.
  final now = DateTime(2026, 10, 9, 20, 30);
  final sessions = SeedData.getSessions(now: now);
  final gpsPoints = SeedData.getGpsPoints(now: now);

  final users = [SeedData.testUserId, SeedData.testUserId2];
  final completed = sessions
      .where((s) => s.status == SessionStatus.completed)
      .toList();

  group('determinism', () {
    test('the same now yields the same sessions and routes', () {
      SeedHistory.debugResetCache(); // regenerate, don't reread the memo
      final again = SeedData.getSessions(now: now);
      expect(again.map(_fingerprint), sessions.map(_fingerprint));
      final againPoints = SeedData.getGpsPoints(now: now);
      expect(
        againPoints.map(_pointFingerprint),
        gpsPoints.map(_pointFingerprint),
      );
    });

    test('a past day keeps its session when the seed runs later', () {
      final cutoff = DateTime(2026, 9, 1);
      List<String> before(DateTime when) => SeedHistory.sessions(
        when,
      ).where((s) => s.startTime.isBefore(cutoff)).map(_fingerprint).toList();

      expect(before(DateTime(2026, 11, 20, 12)), before(now));
    });

    test('one session today per user from 08:30, none before', () {
      List<Session> todayAt(int hour, int minute) => SeedData.getSessions(
        now: DateTime(2026, 10, 9, hour, minute),
      ).where((s) => !s.startTime.isBefore(DateTime(2026, 10, 9))).toList();

      // session-active (started 15 min before now) is not one of them.
      bool generated(Session s) => s.status == SessionStatus.completed;

      expect(todayAt(8, 29).where(generated), isEmpty);
      for (final (hour, minute) in [(8, 30), (20, 30)]) {
        final at = DateTime(2026, 10, 9, hour, minute);
        final today = todayAt(hour, minute).where(generated).toList();
        expect(today, hasLength(2));
        expect(today.map((s) => s.userId).toSet(), users.toSet());
        for (final s in today) {
          expect(s.endTime!.isAfter(at), isFalse, reason: s.id);
        }
      }
    });
  });

  group('sessions', () {
    test('ids are unique', () {
      final ids = sessions.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('the hand-written week and everything referencing it survive', () {
      final ids = sessions.map((s) => s.id).toSet();
      for (final id in [
        'session-1',
        'session-2',
        'session-3',
        'session-4',
        'session-5',
        'session-active',
        'session-u2-1',
        'session-u2-2',
        'session-u2-3',
        'session-u2-4',
      ]) {
        expect(ids, contains(id));
      }
      final referenced = {
        ...SeedData.getUserBenefits().map((b) => b.sessionId),
        ...SeedData.getSensorSummaries().map((s) => s.sessionId),
        ...SeedData.getBiometricSensorData().map((p) => p.sessionId),
        ...SeedData.getMotionSensorData().map((p) => p.sessionId),
      };
      expect(ids, containsAll(referenced));
    });

    test('completed sessions are in the past and internally consistent', () {
      for (final s in completed) {
        expect(s.startTime.isBefore(now), isTrue, reason: s.id);
        expect(s.endTime!.isAfter(now), isFalse, reason: s.id);
        expect(s.durationSeconds, isNotNull, reason: s.id);
        expect(s.durationSeconds, greaterThan(0), reason: s.id);
        final window = s.endTime!.difference(s.startTime).inSeconds;
        expect(window, greaterThanOrEqualTo(s.durationSeconds!), reason: s.id);
      }
    });

    test('sessions of one user never overlap', () {
      for (final user in users) {
        final mine = completed.where((s) => s.userId == user).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        for (var i = 1; i < mine.length; i++) {
          expect(
            mine[i].startTime.isBefore(mine[i - 1].endTime!),
            isFalse,
            reason: '${mine[i - 1].id} overlaps ${mine[i].id}',
          );
        }
      }
    });

    test('speeds stay in the bands ActivityDose expects', () {
      for (final s in completed.where((s) => s.distanceMeters != null)) {
        final kmh = s.distanceMeters! / 1000 / (s.durationSeconds! / 3600);
        switch (s.activityType) {
          case ActivityType.running:
            // 7-25 km/h scores as vigorous running, not as walking or 0.
            expect(kmh, inInclusiveRange(7, 25), reason: s.id);
          case ActivityType.cycling:
            expect(kmh, lessThan(40), reason: s.id); // above 40 scores 0
          default:
            expect(kmh, lessThan(7), reason: s.id);
        }
      }
    });
  });

  group('statistics', () {
    Map<int, double> kmPerYear(String user) {
      final years = <int, double>{};
      for (final s in completed.where((s) => s.userId == user)) {
        years[s.startTime.year] =
            (years[s.startTime.year] ?? 0) + (s.distanceMeters ?? 0) / 1000;
      }
      return years;
    }

    test('every year of the six-year chart has distance', () {
      for (final user in users) {
        final years = kmPerYear(user);
        for (var year = now.year - 5; year <= now.year; year++) {
          expect(years[year], greaterThan(100), reason: '$user $year');
        }
      }
    });

    test('totals stay inside what the charts can label', () {
      for (final user in users) {
        // The yearly chart's 30-px y-axis cannot fit a 5-digit label, which
        // it would need above ~7,270 km.
        expect(kmPerYear(user).values, everyElement(lessThan(7000)));

        final months = <String, double>{};
        for (final s in completed.where((s) => s.userId == user)) {
          final key = '${s.startTime.year}-${s.startTime.month}';
          months[key] = (months[key] ?? 0) + (s.distanceMeters ?? 0) / 1000;
        }
        // 'NNN.N' monthly bar labels just fit; 4 digits would not.
        expect(months.values, everyElement(lessThan(1000)));
      }
    });

    test('the runner covers more ground than the developer every year', () {
      final developer = kmPerYear(SeedData.testUserId);
      final runner = kmPerYear(SeedData.testUserId2);
      for (var year = now.year - 5; year <= now.year; year++) {
        expect(runner[year], greaterThan(developer[year]!), reason: '$year');
      }
    });

    test('the current week has activity for both users on every weekday', () {
      // Mon 2026-10-05 .. Sun 2026-10-11, each in the evening.
      for (var day = 5; day <= 11; day++) {
        final at = DateTime(2026, 10, day, 20, 30);
        final monday = DateTime(at.year, at.month, at.day - (at.weekday - 1));
        final week = SeedData.getSessions(now: at).where(
          (s) =>
              s.status == SessionStatus.completed &&
              !s.startTime.isBefore(monday),
        );
        for (final user in users) {
          expect(
            week.where((s) => s.userId == user),
            isNotEmpty,
            reason: '$user on 2026-10-$day',
          );
        }
      }
    });
  });

  group('routes', () {
    final byId = {for (final s in sessions) s.id: s};
    final routes = <String, List<GpsPoint>>{};
    for (final p in gpsPoints) {
      routes.putIfAbsent(p.sessionId, () => []).add(p);
    }

    test('every recent distance session has a route, older ones none', () {
      final from = DateTime(now.year, now.month, now.day - 27);
      final expected = completed
          .where(
            (s) => (s.distanceMeters ?? 0) > 0 && !s.startTime.isBefore(from),
          )
          .map((s) => s.id)
          .toSet();
      expect(routes.keys.toSet(), expected);
    });

    test('points belong to their session in time and quality', () {
      for (final entry in routes.entries) {
        final session = byId[entry.key]!;
        final points = entry.value;
        expect(points.length, greaterThanOrEqualTo(24), reason: entry.key);
        for (var i = 0; i < points.length; i++) {
          final p = points[i];
          expect(p.timestamp.isBefore(session.startTime), isFalse);
          expect(p.timestamp.isAfter(session.endTime!), isFalse);
          if (i > 0) {
            expect(p.timestamp.isAfter(points[i - 1].timestamp), isTrue);
          }
          // Session details drop points less accurate than 50 m.
          expect(p.accuracyMeters, lessThanOrEqualTo(50));
        }
      }
    });

    test('route length matches the session distance', () {
      for (final entry in routes.entries) {
        final distance = byId[entry.key]!.distanceMeters!;
        expect(
          _length(entry.value),
          closeTo(distance, distance * 0.05),
          reason: entry.key,
        );
      }
    });

    test('routes are in the city from the user preferences', () {
      const vienna = (48.2082, 16.3738);
      const berlin = (52.5200, 13.4050);
      for (final p in gpsPoints) {
        final city = byId[p.sessionId]!.userId == SeedData.testUserId
            ? vienna
            : berlin;
        final km = _haversine(p.latitude, p.longitude, city.$1, city.$2) / 1000;
        expect(km, lessThan(25), reason: p.id);
      }
    });
  });

  group('database', () {
    setUpAll(sqfliteFfiInit);

    final helper = DatabaseHelper();
    late Database db;

    setUp(() async {
      db = await helper.openAppDatabase(
        databaseFactoryFfi,
        inMemoryDatabasePath,
      );
      DatabaseHelper.debugDatabase = db;
    });

    tearDown(() async {
      DatabaseHelper.debugDatabase = null;
      await db.close();
    });

    test('the whole history inserts with foreign keys on', () async {
      final userDao = UserDao();
      for (final user in SeedData.getUsers()) {
        await userDao.insert(user);
      }
      await SessionDao().insertBatch(sessions);
      await GpsPointDao().insertBatch(gpsPoints);

      Future<Object?> count(String table) async =>
          (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n'];
      expect(await count('sessions'), sessions.length);
      expect(await count('gps_points'), gpsPoints.length);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });

    test('insertBatch replaces instead of duplicating', () async {
      for (final user in SeedData.getUsers()) {
        await UserDao().insert(user);
      }
      final dao = SessionDao();
      await dao.insertBatch(sessions, chunkSize: 97);
      // Second pass with one changed row: REPLACE must store the new value
      // (IGNORE would keep the old one, a plain INSERT would throw).
      final changed = [
        for (final s in sessions)
          s.id == 'session-1' ? s.copyWith(distanceMeters: 4321) : s,
      ];
      await dao.insertBatch(changed, chunkSize: 97);

      final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM sessions');
      expect(rows.single['n'], sessions.length);
      final stored = await db.rawQuery(
        "SELECT distance_meters FROM sessions WHERE id = 'session-1'",
      );
      expect(stored.single['distance_meters'], 4321);
    });
  });
}

String _fingerprint(Session s) =>
    '${s.id}|${s.userId}|${s.activityType.name}|${s.status.name}|'
    '${s.startTime.toIso8601String()}|${s.endTime?.toIso8601String()}|'
    '${s.durationSeconds}|${s.distanceMeters}';

String _pointFingerprint(GpsPoint p) =>
    '${p.id}|${p.latitude}|${p.longitude}|${p.timestamp.toIso8601String()}';

double _length(List<GpsPoint> points) {
  var meters = 0.0;
  for (var i = 1; i < points.length; i++) {
    meters += _haversine(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
  }
  return meters;
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(a));
}
