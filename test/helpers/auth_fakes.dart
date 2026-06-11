import 'package:benefitflutter/features/auth/data/auth_service.dart';
import 'package:benefitflutter/features/auth/data/token_storage.dart';
import 'package:benefitflutter/features/auth/domain/account_deletion_request_result.dart';
import 'package:benefitflutter/features/auth/domain/account_deletion_result.dart';
import 'package:benefitflutter/features/auth/domain/auth_result.dart';
import 'package:benefitflutter/features/auth/domain/auth_tokens.dart';
import 'package:benefitflutter/features/auth/domain/password_reset_request_result.dart';
import 'package:benefitflutter/features/auth/domain/password_reset_result.dart';
import 'package:benefitflutter/features/auth/domain/registration_result.dart';
import 'package:benefitflutter/features/security/data/rate_limit_storage.dart';
import 'package:benefitflutter/features/security/services/rate_limiter_service.dart';
import 'package:benefitflutter/features/user/data/user_repository.dart';
import 'package:benefitflutter/features/user/domain/user.dart';
import 'package:benefitflutter/features/user/domain/user_biometrics_reported.dart';
import 'package:benefitflutter/features/user/domain/user_preferences.dart';

import '../mocks/mock_flutter_secure_storage.dart';

/// Shared test fakes for [AuthProvider] / [ProfileProvider] unit tests.
///
/// Hand-written fakes (no codegen) for the three injected collaborators plus
/// fixture builders. Tokens use the mock `type::access::userId::random` format
/// that `AuthProvider._extractUserIdFromToken` parses on session restore.

User userFixture({
  String id = 'user-1',
  String name = 'Alice',
  String email = 'alice@example.com',
  String passwordHash = 'hash-1',
}) {
  return User(id: id, name: name, email: email, passwordHash: passwordHash);
}

AuthTokens tokensFixture({String userId = 'user-1', bool expired = false}) {
  return AuthTokens(
    accessToken: 't::access::$userId::r',
    refreshToken: 't::refresh::$userId::r',
    expiresAt: DateTime.now().add(
      expired ? const Duration(hours: -1) : const Duration(hours: 1),
    ),
  );
}

/// Fresh rate limiter backed by in-memory secure storage (no real keychain).
RateLimiterService freshRateLimiter() {
  return RateLimiterService(
    storage: RateLimitStorage(storage: MockFlutterSecureStorage()),
  );
}

/// In-memory [TokenStorage].
class FakeTokenStorage implements TokenStorage {
  AuthTokens? stored;
  int clearCount = 0;

  FakeTokenStorage([this.stored]);

  @override
  Future<void> saveTokens(AuthTokens tokens) async => stored = tokens;

  @override
  Future<AuthTokens?> getTokens() async => stored;

  @override
  Future<void> clearTokens() async {
    stored = null;
    clearCount++;
  }

  @override
  Future<bool> hasTokens() async => stored != null;

  @override
  Future<String?> getAccessToken() async => stored?.accessToken;
}

/// In-memory [UserRepository]. Seed [users] for read paths; inspect
/// [updatedUser]/[createdUser]/[deleteCalled] for write assertions.
class FakeUserRepository implements UserRepository {
  final Map<String, User> users = {};
  bool throwOnGetById = false;
  bool throwOnUpdate = false;

  User? updatedUser;
  User? createdUser;
  bool deleteCalled = false;

  UserBiometricsReported? latestBiometrics;
  UserPreferences? preferences;
  UserBiometricsReported? savedBiometrics;
  UserPreferences? savedPreferences;

  @override
  Future<User> getUserById(String userId) async {
    if (throwOnGetById) throw Exception('User not found');
    final user = users[userId];
    if (user == null) throw Exception('User not found: $userId');
    return user;
  }

  @override
  Future<User?> getUserByEmail(String email) async {
    final lower = email.trim().toLowerCase();
    for (final u in users.values) {
      if (u.email.toLowerCase() == lower) return u;
    }
    return null;
  }

  @override
  Future<User> getCurrentUser() async => users.values.first;

  @override
  Future<void> updateUser(User user) async {
    if (throwOnUpdate) throw Exception('db write failed');
    users[user.id] = user;
    updatedUser = user;
  }

  @override
  Future<User> createUser(User user) async {
    users[user.id] = user;
    createdUser = user;
    return user;
  }

  @override
  Future<void> deleteCurrentUser() async => deleteCalled = true;

  @override
  Future<UserBiometricsReported?> getLatestBiometrics(String userId) async =>
      latestBiometrics;

  @override
  Future<List<UserBiometricsReported>> getBiometricsHistory(
    String userId,
  ) async => const [];

  @override
  Future<void> saveBiometrics(UserBiometricsReported biometrics) async =>
      savedBiometrics = biometrics;

  @override
  Future<UserPreferences?> getPreferences(String userId) async => preferences;

  @override
  Future<void> savePreferences(UserPreferences prefs) async =>
      savedPreferences = prefs;
}

/// Configurable [AuthService]. Flip the `*Succeeds` flags / override the result
/// payloads per test; counters record how often each method was hit.
class FakeAuthService implements AuthService {
  // login
  bool loginSucceeds = true;
  String loginUserId = 'user-1';
  AuthTokens? loginTokens;
  String loginError = 'Invalid credentials';

  // refresh
  bool refreshSucceeds = true;
  AuthTokens? refreshTokens;

  // register
  bool registerSucceeds = true;
  String registerUserId = 'user-2';
  String registerVerificationCode = '123456';
  String registerError = 'Registration failed';

  // verify
  bool verifySucceeds = true;
  String verifyUserId = 'user-2';
  AuthTokens? verifyTokens;
  String verifyError = 'Invalid code';

  // password reset
  bool resetRequestSucceeds = true;
  String resetRequestEmail = 'alice@example.com';
  String resetRequestCode = '654321';
  bool resetSucceeds = true;
  String resetError = 'Reset failed';

  // account deletion
  bool deletionRequestSucceeds = true;
  String deletionRequestEmail = 'alice@example.com';
  String deletionRequestCode = '111222';
  bool deletionConfirmSucceeds = true;
  String deletionError = 'Deletion failed';

  // change password
  bool changePasswordSucceeds = true;

  bool emailAvailable = true;

  int logoutCalls = 0;

  @override
  Future<AuthResult> login(String email, String password) async {
    if (!loginSucceeds) return AuthResult.failure(error: loginError);
    return AuthResult.success(
      tokens: loginTokens ?? tokensFixture(userId: loginUserId),
      userId: loginUserId,
    );
  }

  @override
  Future<AuthTokens> refreshToken(String refreshToken) async {
    if (!refreshSucceeds) throw const AuthException('Refresh failed');
    return refreshTokens ?? tokensFixture();
  }

  @override
  Future<void> logout(String? accessToken) async => logoutCalls++;

  @override
  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!registerSucceeds) {
      return RegistrationResult.failure(error: registerError);
    }
    return RegistrationResult.success(
      userId: registerUserId,
      verificationCode: registerVerificationCode,
    );
  }

  @override
  Future<AuthResult> verifyEmail({
    required String userId,
    required String code,
  }) async {
    if (!verifySucceeds) return AuthResult.failure(error: verifyError);
    return AuthResult.success(
      tokens: verifyTokens ?? tokensFixture(userId: verifyUserId),
      userId: verifyUserId,
    );
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    if (!resetRequestSucceeds) {
      return PasswordResetRequestResult.failure(error: resetError);
    }
    return PasswordResetRequestResult.success(
      email: resetRequestEmail,
      resetCode: resetRequestCode,
    );
  }

  @override
  Future<PasswordResetResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (!resetSucceeds) return PasswordResetResult.failure(error: resetError);
    return PasswordResetResult.success();
  }

  @override
  Future<bool> changePassword({
    required String userId,
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    return changePasswordSucceeds;
  }

  @override
  Future<AccountDeletionRequestResult> requestAccountDeletion({
    required String userId,
    required String email,
  }) async {
    if (!deletionRequestSucceeds) {
      return AccountDeletionRequestResult.failure(error: deletionError);
    }
    return AccountDeletionRequestResult.success(
      email: deletionRequestEmail,
      deletionCode: deletionRequestCode,
    );
  }

  @override
  Future<AccountDeletionResult> confirmAccountDeletion({
    required String userId,
    required String email,
    required String code,
  }) async {
    if (!deletionConfirmSucceeds) {
      return AccountDeletionResult.failure(error: deletionError);
    }
    return AccountDeletionResult.success();
  }

  @override
  Future<bool> checkEmailAvailability(String email) async => emailAvailable;
}
