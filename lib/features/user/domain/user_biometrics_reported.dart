/// Represents self-reported biometric data for a user
///
/// Users can report height, weight, and other physical metrics
/// Multiple entries can exist for tracking changes over time
class UserBiometricsReported {
  final String id;
  final String userId;
  final DateTime reportDate;
  final int? heightCm;
  final double? weightKg;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserBiometricsReported({
    required this.id,
    required this.userId,
    required this.reportDate,
    this.heightCm,
    this.weightKg,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON (from API response)
  factory UserBiometricsReported.fromJson(Map<String, dynamic> json) {
    return UserBiometricsReported(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      reportDate: DateTime.fromMillisecondsSinceEpoch(json['report_date'] as int),
      heightCm: json['height_cm'] as int?,
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  /// Convert to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'report_date': reportDate.millisecondsSinceEpoch,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with modified fields
  UserBiometricsReported copyWith({
    String? id,
    String? userId,
    DateTime? reportDate,
    int? heightCm,
    double? weightKg,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserBiometricsReported(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      reportDate: reportDate ?? this.reportDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'UserBiometricsReported(id: $id, userId: $userId, heightCm: $heightCm, weightKg: $weightKg, reportDate: $reportDate)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserBiometricsReported && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
