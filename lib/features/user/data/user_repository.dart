import '../domain/user.dart';
import '../domain/user_biometrics_reported.dart';
import '../domain/user_preferences.dart';

/// Repository interface for user data operations
abstract class UserRepository {
  /// Get user by ID
  Future<User> getUserById(String userId);

  /// Get user by email (case-insensitive), or null if no such user.
  ///
  /// Returns null (rather than throwing like [getUserById]) so authentication
  /// can surface a clean "no account" result.
  Future<User?> getUserByEmail(String email);

  /// Get current logged-in user (for MVP, returns hardcoded test user)
  Future<User> getCurrentUser();

  /// Update user profile
  Future<void> updateUser(User user);

  /// Create a new user
  Future<User> createUser(User user);

  /// Delete current user and all related data
  Future<void> deleteCurrentUser();

  // ========================================
  // BIOMETRICS (v3)
  // ========================================

  /// Get latest biometrics for a user
  Future<UserBiometricsReported?> getLatestBiometrics(String userId);

  /// Get all biometrics history for a user
  Future<List<UserBiometricsReported>> getBiometricsHistory(String userId);

  /// Save or update biometrics entry
  Future<void> saveBiometrics(UserBiometricsReported biometrics);

  // ========================================
  // PREFERENCES (v3)
  // ========================================

  /// Get preferences for a user (one-to-one)
  Future<UserPreferences?> getPreferences(String userId);

  /// Save or update preferences
  Future<void> savePreferences(UserPreferences preferences);
}
