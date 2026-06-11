/// Represents user preferences and settings
///
/// One-to-one relationship with User
/// Stores location, units, theme, language, and other app preferences
class UserPreferences {
  final String id;
  final String userId;
  final String? defaultLocationCity;
  final String distanceUnit; // 'metric' or 'imperial'
  final String temperatureUnit; // 'celsius' or 'fahrenheit'
  final String weightUnit; // 'kg' or 'lbs'
  final String theme; // 'light', 'dark', or 'system'
  final String language; // ISO 639-1 code (e.g., 'en', 'de')
  final String? timezone; // IANA timezone (e.g., 'Europe/Vienna')
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPreferences({
    required this.id,
    required this.userId,
    this.defaultLocationCity,
    this.distanceUnit = 'metric',
    this.temperatureUnit = 'celsius',
    this.weightUnit = 'kg',
    this.theme = 'system',
    this.language = 'en',
    this.timezone,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON (from API response)
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      defaultLocationCity: json['default_location_city'] as String?,
      distanceUnit: json['distance_unit'] as String? ?? 'metric',
      temperatureUnit: json['temperature_unit'] as String? ?? 'celsius',
      weightUnit: json['weight_unit'] as String? ?? 'kg',
      theme: json['theme'] as String? ?? 'system',
      language: json['language'] as String? ?? 'en',
      timezone: json['timezone'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  /// Convert to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (defaultLocationCity != null)
        'default_location_city': defaultLocationCity,
      'distance_unit': distanceUnit,
      'temperature_unit': temperatureUnit,
      'weight_unit': weightUnit,
      'theme': theme,
      'language': language,
      if (timezone != null) 'timezone': timezone,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with modified fields
  UserPreferences copyWith({
    String? id,
    String? userId,
    String? defaultLocationCity,
    String? distanceUnit,
    String? temperatureUnit,
    String? weightUnit,
    String? theme,
    String? language,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      defaultLocationCity: defaultLocationCity ?? this.defaultLocationCity,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      weightUnit: weightUnit ?? this.weightUnit,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'UserPreferences(id: $id, userId: $userId, city: $defaultLocationCity, units: $distanceUnit/$weightUnit)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferences && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
