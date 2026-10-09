import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/features/session/domain/activity_entry.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/providers/progress_provider.dart';

import '../../helpers/session_fakes.dart';

const _userId = 'test-user-123';

/// Monday 00:00 (local time) of the current week.
DateTime _startOfThisWeek() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday - 1));
}

/// Recorded session (the UI always records "running"). Defaults: 30 min,
/// 5 km = 10 km/h -> running, 9.0 MET x 0.5 h = 4.5 MET-hours.
Session _session(
  String id,
  DateTime startTime, {
  int durationSeconds = 1800,
  double distanceMeters = 5000,
  SessionStatus status = SessionStatus.completed,
}) {
  return Session(
    id: id,
    userId: _userId,
    trackingMode: TrackingMode.manual,
    activityType: ActivityType.running,
    status: status,
    startTime: startTime,
    durationSeconds: durationSeconds,
    distanceMeters: distanceMeters,
  );
}

void main() {
  group('ProgressProvider weekly statistics', () {
    late DateTime weekStart;

    setUp(() {
      // loadActivities() reads SharedPreferences before the session repo.
      SharedPreferences.setMockInitialValues(const {});
      weekStart = _startOfThisWeek();
    });

    Future<ProgressProvider> loadedProvider(List<Session> sessions) async {
      final repo = MockSessionRepository()..seedSessions(sessions);
      final provider = ProgressProvider(repo);
      // Setting the user starts a load; awaiting a second one makes sure the
      // sessions are in before the test reads them.
      provider.updateUserId(_userId);
      await provider.loadActivities();
      return provider;
    }

    /// Two sessions this week (Monday run, Tuesday walk) and two from last
    /// week, one of them on a Monday as well.
    List<Session> mixedWeeks() {
      return [
        // Monday 01:00: 5 km in 30 min -> 4.5 MET-hours
        _session('this-monday-run', weekStart.add(const Duration(hours: 1))),
        // Tuesday 08:00: 4 km in 60 min = 4 km/h -> walking, 4.0 MET-hours
        _session(
          'this-tuesday-walk',
          DateTime(weekStart.year, weekStart.month, weekStart.day + 1, 8),
          durationSeconds: 3600,
          distanceMeters: 4000,
        ),
        // Last week's Monday and Sunday: must not count
        _session(
          'last-monday-run',
          DateTime(weekStart.year, weekStart.month, weekStart.day - 7, 1),
        ),
        _session(
          'last-sunday-run',
          weekStart.subtract(const Duration(seconds: 1)),
        ),
      ];
    }

    test('getMetHoursThisWeek sums the MET-hours of this week only', () async {
      final provider = await loadedProvider([
        ...mixedWeeks(),
        // Not completed: never part of the statistics
        _session(
          'this-week-active',
          weekStart.add(const Duration(hours: 2)),
          status: SessionStatus.active,
        ),
      ]);

      expect(provider.activities, hasLength(4));
      expect(provider.getMetHoursThisWeek(), closeTo(8.5, 1e-9));
    });

    test('getMetHoursThisWeek includes manual entries of this week', () async {
      final provider = await loadedProvider(const []);

      provider.addActivity(
        ActivityEntry(
          activityType: 'Manual Entry',
          distanceKm: 5.0,
          duration: const Duration(minutes: 30),
          startTime: weekStart.add(const Duration(hours: 3)),
          isManual: true,
        ),
      );

      expect(provider.getMetHoursThisWeek(), closeTo(4.5, 1e-9));
    });

    test('getDistancePerWeekday only counts this week', () async {
      final provider = await loadedProvider(mixedWeeks());

      // Monday: last week's 5 km no longer adds up; Sunday stays empty
      expect(provider.getDistancePerWeekday(), {1: 5.0, 2: 4.0});
    });

    test('getDurationPerWeekdayMinutes only counts this week', () async {
      final provider = await loadedProvider(mixedWeeks());

      expect(provider.getDurationPerWeekdayMinutes(), {1: 30.0, 2: 60.0});
    });

    test('the week starts at Monday 00:00, inclusive', () async {
      final provider = await loadedProvider([
        _session('monday-midnight', weekStart),
        _session(
          'sunday-before',
          weekStart.subtract(const Duration(seconds: 1)),
        ),
      ]);

      expect(provider.getDurationPerWeekdayMinutes(), {1: 30.0});
      expect(provider.getMetHoursThisWeek(), closeTo(4.5, 1e-9));
    });

    test('isInCurrentWeek: Monday 00:00 inclusive, next Monday exclusive', () {
      final provider = ProgressProvider(MockSessionRepository());
      final nextMonday = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + 7,
      );

      expect(provider.isInCurrentWeek(weekStart), isTrue);
      expect(
        provider.isInCurrentWeek(
          nextMonday.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(provider.isInCurrentWeek(nextMonday), isFalse);
      expect(
        provider.isInCurrentWeek(
          weekStart.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('is empty without activity this week', () async {
      final provider = await loadedProvider([
        _session(
          'last-monday-run',
          weekStart.subtract(const Duration(days: 7)),
        ),
      ]);

      expect(provider.activities, hasLength(1));
      expect(provider.getMetHoursThisWeek(), 0.0);
      expect(provider.getDistancePerWeekday(), isEmpty);
      expect(provider.getDurationPerWeekdayMinutes(), isEmpty);
    });
  });
}
