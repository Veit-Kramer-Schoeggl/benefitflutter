import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/auth/widgets/password_text_field.dart';
import 'package:benefitflutter/features/auth/widgets/verification_code_field.dart';
import 'package:benefitflutter/features/security/services/biometric_service.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/auth/login_screen.dart';
import 'package:benefitflutter/presentation/screens/profile/profile_screen.dart';

import '../../helpers/app_harness.dart';

Future<void> openProfile(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byType(MainNavigationScreen));
  await tester.tap(find.text('Profile')); // only the nav label exists yet
  await pumpUntilFound(tester, find.byType(ProfileScreen));
  // Wait for initState's async load to render the content.
  await pumpUntilFound(tester, find.text('Gender'));
}

/// Enter text into the inner TextField of a custom field wrapper at [index].
Future<void> enterInto(
  WidgetTester tester,
  Type wrapper,
  int index,
  String text,
) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(wrapper).at(index),
      matching: find.byType(TextField),
    ),
    text,
  );
}

void main() {
  group('Profile screen', () {
    testWidgets('renders the profile sections', (tester) async {
      await pumpApp(tester, authenticated: true);
      await openProfile(tester);

      expect(find.text('Not Verified'), findsOneWidget);
      for (final label in const [
        'Gender',
        'Height',
        'Weight',
        'Connected Devices',
        'Verify Identity',
        'Change Password',
        'Delete Account',
        'Save Changes',
        'Sign Out',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'missing: $label');
      }
    });

    testWidgets('biometric card is hidden when unavailable', (tester) async {
      await pumpApp(tester, authenticated: true); // biometricAvailable=false
      await openProfile(tester);

      expect(find.textContaining('Unlock with'), findsNothing);
    });

    testWidgets('biometric card shows and the toggle enables app lock', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      // Set knobs BEFORE the lazy Profile tab builds (initState reads them once).
      h.biometric
        ..biometricAvailable = true
        ..primaryType = AppBiometricType.fingerprint;

      await openProfile(tester);

      expect(find.text('Unlock with Fingerprint'), findsOneWidget);

      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await pumpUntilFound(
        tester,
        find.text('App will lock after 2 minutes in background'),
      );
    });

    testWidgets('gender selection sheet updates the card', (tester) async {
      await pumpApp(tester, authenticated: true);
      await openProfile(tester);

      expect(find.text('Select gender'), findsOneWidget); // initial card value
      await tester.tap(find.text('Gender'));
      // Let the modal bottom sheet finish animating up (Profile has no infinite
      // animations, so pumpAndSettle is safe and avoids tapping mid-animation).
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle(); // sheet closes; card value updates

      expect(find.text('Female'), findsOneWidget); // now the card value
      expect(find.text('Select gender'), findsNothing); // selection took effect
    });

    testWidgets('settings dialog opens with the editable fields', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: true);
      await openProfile(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await pumpUntilFound(tester, find.text('Edit Profile Settings'));
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await pumpUntilFound(tester, find.byType(ProfileScreen));
      expect(find.text('Edit Profile Settings'), findsNothing);
    });

    testWidgets('change password dialog rejects an incorrect current password', (
      tester,
    ) async {
      // The dialog verifies the current password client-side against the
      // stored hash (PasswordUtils.verifyPassword). The harness user's hash is
      // a fixed fixture, so any entered current password is "incorrect" — which
      // exercises the dialog's validation + error wiring. (The success path is
      // covered by the AuthProvider unit test.)
      await pumpApp(tester, authenticated: true);
      await openProfile(tester);

      await tester.tap(find.text('Change Password'));
      await pumpUntilFound(tester, find.text('Current Password'));

      await enterInto(tester, PasswordTextField, 0, 'WrongPass1');
      await enterInto(tester, PasswordTextField, 1, 'NewPass123');
      await enterInto(tester, PasswordTextField, 2, 'NewPass123');

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Save'),
        ),
      );
      await pumpUntilFound(tester, find.text('Current password is incorrect'));
      expect(
        find.text('Current Password'),
        findsOneWidget,
      ); // dialog stays open
    });

    testWidgets('delete account two-step flow signs the user out', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      h.authService
        ..deletionRequestSucceeds = true
        ..deletionRequestCode = '111222'
        ..deletionConfirmSucceeds = true;
      await openProfile(tester);

      await tester.ensureVisible(find.text('Delete Account'));
      await tester.tap(find.text('Delete Account'));
      await pumpUntilFound(tester, find.text('Delete Your Account?'));

      await tester.tap(
        find.widgetWithText(FilledButton, 'Send Verification Code'),
      );
      await pumpUntilFound(tester, find.text('Verify Deletion'));

      await enterInto(tester, VerificationCodeField, 0, '111222');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete My Account'));

      await pumpUntilFound(tester, find.byType(LoginScreen));
    });

    testWidgets('sign out confirms and returns to login', (tester) async {
      await pumpApp(tester, authenticated: true);
      await openProfile(tester);

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Sign Out'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await pumpUntilFound(tester, find.text('Sign Out?'));

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Sign Out'),
        ),
      );
      await pumpUntilFound(tester, find.byType(LoginScreen));
    });
  });
}
