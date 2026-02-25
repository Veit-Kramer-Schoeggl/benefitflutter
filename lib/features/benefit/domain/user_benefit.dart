enum BenefitStatus {
  earned,
  redeemed,
}

/// Represents a benefit earned by a user
class UserBenefit {
  final String id;
  final String userId;
  final String benefitId;
  final String sessionId; // The session that earned this benefit
  final DateTime earnedAt;

  final BenefitStatus status;
  final DateTime? redeemedAt;
  final String? redemptionCode;

  UserBenefit({
    required this.id,
    required this.userId,
    required this.benefitId,
    required this.sessionId,
    DateTime? earnedAt,
    this.status = BenefitStatus.earned,
    this.redeemedAt,
    this.redemptionCode,
  }) : earnedAt = earnedAt ?? DateTime.now();

  /// Create from JSON
  factory UserBenefit.fromJson(Map<String, dynamic> json) {
    return UserBenefit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      benefitId: json['benefit_id'] as String,
      sessionId: json['session_id'] as String,
      earnedAt: json['earned_at'] != null
          ? DateTime.parse(json['earned_at'] as String)
          : DateTime.now(),
      status: json['status'] == 'redeemed'
          ? BenefitStatus.redeemed
          : BenefitStatus.earned,
      redeemedAt: json['redeemed_at'] != null
          ? DateTime.parse(json['redeemed_at'] as String)
          : null,
      redemptionCode: json['redemption_code'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'benefit_id': benefitId,
      'session_id': sessionId,
      'earned_at': earnedAt.toIso8601String(),
      'status': status.name,
      'redeemed_at': redeemedAt?.toIso8601String(),
      'redemption_code': redemptionCode,
    };
  }

  @override
  String toString() => 'UserBenefit(id: $id, benefitId: $benefitId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserBenefit && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}