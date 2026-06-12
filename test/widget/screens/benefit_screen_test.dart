import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/benefit/domain/user_benefit.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/benefit/benefit_qr_screen.dart';
import 'package:benefitflutter/presentation/screens/benefit/widgets/benefit_card.dart';
import 'package:benefitflutter/presentation/screens/benefit/widgets/empty_benefits_widget.dart';
import 'package:benefitflutter/presentation/screens/benefit/widgets/total_savings_card.dart';
import 'package:benefitflutter/presentation/shared/widgets/error_display_widget.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/mock_data.dart';

Future<void> openBenefitTab(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byType(MainNavigationScreen));
  // Only the bottom-nav label exists before the branch is built.
  await tester.tap(find.text('Benefit'));
}

void main() {
  group('Benefit screen', () {
    testWidgets('empty state when no benefits are earned', (tester) async {
      await pumpApp(tester, authenticated: true);
      // No seed → the auto-fetch (kicked off in pumpApp) resolves to empty.
      await openBenefitTab(tester);

      await pumpUntilFound(tester, find.byType(EmptyBenefitsWidget));
      expect(find.text('No Benefits Yet'), findsOneWidget);
    });

    testWidgets('success state shows savings + earned benefit cards', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      // Seed BEFORE pumping past the fakes' 50ms delay: the in-flight
      // fetchBenefits() reads these fields when its delayed futures resolve.
      h.benefitRepo
        ..mockUserBenefits = MockData.sampleUserBenefits(userId: harnessUserId)
        ..mockBenefits = MockData.sampleBenefits()
        ..mockTotalSavings = 15.0;

      await openBenefitTab(tester);
      await pumpUntilFound(tester, find.byType(TotalSavingsCard));

      expect(find.text('€15.00'), findsOneWidget);
      expect(find.text('Earned BeneFits'), findsOneWidget);
      expect(find.byType(BenefitCard), findsNWidgets(2));
      expect(find.text('5 Euro Discount'), findsOneWidget);
      expect(find.text('10 Euro Discount'), findsOneWidget);
    });

    testWidgets('error state shows the error widget', (tester) async {
      final h = await pumpApp(tester, authenticated: true);
      h.benefitRepo.shouldThrowError = true;

      await openBenefitTab(tester);
      await pumpUntilFound(tester, find.byType(ErrorDisplayWidget));
    });

    testWidgets('tapping a redeemed benefit opens the QR screen', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      h.benefitRepo
        ..mockUserBenefits = [
          UserBenefit(
            id: 'ub-redeemed',
            userId: harnessUserId,
            benefitId: 'benefit-1',
            sessionId: 'session-1',
            status: BenefitStatus.redeemed,
            redemptionCode: 'BF55555',
          ),
        ]
        ..mockBenefits = MockData.sampleBenefits()
        ..mockTotalSavings = 5.0;

      await openBenefitTab(tester);
      await pumpUntilFound(tester, find.byType(BenefitCard));

      // Redeemed cards expose a QR icon button wired to context.push('/benefit-qr').
      await tester.tap(find.byIcon(Icons.qr_code));
      await pumpUntilFound(tester, find.byType(BenefitQrScreen));
      expect(find.text('BF55555'), findsOneWidget);
    });
  });
}
