import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:benefitflutter/main.dart' as app;
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/auth/login_screen.dart';
import 'package:benefitflutter/presentation/screens/activity/activity_screen.dart';
import 'package:benefitflutter/presentation/screens/community/community_screen.dart';
import 'package:benefitflutter/presentation/screens/progress/progress_screen.dart';
import 'package:benefitflutter/presentation/screens/benefit/benefit_screen.dart';
import 'package:benefitflutter/presentation/screens/profile/profile_screen.dart';

/// Pumps in fixed steps until [finder] matches or [timeout] elapses. We never
/// use pumpAndSettle here: the splash spinner / activity timer never settle.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets); // fail with a useful message if not found
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('happy path: cold start → login → home tabs', (tester) async {
    // Boot the REAL app (real SQLite, providers, router). bootstrap() avoids
    // main()'s runZonedGuarded so runApp shares the test binding's zone.
    await app.bootstrap();

    // Fresh install → splash → login (no restored session).
    await pumpUntil(tester, find.byType(LoginScreen));

    // Log in with the seeded developer account.
    await tester.enterText(find.byType(TextFormField).at(0), 'test@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('Sign In'));

    // Redirect /login → /home/activity.
    await pumpUntil(tester, find.byType(MainNavigationScreen));
    await pumpUntil(tester, find.byType(ActivityScreen));

    // Walk the bottom-nav tabs (avoid Session Detail — its map fetches OSM tiles).
    await tester.tap(find.text('Progress'));
    await pumpUntil(tester, find.byType(ProgressScreen));

    await tester.tap(find.text('Community'));
    await pumpUntil(tester, find.byType(CommunityScreen));

    await tester.tap(find.text('Benefit'));
    await pumpUntil(tester, find.byType(BenefitScreen));

    await tester.tap(find.text('Profile'));
    await pumpUntil(tester, find.byType(ProfileScreen));

    await tester.tap(find.text('Activity'));
    await pumpUntil(tester, find.byType(ActivityScreen));
  });
}
