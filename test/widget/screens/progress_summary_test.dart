import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/presentation/screens/progress/widgets/progress_summary.dart';
import 'package:benefitflutter/providers/progress_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/session_fakes.dart';

/// The summary cards at phone width with a seed-sized history: the big
/// numbers stay on one line at the default text scale, and wrap instead of
/// shrinking when the user has enlarged the system font.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  Future<ProgressProvider> loadedProvider() async {
    // 480 one-hour sessions a year ago, so the Total card reads '480h 0m'.
    final start = DateTime.now().subtract(const Duration(days: 365));
    final repo = MockSessionRepository()
      ..seedSessions([
        for (var i = 0; i < 480; i++)
          Session(
            id: 'session-$i',
            userId: 'u1',
            trackingMode: TrackingMode.manual,
            activityType: ActivityType.running,
            status: SessionStatus.completed,
            startTime: start.add(Duration(hours: i)),
            endTime: start.add(Duration(hours: i + 1)),
            durationSeconds: 3600,
            distanceMeters: 10000,
          ),
      ]);
    final provider = ProgressProvider(repo)..updateUserId('u1');
    await provider.loadActivities();
    return provider;
  }

  Future<void> pumpSummary(
    WidgetTester tester,
    ProgressProvider provider, {
    required double textScale,
  }) async {
    // A 393-dp-wide phone, like the Xiaomi Mi 11i the seed was checked on.
    tester.view.physicalSize = const Size(393 * 3, 851 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: ProgressSummary(provider: provider)),
      ),
    );
  }

  Finder fittedTotal() =>
      find.ancestor(of: find.text('480h 0m'), matching: find.byType(FittedBox));

  testWidgets('a long total stays on one line at the default text scale', (
    tester,
  ) async {
    final provider = await tester.runAsync(loadedProvider);
    await pumpSummary(tester, provider!, textScale: 1);

    expect(find.text('480h 0m'), findsOneWidget);
    expect(find.text('480 sessions'), findsOneWidget);
    expect(fittedTotal(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with a large system font the value wraps instead of shrinking', (
    tester,
  ) async {
    final provider = await tester.runAsync(loadedProvider);
    await pumpSummary(tester, provider!, textScale: 1.3);

    expect(find.text('480h 0m'), findsOneWidget);
    expect(fittedTotal(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
