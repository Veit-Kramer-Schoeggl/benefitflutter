import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/auth/email_verification_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/login_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/register_screen.dart';

import '../../helpers/app_harness.dart';

void main() {
  group('Register + email verification', () {
    testWidgets('full flow: register → verify → home', (tester) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      // Login → Register.
      await tester.tap(find.text('Create Account'));
      await pumpUntilFound(tester, find.byType(RegisterScreen));

      // Fill the register form.
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(0),
        'Bob',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(1),
        'bob@example.com',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(2),
        'Password1',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(3),
        'Password1',
      );
      // Let the async email-availability check resolve.
      await tester.pump(const Duration(milliseconds: 600));

      // Submit → non-dismissible dialog with the mock code.
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await pumpUntilFound(tester, find.text('Continue to Verification'));
      await tester.tap(find.text('Continue to Verification'));

      // Verify screen → enter the (mock) code → home.
      await pumpUntilFound(tester, find.byType(EmailVerificationScreen));
      await tester.enterText(
        find.widgetWithText(TextField, 'Verification Code'),
        h.auth.pendingVerificationCode!,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Verify'));

      await pumpUntilFound(tester, find.byType(MainNavigationScreen));
      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });

    testWidgets('register screen renders the form', (tester) async {
      await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));
      await tester.tap(find.text('Create Account'));
      await pumpUntilFound(tester, find.byType(RegisterScreen));

      expect(
        find.descendant(
          of: find.byType(RegisterScreen),
          matching: find.byType(TextFormField),
        ),
        findsNWidgets(4),
      );
      expect(
        find.widgetWithText(FilledButton, 'Create Account'),
        findsOneWidget,
      );
    });

    testWidgets('service failure keeps the user on register', (tester) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));
      await tester.tap(find.text('Create Account'));
      await pumpUntilFound(tester, find.byType(RegisterScreen));

      h.authService.registerSucceeds = false;

      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(0),
        'Bob',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(1),
        'bob@example.com',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(2),
        'Password1',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(3),
        'Password1',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Continue to Verification'), findsNothing);
    });

    testWidgets('client validation: mismatched confirm blocks submit', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));
      await tester.tap(find.text('Create Account'));
      await pumpUntilFound(tester, find.byType(RegisterScreen));

      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(0),
        'Bob',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(1),
        'bob@example.com',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(2),
        'Password1',
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(TextFormField),
            )
            .at(3),
        'Different1',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump(const Duration(milliseconds: 300));

      // No code dialog, still on register (validation stopped the submit).
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Continue to Verification'), findsNothing);
    });

    testWidgets('verify guard: no pending registration → /register', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      h.router.go('/verify');
      await pumpUntilFound(tester, find.byType(RegisterScreen));

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });
}
