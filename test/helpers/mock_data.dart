import 'package:benefitflutter/features/benefit/domain/benefit.dart';
import 'package:benefitflutter/features/benefit/domain/user_benefit.dart';

/// Test data factory for creating mock benefits and user benefits
class MockData {
  /// Sample Benefit instances for testing
  static Benefit createBenefit({
    String id = 'benefit-1',
    String title = 'Test Benefit',
    String description = 'Test Description',
    double discountAmount = 10.0,
    int? requiredDistance,
    int? requiredSessions,
    DateTime? createdAt,
  }) {
    return Benefit(
      id: id,
      title: title,
      description: description,
      discountAmount: discountAmount,
      requiredDistance: requiredDistance,
      requiredSessions: requiredSessions,
      createdAt: createdAt ?? DateTime(2024, 1, 1),
    );
  }

  /// Sample UserBenefit instances for testing
  static UserBenefit createUserBenefit({
    String id = 'user-benefit-1',
    String userId = 'user-123',
    String benefitId = 'benefit-1',
    String sessionId = 'session-1',
    DateTime? earnedAt,
  }) {
    return UserBenefit(
      id: id,
      userId: userId,
      benefitId: benefitId,
      sessionId: sessionId,
      earnedAt: earnedAt ?? DateTime(2024, 1, 1),
    );
  }

  /// Create a list of sample benefits
  static List<Benefit> sampleBenefits() {
    return [
      createBenefit(
        id: 'benefit-1',
        title: '5 Euro Discount',
        description: 'Earn €5 for 10km of cycling',
        discountAmount: 5.0,
        requiredDistance: 10000,
      ),
      createBenefit(
        id: 'benefit-2',
        title: '10 Euro Discount',
        description: 'Complete 5 active sessions',
        discountAmount: 10.0,
        requiredSessions: 5,
      ),
      createBenefit(
        id: 'benefit-3',
        title: '20 Euro Discount',
        description: 'Reach 50km total distance',
        discountAmount: 20.0,
        requiredDistance: 50000,
      ),
    ];
  }

  /// Create a list of sample user benefits
  static List<UserBenefit> sampleUserBenefits({String userId = 'user-123'}) {
    return [
      createUserBenefit(
        id: 'ub-1',
        userId: userId,
        benefitId: 'benefit-1',
        sessionId: 'session-1',
        earnedAt: DateTime(2024, 1, 15),
      ),
      createUserBenefit(
        id: 'ub-2',
        userId: userId,
        benefitId: 'benefit-2',
        sessionId: 'session-2',
        earnedAt: DateTime(2024, 2, 1),
      ),
    ];
  }
}
