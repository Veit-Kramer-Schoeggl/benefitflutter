import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/auth/login_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/auth_fakes.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders email, password and Sign In', (tester) async {
      await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('successful login navigates to home', (tester) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      // Seed the user so AuthProvider.login can load it after auth succeeds.
      h.userRepo.users[harnessUserId] = userFixture(id: harnessUserId);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@gmail.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '1234');
      await tester.tap(find.text('Sign In'));

      await pumpUntilFound(tester, find.byType(MainNavigationScreen));
      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });

    testWidgets('failed login stays on the login screen', (tester) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      h.authService.loginSucceeds = false;

      await tester.enterText(find.byType(TextFormField).at(0), 'x@y.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
      await tester.tap(find.text('Sign In'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainNavigationScreen), findsNothing);
    });
  });
}
