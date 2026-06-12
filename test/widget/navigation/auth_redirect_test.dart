import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/auth/login_screen.dart';

import '../../helpers/app_harness.dart';

void main() {
  group('go_router auth redirect', () {
    testWidgets('cold start, unauthenticated → /login (no home flash)', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainNavigationScreen), findsNothing);
    });

    testWidgets('cold start, authenticated → /home/activity', (tester) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(MainNavigationScreen));

      expect(find.byType(MainNavigationScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('logout from authed state → redirected to /login', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(MainNavigationScreen));

      await h.auth.logout(); // refreshListenable → redirect re-runs
      await pumpUntilFound(tester, find.byType(LoginScreen));
      // Let the outgoing route finish its transition before asserting removal.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainNavigationScreen), findsNothing);
    });
  });
}
