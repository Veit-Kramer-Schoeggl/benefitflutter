import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/progress/progress_screen.dart';
import 'package:benefitflutter/presentation/screens/progress/widgets/activity_dose_card.dart';
import 'package:benefitflutter/presentation/screens/progress/widgets/activity_list_item.dart';
import 'package:benefitflutter/presentation/screens/session/session_detail_screen.dart';

import '../../helpers/app_harness.dart';

Session completedSession({
  required String id,
  required DateTime startTime,
  ActivityType type = ActivityType.running,
  int durationSeconds = 1800,
  double distanceMeters = 5000,
}) {
  return Session(
    id: id,
    userId: harnessUserId,
    trackingMode: TrackingMode.manual,
    activityType: type,
    status: SessionStatus.completed,
    startTime: startTime,
    durationSeconds: durationSeconds,
    distanceMeters: distanceMeters,
  );
}

/// Monday 00:00 (local time) of the current week: always inside the window of
/// the weekly statistics.
DateTime startOfThisWeek() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday - 1));
}

Future<void> openProgress(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byType(MainNavigationScreen));
  await tester.tap(find.text('Progress'));
  await pumpUntilFound(tester, find.byType(ProgressScreen));
}

void main() {
  group('Progress screen', () {
    testWidgets('statistics tab shows empty state with no activities', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: true);
      await openProgress(tester);

      // STATISTICS is the default tab.
      await pumpUntilFound(
        tester,
        find.text('Perform activities to see statistics.'),
      );
    });

    testWidgets('activities tab shows empty state with no activities', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: true);
      await openProgress(tester);

      // Tab switch runs a ~300ms animation → pump until the content appears.
      await tester.tap(find.text('ACTIVITIES'));
      await pumpUntilFound(tester, find.text('No activities yet.'));
    });

    testWidgets('activities tab lists a seeded session and opens its detail', (
      tester,
    ) async {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      await pumpApp(
        tester,
        authenticated: true,
        sessions: [
          completedSession(id: 'session-old', startTime: thirtyDaysAgo),
        ],
      );
      await openProgress(tester);

      await tester.tap(find.text('ACTIVITIES'));
      await pumpUntilFound(tester, find.byType(ActivityListItem));

      expect(find.text('OLDER'), findsOneWidget);
      expect(find.text('running'), findsOneWidget);
      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('00:30:00'), findsOneWidget);

      // Tapping a row pushes /session/:id (data load is Round 8's concern;
      // here we only assert navigation happened).
      await tester.tap(find.byType(ActivityListItem));
      await pumpUntilFound(tester, find.byType(SessionDetailScreen));
    });

    testWidgets('statistics tab shows summary cards + chart with data', (
      tester,
    ) async {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      await pumpApp(
        tester,
        authenticated: true,
        sessions: [
          completedSession(id: 'session-recent', startTime: oneHourAgo),
        ],
      );
      await openProgress(tester);

      // Summary cards (Text widgets) + a chart title (Text above the canvas
      // chart). Axis labels are canvas-painted → not asserted here.
      await pumpUntilFound(tester, find.text('This Week'));
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Weekly Distance (km)'), findsOneWidget);
    });

    testWidgets('dose card shows this week\'s share and both model rows', (
      tester,
    ) async {
      await pumpApp(
        tester,
        authenticated: true,
        sessions: [
          // 5 km in 30 min = 10 km/h -> running, 9.0 MET x 0.5 h = 4.5 MET-h
          completedSession(id: 'session-week', startTime: startOfThisWeek()),
          // Last week's run must not count
          completedSession(
            id: 'session-last-week',
            startTime: startOfThisWeek().subtract(const Duration(days: 3)),
          ),
        ],
      );
      await openProgress(tester);

      await pumpUntilFound(tester, find.text('ACTIVITY THIS WEEK'));
      expect(find.text('40 %'), findsOneWidget);
      expect(find.text('of the weekly WHO recommendation'), findsOneWidget);
      expect(
        find.text('4.5 of 11.25 MET-hours · 30m recorded'),
        findsOneWidget,
      );
      // The harness user has no gender -> women–men, one band over both rows
      expect(
        find.text(
          'Keeping up this weekly level from age 40 is linked to about 8–12 '
          'more independent months on average (women–men; range 5–16).',
        ),
        findsOneWidget,
      );
      expect(find.text('INDEPENDENT YEARS · MODEL'), findsOneWidget);
    });

    testWidgets('dose card uses the model row of the profile gender', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        authenticated: true,
        sessions: [
          completedSession(id: 'session-week', startTime: startOfThisWeek()),
        ],
      );
      h.auth.setCurrentUser(h.auth.currentUser!.copyWith(gender: 'female'));
      await openProgress(tester);

      await pumpUntilFound(tester, find.text('ACTIVITY THIS WEEK'));
      expect(
        find.text(
          'Keeping up this weekly level from age 40 is linked to about 8 '
          'more independent months on average (range 5–13).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('dose card shows no model number below 2 MET-hours', (
      tester,
    ) async {
      await pumpApp(
        tester,
        authenticated: true,
        sessions: [
          // 1.5 km in 20 min = 4.5 km/h -> walking, 4.0 MET x 1/3 h = 1.3 MET-h
          completedSession(
            id: 'session-short-walk',
            startTime: startOfThisWeek(),
            durationSeconds: 1200,
            distanceMeters: 1500,
          ),
        ],
      );
      await openProgress(tester);

      await pumpUntilFound(tester, find.text('ACTIVITY THIS WEEK'));
      expect(find.text('12 %'), findsOneWidget);
      expect(
        find.text(
          'Short, brisk sessions count too. From 2 MET-hours a week, the '
          'model estimate appears here.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('independent months'), findsNothing);
    });

    testWidgets('dose card caps the model at twice the recommendation', (
      tester,
    ) async {
      await pumpApp(
        tester,
        authenticated: true,
        sessions: [
          // 30 km in 3 h = 10 km/h -> running, 9.0 MET x 3 h = 27 MET-h
          completedSession(
            id: 'session-long-run',
            startTime: startOfThisWeek(),
            durationSeconds: 3 * 3600,
            distanceMeters: 30000,
          ),
        ],
      );
      await openProgress(tester);

      await pumpUntilFound(tester, find.text('ACTIVITY THIS WEEK'));
      // The percentage may exceed 100 %, the bar stays full
      expect(find.text('240 %'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byType(ActivityDoseCard),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, 1.0);
      // Evaluated at 22.5 MET-h; the upper band is the women's (56 > 54)
      expect(
        find.text(
          'Keeping up this weekly level from age 40 is linked to about 25–28 '
          'more independent months on average (women–men; range 14–56). '
          'Shown up to twice the recommendation.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('dose card info button explains the model', (tester) async {
      await pumpApp(
        tester,
        authenticated: true,
        sessions: [
          completedSession(id: 'session-week', startTime: startOfThisWeek()),
        ],
      );
      await openProgress(tester);

      await pumpUntilFound(tester, find.byTooltip('About independent years'));
      await tester.tap(find.byTooltip('About independent years'));
      await pumpUntilFound(tester, find.byType(AlertDialog));

      expect(find.text('Independent years'), findsOneWidget);
      expect(find.text('How BeneFit counts'), findsOneWidget);
      expect(find.textContaining('range 1.0–2.6 / 0.7–2.4'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump(); // start the exit transition
      await tester.pump(const Duration(seconds: 1)); // and let it finish
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows the EARNED SO FAR bar with total savings', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      // 50ms seam: the in-flight benefit fetch reads this before resolving.
      h.benefitRepo.mockTotalSavings = 12.5;

      await openProgress(tester);

      await pumpUntilFound(tester, find.text('12.50 €'));
      expect(find.text('EARNED SO FAR'), findsOneWidget);
    });
  });
}
