import '../domain/benefit.dart';
import '../domain/user_benefit.dart';
import '../domain/benefit_partner.dart';

/// Repository interface for benefit data operations
abstract class BenefitRepository {
  /// Get all available benefits
  Future<List<Benefit>> getAllBenefits();

  /// Get benefits earned by a user
  Future<List<UserBenefit>> getUserBenefits({required String userId});

  /// Get partners for benefits
  Future<List<BenefitPartner>> getPartnersForBenefit(String benefitId);

  /// Redeem a user benefit
  Future<void> redeemBenefit({
    required String userBenefitId,
    required String redemptionCode,
  });

  /// Award a benefit to a user for a session
  Future<UserBenefit> awardBenefit({
    required String userId,
    required String benefitId,
    required String sessionId,
  });

  /// Calculate total discount earned by user
  Future<double> getTotalDiscountEarned({required String userId});
}