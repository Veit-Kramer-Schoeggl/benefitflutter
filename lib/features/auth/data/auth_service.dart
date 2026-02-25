import 'dart:math';

import 'package:benefitflutter/core/utils/password_utils.dart';

import '../domain/account_deletion_request_result.dart';
import '../domain/account_deletion_result.dart';
import '../domain/auth_result.dart';
import '../domain/auth_tokens.dart';
import '../domain/password_reset_request_result.dart';
import '../domain/password_reset_result.dart';
import '../domain/registration_result.dart';

/// Authentication service interface
///
/// Defines the contract for authentication operations.
/// Implement this interface to connect to a real backend.
abstract class AuthService {
  /// Authenticate with email and password
  ///
  /// Returns [AuthResult] with tokens and userId on success,
  /// or error message on failure.
  Future<AuthResult> login(String email, String password);

  /// Refresh an expired access token using the refresh token
  ///
  /// Returns new [AuthTokens] on success.
  /// Throws [AuthException] if refresh token is invalid/expired.
  Future<AuthTokens> refreshToken(String refreshToken);

  /// Invalidate the current session on the server
  ///
  /// This is optional - the server may handle this differently.
  Future<void> logout(String? accessToken);

  /// Register a new user account
  ///
  /// Returns [RegistrationResult] with userId and verification code on success,
  /// or error message on failure.
  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
  });

  /// Verify email with the provided code
  ///
  /// Returns [AuthResult] with tokens on success (auto-login),
  /// or error message on failure.
  Future<AuthResult> verifyEmail({
    required String userId,
    required String code,
  });

  /// Request a password reset for the given email
  ///
  /// Returns [PasswordResetRequestResult] with reset code on success (mock),
  /// or error message on failure.
  Future<PasswordResetRequestResult> requestPasswordReset(String email);

  /// Reset password using the reset code
  ///
  /// Returns [PasswordResetResult] indicating success or failure.
  Future<PasswordResetResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Change password for authenticated user
  ///
  /// Verifies the current password, then updates to the new password.
  /// Returns true on success, false on failure (e.g., wrong current password).
  Future<bool> changePassword({
    required String userId,
    required String email,
    required String currentPassword,
    required String newPassword,
  });

  /// Request account deletion for authenticated user
  ///
  /// Sends a verification code to the user's email.
  /// Returns [AccountDeletionRequestResult] with deletion code on success (mock),
  /// or error message on failure.
  Future<AccountDeletionRequestResult> requestAccountDeletion({
    required String userId,
    required String email,
  });

  /// Confirm account deletion with verification code
  ///
  /// Permanently deletes the user's account and all associated data.
  /// Returns [AccountDeletionResult] indicating success or failure.
  Future<AccountDeletionResult> confirmAccountDeletion({
    required String userId,
    required String email,
    required String code,
  });

  /// Check if an email is available for registration
  ///
  /// Returns true if the email is available, false if already taken.
  /// Used for real-time validation during registration.
  Future<bool> checkEmailAvailability(String email);
}

/// Exception thrown by auth operations
class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message${code != null ? ' ($code)' : ''}';
}

/// Mock implementation for development/testing
///
/// Simulates backend authentication with hardcoded test credentials.
/// Replace with [RealAuthService] when backend is available.
class MockAuthService implements AuthService {
  /// Test credentials: email -> {passwordHash, userId}
  /// Passwords are stored as SHA-256 hashes.
  /// Mutable to allow password reset in mock.
  static final Map<String, Map<String, String>> _testCredentials = {
    'test@gmail.com': {
      // Hash of '1234'
      'passwordHash': '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
      'userId': 'test-user-123',
    },
    'test2@gmail.com': {
      // Hash of '1234'
      'passwordHash': '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
      'userId': 'test-user-321',
    },
  };

  /// Pending registrations: userId -> {name, email, passwordHash, verificationCode}
  final Map<String, Map<String, String>> _pendingRegistrations = {};

  /// Verified users added during runtime: email -> {passwordHash, userId, name}
  final Map<String, Map<String, String>> _registeredUsers = {};

  /// Pending password resets: email -> {resetCode, expiresAt}
  final Map<String, Map<String, dynamic>> _pendingResets = {};

  /// Pending account deletions: email -> {deletionCode, expiresAt}
  final Map<String, Map<String, dynamic>> _pendingDeletions = {};

  /// Simulated network delay range
  final Duration minDelay;
  final Duration maxDelay;

  /// Token expiry duration (short for testing)
  final Duration tokenExpiry;

  MockAuthService({
    this.minDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(milliseconds: 500),
    this.tokenExpiry = const Duration(hours: 1),
  });

  /// Simulate network delay
  Future<void> _simulateDelay() async {
    final minMs = minDelay.inMilliseconds;
    final maxMs = maxDelay.inMilliseconds;
    final range = maxMs - minMs;

    if (range <= 0) {
      await Future.delayed(minDelay);
      return;
    }

    final random = Random();
    final delayMs = minMs + random.nextInt(range);
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Generate a mock JWT-like token
  /// Format: mock::{type}::{userId}::{random}
  String _generateMockToken(String type, String userId) {
    final random = Random();
    final randomPart = List.generate(32, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'mock::$type::$userId::$randomPart';
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    await _simulateDelay();

    // Normalize email
    final normalizedEmail = email.trim().toLowerCase();

    // Look up credentials - check test credentials first, then registered users
    var credentials = _testCredentials[normalizedEmail];
    credentials ??= _registeredUsers[normalizedEmail];

    if (credentials == null) {
      return AuthResult.failure(error: 'No account found with this email');
    }

    // Verify password against stored hash
    final storedHash = credentials['passwordHash']!;
    if (!PasswordUtils.verifyPassword(password, storedHash)) {
      return AuthResult.failure(error: 'Invalid password');
    }

    final userId = credentials['userId']!;

    // Generate mock tokens
    final tokens = AuthTokens(
      accessToken: _generateMockToken('access', userId),
      refreshToken: _generateMockToken('refresh', userId),
      expiresAt: DateTime.now().add(tokenExpiry),
    );

    return AuthResult.success(tokens: tokens, userId: userId);
  }

  @override
  Future<AuthTokens> refreshToken(String refreshToken) async {
    await _simulateDelay();

    // Extract userId from mock token format: mock::{type}::{userId}::{random}
    final parts = refreshToken.split('::');
    if (parts.length < 3 || parts[1] != 'refresh') {
      throw const AuthException(
        'Invalid refresh token',
        code: 'INVALID_REFRESH_TOKEN',
      );
    }

    final userId = parts[2];

    // Generate new tokens
    return AuthTokens(
      accessToken: _generateMockToken('access', userId),
      refreshToken: _generateMockToken('refresh', userId),
      expiresAt: DateTime.now().add(tokenExpiry),
    );
  }

  @override
  Future<void> logout(String? accessToken) async {
    await _simulateDelay();
    // Mock logout - just simulates server acknowledgment
    // In real implementation, this would invalidate the token on the server
  }

  /// Generate 6-digit verification code
  String _generateVerificationCode() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  @override
  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _simulateDelay();

    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = name.trim();

    // Check if email already exists in test credentials or registered users
    if (_testCredentials.containsKey(normalizedEmail) ||
        _registeredUsers.containsKey(normalizedEmail)) {
      return RegistrationResult.failure(
        error: 'An account with this email already exists',
      );
    }

    // Check if already pending verification
    final existingPending = _pendingRegistrations.values
        .where((reg) => reg['email'] == normalizedEmail)
        .firstOrNull;
    if (existingPending != null) {
      return RegistrationResult.failure(
        error: 'A verification is already pending for this email',
      );
    }

    // Generate userId and verification code
    final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final verificationCode = _generateVerificationCode();

    // Hash password before storing
    final passwordHash = PasswordUtils.hashPassword(password);

    // Store pending registration
    _pendingRegistrations[userId] = {
      'name': trimmedName,
      'email': normalizedEmail,
      'passwordHash': passwordHash,
      'verificationCode': verificationCode,
    };

    return RegistrationResult.success(
      userId: userId,
      verificationCode: verificationCode,
    );
  }

  @override
  Future<AuthResult> verifyEmail({
    required String userId,
    required String code,
  }) async {
    await _simulateDelay();

    // Look up pending registration
    final pending = _pendingRegistrations[userId];
    if (pending == null) {
      return AuthResult.failure(error: 'Registration not found or expired');
    }

    // Verify code
    if (pending['verificationCode'] != code) {
      return AuthResult.failure(error: 'Invalid verification code');
    }

    // Move from pending to registered
    final email = pending['email']!;
    _registeredUsers[email] = {
      'passwordHash': pending['passwordHash']!,
      'userId': userId,
      'name': pending['name']!,
    };

    // Remove from pending
    _pendingRegistrations.remove(userId);

    // Generate tokens (same as login)
    final tokens = AuthTokens(
      accessToken: _generateMockToken('access', userId),
      refreshToken: _generateMockToken('refresh', userId),
      expiresAt: DateTime.now().add(tokenExpiry),
    );

    return AuthResult.success(tokens: tokens, userId: userId);
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    await _simulateDelay();

    final normalizedEmail = email.trim().toLowerCase();

    // Check if email exists in test credentials or registered users
    final existsInTest = _testCredentials.containsKey(normalizedEmail);
    final existsInRegistered = _registeredUsers.containsKey(normalizedEmail);

    if (!existsInTest && !existsInRegistered) {
      return PasswordResetRequestResult.failure(
        error: 'No account found with this email',
      );
    }

    // Generate reset code (6 digits, same as verification)
    final resetCode = _generateVerificationCode();

    // Store pending reset with 15-minute expiry
    _pendingResets[normalizedEmail] = {
      'resetCode': resetCode,
      'expiresAt': DateTime.now().add(const Duration(minutes: 15)),
    };

    return PasswordResetRequestResult.success(
      email: normalizedEmail,
      resetCode: resetCode,
    );
  }

  @override
  Future<PasswordResetResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _simulateDelay();

    final normalizedEmail = email.trim().toLowerCase();

    // Check for pending reset
    final pending = _pendingResets[normalizedEmail];
    if (pending == null) {
      return PasswordResetResult.failure(
        error: 'No password reset request found. Please request a new reset.',
      );
    }

    // Check expiry
    final expiresAt = pending['expiresAt'] as DateTime;
    if (DateTime.now().isAfter(expiresAt)) {
      _pendingResets.remove(normalizedEmail);
      return PasswordResetResult.failure(
        error: 'Reset code has expired. Please request a new reset.',
      );
    }

    // Verify code
    if (pending['resetCode'] != code) {
      return PasswordResetResult.failure(
        error: 'Invalid reset code',
      );
    }

    // Hash new password before storing
    final newPasswordHash = PasswordUtils.hashPassword(newPassword);

    // Update password in appropriate storage
    if (_testCredentials.containsKey(normalizedEmail)) {
      _testCredentials[normalizedEmail]!['passwordHash'] = newPasswordHash;
    }

    if (_registeredUsers.containsKey(normalizedEmail)) {
      _registeredUsers[normalizedEmail]!['passwordHash'] = newPasswordHash;
    }

    // Clear the pending reset
    _pendingResets.remove(normalizedEmail);

    return PasswordResetResult.success();
  }

  @override
  Future<bool> changePassword({
    required String userId,
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _simulateDelay();

    final normalizedEmail = email.trim().toLowerCase();

    // Find credentials in test credentials or registered users
    Map<String, String>? credentials = _testCredentials[normalizedEmail];
    bool isTestUser = credentials != null;

    credentials ??= _registeredUsers[normalizedEmail];

    if (credentials == null) {
      return false;
    }

    // Verify current password
    final storedHash = credentials['passwordHash']!;
    if (!PasswordUtils.verifyPassword(currentPassword, storedHash)) {
      return false;
    }

    // Hash and store new password
    final newPasswordHash = PasswordUtils.hashPassword(newPassword);

    if (isTestUser) {
      _testCredentials[normalizedEmail]!['passwordHash'] = newPasswordHash;
    } else {
      _registeredUsers[normalizedEmail]!['passwordHash'] = newPasswordHash;
    }

    return true;
  }

  @override
  Future<AccountDeletionRequestResult> requestAccountDeletion({
    required String userId,
    required String email,
  }) async {
    await _simulateDelay();

    final normalizedEmail = email.trim().toLowerCase();

    // Check if email exists in test credentials or registered users
    final existsInTest = _testCredentials.containsKey(normalizedEmail);
    final existsInRegistered = _registeredUsers.containsKey(normalizedEmail);

    if (!existsInTest && !existsInRegistered) {
      return AccountDeletionRequestResult.failure(
        error: 'No account found with this email',
      );
    }

    // Generate deletion code (6 digits, same as verification)
    final deletionCode = _generateVerificationCode();

    // Store pending deletion with 15-minute expiry
    _pendingDeletions[normalizedEmail] = {
      'deletionCode': deletionCode,
      'userId': userId,
      'expiresAt': DateTime.now().add(const Duration(minutes: 15)),
    };

    return AccountDeletionRequestResult.success(
      email: normalizedEmail,
      deletionCode: deletionCode,
    );
  }

  @override
  Future<AccountDeletionResult> confirmAccountDeletion({
    required String userId,
    required String email,
    required String code,
  }) async {
    await _simulateDelay();

    final normalizedEmail = email.trim().toLowerCase();

    // Check for pending deletion
    final pending = _pendingDeletions[normalizedEmail];
    if (pending == null) {
      return AccountDeletionResult.failure(
        error: 'No deletion request found. Please request a new deletion.',
      );
    }

    // Check expiry
    final expiresAt = pending['expiresAt'] as DateTime;
    if (DateTime.now().isAfter(expiresAt)) {
      _pendingDeletions.remove(normalizedEmail);
      return AccountDeletionResult.failure(
        error: 'Verification code has expired. Please request a new deletion.',
      );
    }

    // Verify code
    if (pending['deletionCode'] != code) {
      return AccountDeletionResult.failure(
        error: 'Invalid verification code',
      );
    }

    // Remove user from credentials
    _testCredentials.remove(normalizedEmail);
    _registeredUsers.remove(normalizedEmail);

    // Clear the pending deletion
    _pendingDeletions.remove(normalizedEmail);

    return AccountDeletionResult.success();
  }

  @override
  Future<bool> checkEmailAvailability(String email) async {
    await _simulateDelay();

    final normalizedEmail = email.trim().toLowerCase();

    // Check if email exists in test credentials, registered users, or pending registrations
    final existsInTest = _testCredentials.containsKey(normalizedEmail);
    final existsInRegistered = _registeredUsers.containsKey(normalizedEmail);
    final existsInPending = _pendingRegistrations.values
        .any((reg) => reg['email'] == normalizedEmail);

    // Return true if available (not found anywhere)
    return !existsInTest && !existsInRegistered && !existsInPending;
  }
}
