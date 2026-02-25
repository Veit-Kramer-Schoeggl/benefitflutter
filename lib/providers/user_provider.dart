import 'package:flutter/foundation.dart';
import 'package:benefitflutter/core/utils/password_utils.dart';
import 'package:benefitflutter/features/user/domain/user.dart';
import 'package:benefitflutter/features/user/data/user_repository.dart';
import 'package:benefitflutter/features/auth/data/auth_service.dart';
import 'package:benefitflutter/features/auth/data/token_storage.dart';
import 'package:benefitflutter/features/auth/domain/auth_tokens.dart';
import 'package:benefitflutter/features/user/domain/user_biometrics_reported.dart';
import 'package:benefitflutter/features/user/domain/user_preferences.dart';
import 'package:benefitflutter/features/security/services/rate_limiter_service.dart';

/// Provider for user authentication state management
///
/// Manages the current authenticated user and provides:
/// - Login/logout functionality via AuthService
/// - Session persistence via TokenStorage (secure)
/// - Current user state for other providers
/// - Token refresh handling
class UserProvider extends ChangeNotifier {
  final UserRepository _repository;
  final AuthService _authService;
  final TokenStorage _tokenStorage;
  final RateLimiterService _rateLimiter;

  UserProvider({
    required UserRepository repository,
    required AuthService authService,
    required TokenStorage tokenStorage,
    RateLimiterService? rateLimiter,
  })  : _repository = repository,
        _authService = authService,
        _tokenStorage = tokenStorage,
        _rateLimiter = rateLimiter ?? RateLimiterService();

  // ===== STATE VARIABLES =====

  /// Current authenticated user (null if not logged in)
  User? _currentUser;

  /// Current auth tokens (null if not logged in)
  AuthTokens? _currentTokens;

  /// Loading state during initialization or login
  bool _isLoading = false;

  /// Error message (null if no error)
  String? _error;

  /// Whether initialization has completed
  bool _isInitialized = false;

  /// Pending registration userId (for verification flow)
  String? _pendingRegistrationUserId;

  /// Pending registration user data (for creating user after verification)
  String? _pendingRegistrationName;
  String? _pendingRegistrationEmail;
  String? _pendingRegistrationPassword;

  /// Pending verification code (for mock display on verification screen)
  String? _pendingVerificationCode;

  /// Pending password reset email (for reset flow)
  String? _pendingResetEmail;

  /// Pending password reset code (for mock display on reset screen)
  String? _pendingResetCode;

  /// Pending account deletion email (for deletion flow)
  String? _pendingDeletionEmail;

  // ===== GETTERS =====

  /// Current authenticated user
  User? get currentUser => _currentUser;

  /// Current user ID (convenience getter)
  String? get userId => _currentUser?.id;

  /// Whether user is authenticated
  bool get isAuthenticated => _currentUser != null && _currentTokens != null;

  /// Whether currently loading
  bool get isLoading => _isLoading;

  /// Current error message
  String? get error => _error;

  /// Whether an error has occurred
  bool get hasError => _error != null;

  /// Whether initialization has completed
  bool get isInitialized => _isInitialized;

  /// Current access token (for API calls)
  String? get accessToken => _currentTokens?.accessToken;

  /// Pending registration userId (for verification flow)
  String? get pendingRegistrationUserId => _pendingRegistrationUserId;

  /// Pending verification code (for mock display)
  String? get pendingVerificationCode => _pendingVerificationCode;

  /// Pending password reset email (for reset flow)
  String? get pendingResetEmail => _pendingResetEmail;

  /// Pending password reset code (for mock display)
  String? get pendingResetCode => _pendingResetCode;

  /// Pending account deletion email (for deletion flow)
  String? get pendingDeletionEmail => _pendingDeletionEmail;

  /// Access to rate limiter for UI to check status
  RateLimiterService get rateLimiter => _rateLimiter;

  // ===== METHODS =====

  /// Initialize provider - check for stored session
  ///
  /// Call this on app startup to restore user session from secure storage.
  /// If valid tokens exist, loads the user from the repository.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check for stored tokens
      final tokens = await _tokenStorage.getTokens();

      if (tokens != null) {
        debugPrint('UserProvider: Found stored tokens');

        // Check if tokens are expired
        if (tokens.isExpired) {
          debugPrint('UserProvider: Tokens expired, attempting refresh');
          try {
            final newTokens = await _authService.refreshToken(tokens.refreshToken);
            await _tokenStorage.saveTokens(newTokens);
            _currentTokens = newTokens;
          } catch (e) {
            debugPrint('UserProvider: Token refresh failed - $e');
            await _tokenStorage.clearTokens();
            _currentUser = null;
            _currentTokens = null;
            _isLoading = false;
            _isInitialized = true;
            notifyListeners();
            return;
          }
        } else {
          _currentTokens = tokens;
        }

        // Extract userId from token (mock tokens contain userId)
        final userId = _extractUserIdFromToken(tokens.accessToken);
        if (userId != null) {
          _currentUser = await _repository.getUserById(userId);
          debugPrint('UserProvider: Restored session for ${_currentUser?.name}');
        }
      } else {
        debugPrint('UserProvider: No stored session found');
        _currentUser = null;
      }

      _error = null;
    } catch (e) {
      debugPrint('UserProvider: Error initializing - $e');
      _error = 'Failed to restore session: $e';
      _currentUser = null;
      _currentTokens = null;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Extract userId from mock token format: mock::{type}::{userId}::{random}
  String? _extractUserIdFromToken(String token) {
    final parts = token.split('::');
    if (parts.length >= 3 && (parts[1] == 'access' || parts[1] == 'refresh')) {
      return parts[2];
    }
    // For real JWT, you would decode the token payload
    return null;
  }

  /// Login with email and password
  ///
  /// Authenticates via AuthService and stores tokens securely.
  /// Includes rate limiting to prevent brute force attacks.
  ///
  /// Returns true on success, false on failure.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check rate limit first
      if (!await _rateLimiter.canAttempt()) {
        final remaining = await _rateLimiter.getLockoutRemaining();
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        _error = 'Too many login attempts. Try again in ${minutes}m ${seconds}s';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validate inputs
      final trimmedEmail = email.trim();
      final trimmedPassword = password.trim();

      // Validate inputs
      if (trimmedEmail.isEmpty) {
        _error = 'Please enter your email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (trimmedPassword.isEmpty) {
        _error = 'Please enter your password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Authenticate via auth service
      final result = await _authService.login(trimmedEmail, trimmedPassword);

      if (!result.success) {
        // Record failed attempt
        await _rateLimiter.recordFailedAttempt();
        final remaining = await _rateLimiter.getRemainingAttempts();

        if (remaining > 0) {
          _error = '${result.error ?? 'Login failed'}. $remaining attempts remaining.';
        } else {
          final lockoutRemaining = await _rateLimiter.getLockoutRemaining();
          final minutes = lockoutRemaining.inMinutes;
          _error = 'Too many login attempts. Try again in $minutes minutes.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Store tokens securely
      await _tokenStorage.saveTokens(result.tokens!);
      _currentTokens = result.tokens;

      // Load user from repository
      try {
        _currentUser = await _repository.getUserById(result.userId!);
      } catch (e) {
        // User exists in auth but not in local database
        debugPrint('UserProvider: User not found in database - $e');
        _error = 'No account found with this email';
        await _tokenStorage.clearTokens();
        _currentTokens = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (_currentUser == null) {
        _error = 'No account found with this email';
        await _tokenStorage.clearTokens();
        _currentTokens = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Reset rate limiter on successful login
      await _rateLimiter.resetOnSuccess();

      debugPrint('UserProvider: Login successful for ${_currentUser!.name}');
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UserProvider: Login error - $e');
      // Record failed attempt for unexpected errors
      await _rateLimiter.recordFailedAttempt();
      // Show user-friendly error instead of technical details
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('user not found') || errorStr.contains('no account')) {
        _error = 'No account found with this email';
      } else {
        _error = 'Login failed. Please check your credentials.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout current user
  ///
  /// Clears tokens from secure storage and user state.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Notify server (optional, may fail)
      try {
        await _authService.logout(_currentTokens?.accessToken);
      } catch (e) {
        debugPrint('UserProvider: Server logout failed (ignored) - $e');
      }

      // Clear secure storage
      await _tokenStorage.clearTokens();

      // Clear user state
      _currentUser = null;
      _currentTokens = null;
      _error = null;

      debugPrint('UserProvider: Logout successful');
    } catch (e) {
      debugPrint('UserProvider: Logout error - $e');
      // Still clear local state even if storage fails
      _currentUser = null;
      _currentTokens = null;
      _error = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh the current session's tokens
  ///
  /// Call this when you receive a 401 from the API.
  /// Returns true if refresh succeeded, false if re-login needed.
  Future<bool> refreshSession() async {
    if (_currentTokens == null) {
      return false;
    }

    try {
      final newTokens = await _authService.refreshToken(
        _currentTokens!.refreshToken,
      );
      await _tokenStorage.saveTokens(newTokens);
      _currentTokens = newTokens;
      notifyListeners();
      debugPrint('UserProvider: Session refreshed');
      return true;
    } on AuthException catch (e) {
      debugPrint('UserProvider: Session refresh failed - ${e.message}');
      // Refresh failed - need to re-login
      await logout();
      return false;
    }
  }

  /// Update current user profile
  ///
  /// Updates both local state and repository.
  Future<bool> updateUser(User updatedUser) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.updateUser(updatedUser);
      _currentUser = updatedUser;
      _error = null;
      debugPrint('UserProvider: Updated user ${updatedUser.name}');
      return true;
    } catch (e) {
      _error = 'Failed to update profile: $e';
      debugPrint('UserProvider: Update error - $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear any error state
  void clearError() {
    if (_error != null) {
      debugPrint('UserProvider: clearError() - clearing error: $_error');
    }
    _error = null;
    notifyListeners();
  }

  /// Handle auth failure from interceptor
  ///
  /// Called when token refresh fails during an API call.
  void handleAuthFailure() {
    _currentUser = null;
    _currentTokens = null;
    _error = 'Session expired. Please log in again.';
    notifyListeners();
  }

  // ===== REGISTRATION METHODS =====

  /// Check if an email is available for registration
  ///
  /// Returns true if available, false if already taken.
  /// Does NOT set loading state (lightweight check for real-time validation).
  Future<bool> checkEmailAvailability(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return true; // Empty email is "available" - form validation handles this
    }

    try {
      return await _authService.checkEmailAvailability(trimmedEmail);
    } catch (e) {
      debugPrint('UserProvider: Email availability check failed - $e');
      return true; // On error, allow to proceed (server will validate)
    }
  }

  /// Register a new user account
  ///
  /// Validates inputs, calls authService.register(), and stores pending userId.
  /// Returns verification code on success (to display in UI), null on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    debugPrint('UserProvider: register() called for email: $email');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate inputs
      final trimmedName = name.trim();
      final trimmedEmail = email.trim();

      if (trimmedName.isEmpty) {
        _error = 'Please enter your name';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      if (trimmedEmail.isEmpty) {
        _error = 'Please enter your email';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Call auth service
      final result = await _authService.register(
        name: trimmedName,
        email: trimmedEmail,
        password: password,
      );

      if (!result.success) {
        debugPrint('UserProvider: register() failed with error: ${result.error}');
        _error = result.error ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Store pending registration for verification
      _pendingRegistrationUserId = result.userId;
      _pendingRegistrationName = trimmedName;
      _pendingRegistrationEmail = trimmedEmail;
      _pendingRegistrationPassword = password;
      _pendingVerificationCode = result.verificationCode;

      debugPrint('UserProvider: Registration successful, verification code: ${result.verificationCode}');
      _error = null;
      _isLoading = false;
      notifyListeners();

      // Return verification code for UI to display
      return result.verificationCode;
    } catch (e) {
      debugPrint('UserProvider: Registration error - $e');
      _error = 'Registration failed: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Verify email with code and auto-login
  ///
  /// Returns true on success, false on failure.
  Future<bool> verifyEmail(String code) async {
    if (_pendingRegistrationUserId == null) {
      _error = 'No pending registration';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.verifyEmail(
        userId: _pendingRegistrationUserId!,
        code: code,
      );

      if (!result.success) {
        _error = result.error ?? 'Verification failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Store tokens (auto-login)
      await _tokenStorage.saveTokens(result.tokens!);
      _currentTokens = result.tokens;

      // Create new user in repository
      final newUser = User(
        id: result.userId!,
        name: _pendingRegistrationName ?? 'New User',
        email: _pendingRegistrationEmail ?? '',
        passwordHash: _pendingRegistrationPassword ?? '',
      );

      try {
        await _repository.createUser(newUser);
        debugPrint('UserProvider: Created new user in repository');
      } catch (e) {
        debugPrint('UserProvider: Could not create user in repository - $e');
        // Continue anyway - user might already exist
      }

      // Load user from repository (or use the new user we just created)
      try {
        _currentUser = await _repository.getUserById(result.userId!);
      } catch (e) {
        // If loading fails, use the user we created
        _currentUser = newUser;
      }

      // Clear pending registration
      _pendingRegistrationUserId = null;
      _pendingRegistrationName = null;
      _pendingRegistrationEmail = null;
      _pendingRegistrationPassword = null;
      _pendingVerificationCode = null;

      debugPrint('UserProvider: Verification successful for ${_currentUser?.name}');
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UserProvider: Verification error - $e');
      _error = 'Verification failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear pending registration (e.g., user goes back)
  void clearPendingRegistration() {
    _pendingRegistrationUserId = null;
    _pendingRegistrationName = null;
    _pendingRegistrationEmail = null;
    _pendingRegistrationPassword = null;
    _pendingVerificationCode = null;
    notifyListeners();
  }

  // ===== ACCOUNT DELETION METHODS =====

  /// Request account deletion (sends verification code)
  ///
  /// Returns deletion code on success (to display in mock UI), null on failure.
  Future<String?> requestAccountDeletion() async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.requestAccountDeletion(
        userId: _currentUser!.id,
        email: _currentUser!.email,
      );

      if (!result.success) {
        _error = result.error ?? 'Failed to request account deletion';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Store email for deletion confirmation
      _pendingDeletionEmail = result.email;

      debugPrint('UserProvider: Account deletion requested, code: ${result.deletionCode}');
      _error = null;
      _isLoading = false;
      notifyListeners();

      return result.deletionCode;
    } catch (e) {
      debugPrint('UserProvider: Account deletion request error - $e');
      _error = 'Failed to request account deletion: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Confirm account deletion with verification code
  ///
  /// Permanently deletes the account. Returns true on success.
  Future<bool> confirmAccountDeletion(String code) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return false;
    }

    if (_pendingDeletionEmail == null) {
      _error = 'No deletion request in progress';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.confirmAccountDeletion(
        userId: _currentUser!.id,
        email: _pendingDeletionEmail!,
        code: code,
      );

      if (!result.success) {
        _error = result.error ?? 'Failed to delete account';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Delete from local database
      await _repository.deleteCurrentUser();

      // Clear auth tokens
      await _tokenStorage.clearTokens();
      _currentTokens = null;
      _currentUser = null;
      _pendingDeletionEmail = null;
      _error = null;

      debugPrint('UserProvider: Account deleted successfully');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UserProvider: Account deletion error - $e');
      _error = 'Failed to delete account: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear pending account deletion (e.g., user cancels)
  void clearPendingDeletion() {
    _pendingDeletionEmail = null;
    notifyListeners();
  }

  /// Legacy method - now uses two-step verification
  @Deprecated('Use requestAccountDeletion and confirmAccountDeletion instead')
  Future<bool> deleteAccount() async {
    _error = 'Please use the new verification-based deletion flow';
    notifyListeners();
    return false;
  }

  Future<UserBiometricsReported?> getLatestBiometrics(String userId) {
    return _repository.getLatestBiometrics(userId);
  }

  Future<UserPreferences?> getPreferences(String userId) {
    return _repository.getPreferences(userId);
  }

  Future<void> saveBiometrics(UserBiometricsReported biometrics) {
    return _repository.saveBiometrics(biometrics);
  }

  Future<void> savePreferences(UserPreferences prefs) {
    return _repository.savePreferences(prefs);
  }

  Future<void> refreshUser() async {
    if (_currentUser == null) return;

    final refreshedUser = await _repository.getUserById(_currentUser!.id);
    _currentUser = refreshedUser;
    notifyListeners();
  }

  // ===== PASSWORD RESET METHODS =====

  /// Request password reset for the given email
  ///
  /// Returns reset code on success (to display in mock UI), null on failure.
  Future<String?> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trimmedEmail = email.trim();

      if (trimmedEmail.isEmpty) {
        _error = 'Please enter your email';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final result = await _authService.requestPasswordReset(trimmedEmail);

      if (!result.success) {
        _error = result.error ?? 'Failed to request password reset';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Store email and code for reset step
      _pendingResetEmail = result.email;
      _pendingResetCode = result.resetCode;

      debugPrint('UserProvider: Password reset requested, code: ${result.resetCode}');
      _error = null;
      _isLoading = false;
      notifyListeners();

      return result.resetCode;
    } catch (e) {
      debugPrint('UserProvider: Password reset request error - $e');
      _error = 'Failed to request password reset: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Reset password using the code and new password
  ///
  /// Returns true on success, false on failure.
  Future<bool> resetPassword({
    required String code,
    required String newPassword,
  }) async {
    if (_pendingResetEmail == null) {
      _error = 'No password reset in progress';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.resetPassword(
        email: _pendingResetEmail!,
        code: code,
        newPassword: newPassword,
      );

      if (!result.success) {
        _error = result.error ?? 'Failed to reset password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Clear pending reset
      _pendingResetEmail = null;
      _pendingResetCode = null;

      debugPrint('UserProvider: Password reset successful');
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UserProvider: Password reset error - $e');
      _error = 'Failed to reset password: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear pending password reset (e.g., user cancels)
  void clearPendingReset() {
    _pendingResetEmail = null;
    _pendingResetCode = null;
    notifyListeners();
  }

  // ===== CHANGE PASSWORD (Authenticated User) =====

  /// Change password for the currently logged-in user
  ///
  /// Verifies current password, updates both auth service and database.
  /// Returns true on success, false on failure.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Update auth service credentials first
      final authSuccess = await _authService.changePassword(
        userId: _currentUser!.id,
        email: _currentUser!.email,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!authSuccess) {
        _error = 'Current password is incorrect';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Update database with new password hash
      final newHash = PasswordUtils.hashPassword(newPassword);
      final updatedUser = _currentUser!.copyWith(passwordHash: newHash);
      await _repository.updateUser(updatedUser);
      _currentUser = updatedUser;

      debugPrint('UserProvider: Password changed successfully');
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UserProvider: Password change error - $e');
      _error = 'Failed to change password: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
