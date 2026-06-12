import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/progress/progress_screen.dart';
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
