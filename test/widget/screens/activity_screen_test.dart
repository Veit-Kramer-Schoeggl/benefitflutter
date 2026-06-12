import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/presentation/screens/activity/activity_screen.dart';
import 'package:benefitflutter/presentation/screens/wearable/widgets/heart_rate_display.dart';

import '../../helpers/app_harness.dart';

void main() {
  group('Activity screen', () {
    testWidgets('idle state renders the default content', (tester) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(ActivityScreen));

      expect(find.text('START Running'), findsOneWidget);
      expect(find.text('Ready to start recording'), findsOneWidget);
      expect(find.text('0.0 KM'), findsOneWidget);
      expect(find.text('New running session!'), findsOneWidget);
      expect(find.text('EARNED SO FAR'), findsOneWidget);
      expect(find.byType(HeartRateDisplayCompact), findsOneWidget);
    });

    testWidgets('lifecycle: start → pause → long-press stop → idle', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.text('START Running'));

      // idle → tracking (starts a real periodic timer)
      await tester.tap(find.text('START Running'));
      await pumpUntilFound(tester, find.text('Pause'));
      expect(find.text('Recording running'), findsOneWidget);

      // tracking → paused (cancels the timer)
      await tester.tap(find.text('Pause'));
      await pumpUntilFound(tester, find.text('Continue / Stop'));
      expect(find.text('Recording paused'), findsOneWidget);

      // paused → idle via long-press (stopSession); ending idle leaves no
      // pending timer.
      await tester.longPress(find.text('Continue / Stop'));
      await pumpUntilFound(tester, find.text('START Running'));
      expect(find.text('Ready to start recording'), findsOneWidget);
    });

    testWidgets('connectivity indicator flips to offline', (tester) async {
      final h = await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(ActivityScreen));

      // Default is online.
      expect(find.byIcon(Icons.signal_cellular_alt), findsOneWidget);

      h.connectivity.setOnline(false);
      await pumpUntilFound(
        tester,
        find.byIcon(Icons.signal_cellular_connected_no_internet_0_bar),
      );
    });

    testWidgets('shows the EARNED SO FAR bar with total savings', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      // 50ms seam: the in-flight benefit fetch reads this before resolving.
      h.benefitRepo.mockTotalSavings = 12.5;

      await pumpUntilFound(tester, find.text('12.50 €'));
      expect(find.text('EARNED SO FAR'), findsOneWidget);
    });
  });
}
