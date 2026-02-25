import 'package:benefitflutter/features/benefit/domain/benefit.dart';
import 'package:benefitflutter/features/benefit/domain/user_benefit.dart';

/// ViewModel that combines UserBenefit + Benefit metadata
/// This joins data from two sources for easier UI consumption
class BenefitViewModel {
  final UserBenefit userBenefit;
  final Benefit benefit;

  BenefitViewModel({
    required this.userBenefit,
    required this.benefit,
  });

  // Convenient getters for UI
  String get id => userBenefit.id;
  String get title => benefit.title;
  String get description => benefit.description;
  String get formattedAmount => benefit.formattedDiscount;
  DateTime get earnedAt => userBenefit.earnedAt;
  String get sessionId => userBenefit.sessionId;
  /// Whether this benefit has been redeemed
  bool get isRedeemed =>
      userBenefit.status == BenefitStatus.redeemed;
  /// Whether this benefit is still available to redeem
  bool get isEarned =>
      userBenefit.status == BenefitStatus.earned;
  /// Redeemed date (if applicable)
  DateTime? get redeemedAt => userBenefit.redeemedAt;

  /// Format earned date as human-readable string
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(earnedAt);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    // Format as DD.MM.YYYY
    return '${earnedAt.day.toString().padLeft(2, '0')}.${earnedAt.month.toString().padLeft(2, '0')}.${earnedAt.year}';
  }

  @override
  String toString() =>
      'BenefitViewModel(title: $title, amount: $formattedAmount, earned: $formattedDate)';
}
