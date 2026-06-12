import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/community/community_screen.dart';

import '../../helpers/app_harness.dart';

void main() {
  group('Community screen', () {
    testWidgets('opens from the Community tab and renders its sections', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(MainNavigationScreen));

      // Only the bottom-nav label exists yet (branch is lazy); tap it.
      await tester.tap(find.text('Community'));
      await pumpUntilFound(tester, find.byType(CommunityScreen));

      // Header banner (unique string; 'Community' also appears in nav + appbar).
      expect(find.text('Community – Coming Soon'), findsOneWidget);

      // Section headers are upper-cased by _SectionHeader.
      expect(find.text('CHALLENGES'), findsOneWidget);
      expect(find.text('EVENTS'), findsOneWidget);
      expect(find.text('COMMUNITIES'), findsOneWidget);

      // Static content across the three sections.
      expect(find.text('YOUR MONTHLY 50 KM'), findsOneWidget);
      expect(find.text('JULI 10K'), findsOneWidget);
      expect(find.text('Running Beginners'), findsOneWidget);
    });
  });
}
