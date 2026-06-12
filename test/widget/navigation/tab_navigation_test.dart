import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/activity/activity_screen.dart';
import 'package:benefitflutter/presentation/screens/progress/progress_screen.dart';
import 'package:benefitflutter/presentation/screens/profile/profile_screen.dart';

import '../../helpers/app_harness.dart';

void main() {
  group('StatefulShellRoute tabs', () {
    testWidgets('opens on the Activity branch by default', (tester) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(MainNavigationScreen));

      expect(find.byType(ActivityScreen), findsOneWidget);
      // Other branches are lazy — not built until first visited.
      expect(find.byType(ProgressScreen), findsNothing);
    });

    testWidgets('tapping a tab switches the branch', (tester) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(MainNavigationScreen));

      await tester.tap(find.text('Progress'));
      await pumpUntilFound(tester, find.byType(ProgressScreen));
      expect(find.byType(ProgressScreen), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await pumpUntilFound(tester, find.byType(ProfileScreen));
      expect(find.byType(ProfileScreen), findsOneWidget);

      // Switching back keeps the Activity branch alive (state preserved).
      await tester.tap(find.text('Activity'));
      await pumpUntilFound(tester, find.byType(ActivityScreen));
      expect(find.byType(ActivityScreen), findsOneWidget);
    });
  });
}
