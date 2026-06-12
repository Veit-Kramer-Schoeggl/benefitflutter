import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:benefitflutter/features/benefit/domain/benefit_partner.dart';
import 'package:benefitflutter/features/benefit/domain/benefit_view_model.dart';
import 'package:benefitflutter/features/benefit/domain/user_benefit.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/benefit/benefit_qr_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/mock_data.dart';

BenefitViewModel redeemedVm({
  String code = 'BF55555',
  String benefitId = 'benefit-1',
}) {
  return BenefitViewModel(
    userBenefit: UserBenefit(
      id: 'ub-redeemed',
      userId: harnessUserId,
      benefitId: benefitId,
      sessionId: 'session-1',
      status: BenefitStatus.redeemed,
      redemptionCode: code,
    ),
    benefit: MockData.createBenefit(
      id: benefitId,
      title: 'QR Benefit',
      discountAmount: 5.0,
    ),
  );
}

void main() {
  group('Benefit QR screen', () {
    testWidgets('renders QR code, redemption code, title and amount', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(MainNavigationScreen));

      h.router.go('/benefit-qr', extra: redeemedVm());
      await pumpUntilFound(tester, find.byType(BenefitQrScreen));

      expect(find.text('QR Benefit'), findsOneWidget);
      expect(find.text('€5.00'), findsOneWidget);
      // The redemption code is shown as text and encoded into the QR (same
      // source variable); qr_flutter keeps `data` private so we assert both
      // the visible code and the presence of the QR widget.
      expect(find.text('BF55555'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('shows seeded partner locations', (tester) async {
      final h = await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(MainNavigationScreen));

      // getPartnersForBenefit has no delay → seed before navigating.
      h.benefitRepo.mockPartners = [
        BenefitPartner(
          id: 'p1',
          benefitId: 'benefit-1',
          name: 'FitShop',
          city: 'Berlin',
          address: 'Main St 1',
        ),
      ];

      h.router.go('/benefit-qr', extra: redeemedVm());
      await pumpUntilFound(tester, find.byType(BenefitQrScreen));
      await pumpUntilFound(tester, find.textContaining('FitShop'));
      expect(find.textContaining('FitShop'), findsOneWidget);
    });

    testWidgets('null view model shows the fallback', (tester) async {
      final h = await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(MainNavigationScreen));

      h.router.go('/benefit-qr'); // no extra → BenefitViewModel is null
      await pumpUntilFound(tester, find.byType(BenefitQrScreen));

      expect(find.text('Back to Benefits'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });
  });
}
