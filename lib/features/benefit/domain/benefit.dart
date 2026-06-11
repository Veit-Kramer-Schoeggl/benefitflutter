/// Represents a benefit/reward available in the app
class Benefit {
  final String id;
  final String title;
  final String description;
  final double discountAmount; // Amount in euros
  final int? requiredDistance; // Required distance in meters
  final int? requiredSessions; // Required session count
  final DateTime createdAt;

  Benefit({
    required this.id,
    required this.title,
    required this.description,
    required this.discountAmount,
    this.requiredDistance,
    this.requiredSessions,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from JSON
  factory Benefit.fromJson(Map<String, dynamic> json) {
    return Benefit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      discountAmount: (json['discount_amount'] as num).toDouble(),
      requiredDistance: json['required_distance'] as int?,
      requiredSessions: json['required_sessions'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'discount_amount': discountAmount,
      'required_distance': requiredDistance,
      'required_sessions': requiredSessions,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get formatted discount string (e.g., "€5.00")
  String get formattedDiscount {
    return '€${discountAmount.toStringAsFixed(2)}';
  }

  @override
  String toString() => 'Benefit(id: $id, title: $title)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Benefit && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
