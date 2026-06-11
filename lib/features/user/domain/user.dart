/// Represents a user in the BeneFit app
class User {
  final String id;
  final String name;
  final String email;
  final String passwordHash;

  // Profile fields (v3)
  final String? displayName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? timezone;

  final String? profileImagePath;
  final bool isVerified;
  final String verificationStatus;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    this.displayName,
    this.gender,
    this.dateOfBirth,
    this.timezone,
    this.profileImagePath,
    this.isVerified = false,
    this.verificationStatus = 'unverified',
  });

  /// Create User from JSON (from API response)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      passwordHash: json['password_hash'] as String,
      displayName: json['display_name'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['date_of_birth'] as int)
          : null,
      timezone: json['timezone'] as String?,
      profileImagePath: json['profile_image_path'] as String?,
      isVerified: (json['is_verified'] ?? 0) == 1,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
    );
  }

  /// Convert User to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password_hash': passwordHash,
      if (displayName != null) 'display_name': displayName,
      if (gender != null) 'gender': gender,
      if (dateOfBirth != null)
        'date_of_birth': dateOfBirth!.millisecondsSinceEpoch,
      if (timezone != null) 'timezone': timezone,
      if (profileImagePath != null) 'profile_image_path': profileImagePath,
      'is_verified': isVerified ? 1 : 0,
      'verification_status': verificationStatus,
    };
  }

  /// Create a copy with modified fields
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? passwordHash,
    String? displayName,
    String? gender,
    DateTime? dateOfBirth,
    String? timezone,
    String? profileImagePath,
    bool? isVerified,
    String? verificationStatus,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      timezone: timezone ?? this.timezone,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  @override
  String toString() =>
      'User(id: $id, name: $name, email: $email, displayName: $displayName, gender: $gender)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
