import 'package:benefitflutter/features/benefit/data/benefit_repository.dart';
import 'package:benefitflutter/features/benefit/domain/benefit.dart';
import 'package:benefitflutter/features/benefit/domain/benefit_partner.dart';
import 'package:benefitflutter/features/benefit/domain/user_benefit.dart';

import 'mock_data.dart';

/// In-memory [BenefitRepository] for tests. Configure [mockBenefits] /
/// [mockUserBenefits] / [mockTotalSavings]; flip [shouldThrowError] for error paths.
class MockBenefitRepositoryForTest implements BenefitRepository {
  List<Benefit> mockBenefits = [];
  List<UserBenefit> mockUserBenefits = [];
  List<BenefitPartner> mockPartners = [];
  double mockTotalSavings = 0.0;
  bool shouldThrowError = false;
  String errorMessage = 'Test error';

  @override
  Future<List<Benefit>> getAllBenefits() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldThrowError) throw Exception(errorMessage);
    return mockBenefits;
  }

  @override
  Future<List<UserBenefit>> getUserBenefits({required String userId}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldThrowError) throw Exception(errorMessage);
    return mockUserBenefits;
  }

  @override
  Future<double> getTotalDiscountEarned({required String userId}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldThrowError) throw Exception(errorMessage);
    return mockTotalSavings;
  }

  @override
  Future<UserBenefit> awardBenefit({
    required String userId,
    required String benefitId,
    required String sessionId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldThrowError) throw Exception(errorMessage);
    final userBenefit = MockData.createUserBenefit(
      userId: userId,
      benefitId: benefitId,
      sessionId: sessionId,
    );
    mockUserBenefits.add(userBenefit);
    return userBenefit;
  }

  @override
  Future<List<BenefitPartner>> getPartnersForBenefit(String benefitId) async {
    if (shouldThrowError) throw Exception(errorMessage);
    return mockPartners;
  }

  @override
  Future<void> redeemBenefit({
    required String userBenefitId,
    required String redemptionCode,
  }) async {
    if (shouldThrowError) throw Exception(errorMessage);
  }
}
