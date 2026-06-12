import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/presentation/screens/auth/forgot_password_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/login_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/reset_password_screen.dart';

import '../../helpers/app_harness.dart';

void main() {
  group('Forgot + reset password', () {
    testWidgets('full flow: forgot → reset → login', (tester) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      // Enter the forgot screen via the router (the login "Forgot Password?"
      // link is right-aligned/off-screen at the test viewport).
      h.router.go('/forgot-password');
      await pumpUntilFound(tester, find.byType(ForgotPasswordScreen));

      await tester.enterText(
        find.descendant(
          of: find.byType(ForgotPasswordScreen),
          matching: find.byType(TextFormField),
        ),
        'bob@example.com',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Code'));

      // Dialog → continue to reset.
      await pumpUntilFound(tester, find.text('Continue to Reset'));
      await tester.tap(find.text('Continue to Reset'));

      // Reset screen (reached via go → fresh stack; pendingResetCode is set).
      await pumpUntilFound(tester, find.byType(ResetPasswordScreen));
      await tester.enterText(
        find.widgetWithText(TextField, 'Reset Code'),
        h.auth.pendingResetCode!,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'New Password'),
        'NewPass123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm Password'),
        'NewPass123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Reset Password'));

      // Success dialog → Sign In (scope to the dialog) → login.
      await pumpUntilFound(tester, find.byType(AlertDialog));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Sign In'),
        ),
      );

      await pumpUntilFound(tester, find.byType(LoginScreen));
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('forgot screen renders email + button', (tester) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      h.router.go('/forgot-password');
      await pumpUntilFound(tester, find.byType(ForgotPasswordScreen));

      expect(
        find.descendant(
          of: find.byType(ForgotPasswordScreen),
          matching: find.byType(TextFormField),
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Send Reset Code'),
        findsOneWidget,
      );
    });

    testWidgets('reset guard: no pending reset/token → /forgot-password', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      h.router.go('/reset-password');
      await pumpUntilFound(tester, find.byType(ForgotPasswordScreen));
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('deep-link token via extra pre-fills the code', (tester) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      h.router.go('/reset-password', extra: 'TOKEN123');
      await pumpUntilFound(tester, find.byType(ResetPasswordScreen));

      expect(find.text('TOKEN123'), findsOneWidget); // code field pre-filled
    });

    testWidgets('deep-link token via ?token= pre-fills the code', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      h.router.go('/reset-password?token=TOKEN123');
      await pumpUntilFound(tester, find.byType(ResetPasswordScreen));

      expect(find.text('TOKEN123'), findsOneWidget);
    });

    testWidgets('service failure keeps the user on reset', (tester) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      // Establish a pending reset (so resetPassword reaches the service), then
      // make the service fail.
      await h.auth.requestPasswordReset('bob@example.com');
      h.router.go('/reset-password');
      await pumpUntilFound(tester, find.byType(ResetPasswordScreen));
      h.authService.resetSucceeds = false;

      await tester.enterText(
        find.widgetWithText(TextField, 'Reset Code'),
        h.auth.pendingResetCode!,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'New Password'),
        'NewPass123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm Password'),
        'NewPass123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Reset Password'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing); // no success dialog
    });

    testWidgets('client validation: mismatched confirm blocks reset', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: false);
      await pumpUntilFound(tester, find.byType(LoginScreen));

      h.router.go('/reset-password', extra: 'CODE99');
      await pumpUntilFound(tester, find.byType(ResetPasswordScreen));

      await tester.enterText(
        find.widgetWithText(TextField, 'New Password'),
        'NewPass123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm Password'),
        'Different1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Reset Password'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
