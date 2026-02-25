import 'package:flutter/material.dart';
import 'package:benefitflutter/features/benefit/domain/benefit_view_model.dart';
import 'package:benefitflutter/presentation/screens/benefit/widgets/benefit_card.dart';

/// List of earned benefits
/// Renders each benefit using BenefitCard
class BenefitList extends StatelessWidget {
  final List<BenefitViewModel> benefits;
  final Function(BenefitViewModel)? onBenefitTap;
  final Function(BenefitViewModel)? onRedeem;

  const BenefitList({
    super.key,
    required this.benefits,
    this.onBenefitTap,
    this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: benefits.length,
      itemBuilder: (context, index) {
        final benefitVM = benefits[index];
        return BenefitCard(
          benefitVM: benefitVM,
          onTap: onBenefitTap != null
              ? () => onBenefitTap!(benefitVM)
              : null,
          onRedeem: onRedeem != null
              ? () => onRedeem!(benefitVM)
              : null,
        );
      },
    );
  }
}
