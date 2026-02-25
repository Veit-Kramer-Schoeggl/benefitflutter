/// Types of physical activities
enum ActivityType {
  running,
  walking,
  cycling,
  swimming,
  strengthTraining,
  yoga,
  hiking,
  trailRunning,
  dancing,
  martialArts,
  teamSports,
  other;

  /// Convert to JSON string
  String toJson() => name;

  /// Create from JSON string
  static ActivityType fromJson(String value) {
    return ActivityType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActivityType.other,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case ActivityType.running:
        return 'Running';
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.cycling:
        return 'Cycling';
      case ActivityType.swimming:
        return 'Swimming';
      case ActivityType.strengthTraining:
        return 'Strength Training';
      case ActivityType.yoga:
        return 'Yoga';
      case ActivityType.hiking:
        return 'Hiking';
      case ActivityType.trailRunning:
        return 'Trail Running';
      case ActivityType.dancing:
        return 'Dancing';
      case ActivityType.martialArts:
        return 'Martial Arts';
      case ActivityType.teamSports:
        return 'Team Sports';
      case ActivityType.other:
        return 'Other';
    }
  }
}