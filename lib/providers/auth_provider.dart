import 'package:benefitflutter/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:benefitflutter/core/utils/password_utils.dart';
import 'package:benefitflutter/features/user/domain/user.dart';
import 'package:benefitflutter/features/user/data/user_repository.dart';
import 'package:benefitflutter/features/auth/data/auth_service.dart';
import 'package:benefitflutter/features/auth/data/token_storage.dart';
import 'package:benefitflutter/features/auth/domain/auth_tokens.dart';
import 'package:benefitflutter/features/security/services/rate_limiter_service.dart';

/// Provider for user authentication state management
///
/// Manages the current authenticated user and provides:
/// - Login/logout functionality via AuthService
/// - Session persistence via TokenStorage (secure)
/// - Current user state for other providers
/// - Token refresh handling
class AuthProvider extends ChangeNotifier {
  final UserRepository _repository;
  final AuthService _authService;
  final TokenStorage _tokenStorage;
  final RateLimiterService _rateLimiter;

  AuthProvider({
    required UserRepository repository,
    required AuthService authService,
    required TokenStorage tokenStorage,
    RateLimiterService? rateLimiter,
  }) : _repository = repository,
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
        AppLogger.d('AuthProvider: Found stored tokens');

        // Check if tokens are expired
        if (tokens.isExpired) {
          AppLogger.d('AuthProvider: Tokens expired, attempting refresh');
          try {
            final newTokens = await _authService.refreshToken(
              tokens.refreshToken,
            );
            await _tokenStorage.saveTokens(newTokens);
            _currentTokens = newTokens;
          } catch (e) {
            AppLogger.e('AuthProvider: Token refresh failed - $e');
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
          AppLogger.d(
            'AuthProvider: Restored session for ${_currentUser?.name}',
          );
        }
      } else {
        AppLogger.d('AuthProvider: No stored session found');
        _currentUser = null;
      }

      _error = null;
    } catch (e) {
      AppLogger.e('AuthProvider: Error initializing - $e');
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
        _error =
            'Too many login attempts. Try again in ${minutes}m ${seconds}s';
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
          _error =
              '${result.error ?? 'Login failed'}. $remaining attempts remaining.';
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
        AppLogger.e('AuthProvider: User not found in database - $e');
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

      AppLogger.d('AuthProvider: Login successful for ${_currentUser!.name}');
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('AuthProvider: Login error - $e');
      // Record failed attempt for unexpected errors
      await _rateLimiter.recordFailedAttempt();
      // Show user-friendly error instead of technical details
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('user not found') ||
          errorStr.contains('no account')) {
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
        AppLogger.e('AuthProvider: Server logout failed (ignored) - $e');
      }

      // Clear secure storage
      await _tokenStorage.clearTokens();

      // Clear user state
      _currentUser = null;
      _currentTokens = null;
      _error = null;

      AppLogger.d('AuthProvider: Logout successful');
    } catch (e) {
      AppLogger.e('AuthProvider: Logout error - $e');
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
      AppLogger.d('AuthProvider: Session refreshed');
      return true;
    } on AuthException catch (e) {
      AppLogger.e('AuthProvider: Session refresh failed - ${e.message}');
      // Refresh failed - need to re-login
      await logout();
      return false;
    }
  }

  /// Clear any error state
  void clearError() {
    if (_error != null) {
      AppLogger.d('AuthProvider: clearError() - clearing error: $_error');
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
      AppLogger.e('AuthProvider: Email availability check failed - $e');
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
    AppLogger.d('AuthProvider: register() called');
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
        AppLogger.d(
          'AuthProvider: register() failed with error: ${result.error}',
        );
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

      AppLogger.d(
        'AuthProvider: Registration successful (verification code issued)',
      );
      _error = null;
      _isLoading = false;
      notifyListeners();

      // Return verification code for UI to display
      return result.verificationCode;
    } catch (e) {
      AppLogger.e('AuthProvider: Registration error - $e');
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

      // Create new user in repository. Store a SHA-256 hash (NOT the plaintext)
      // so DB-backed login can verify it — PasswordUtils.verifyPassword re-hashes
      // the input and compares against this stored hash.
      final newUser = User(
        id: result.userId!,
        name: _pendingRegistrationName ?? 'New User',
        email: _pendingRegistrationEmail ?? '',
        passwordHash: PasswordUtils.hashPassword(
          _pendingRegistrationPassword ?? '',
        ),
      );

      try {
        await _repository.createUser(newUser);
        AppLogger.d('AuthProvider: Created new user in repository');
      } catch (e) {
        AppLogger.e('AuthProvider: Could not create user in repository - $e');
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

      AppLogger.d(
        'AuthProvider: Verification successful for ${_currentUser?.name}',
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('AuthProvider: Verification error - $e');
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

      AppLogger.d(
        'AuthProvider: Account deletion requested (confirmation code issued)',
      );
      _error = null;
      _isLoading = false;
      notifyListeners();

      return result.deletionCode;
    } catch (e) {
      AppLogger.e('AuthProvider: Account deletion request error - $e');
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

      AppLogger.d('AuthProvider: Account deleted successfully');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('AuthProvider: Account deletion error - $e');
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

  Future<void> refreshUser() async {
    if (_currentUser == null) return;

    final refreshedUser = await _repository.getUserById(_currentUser!.id);
    _currentUser = refreshedUser;
    notifyListeners();
  }

  /// Replace the in-memory current user (e.g. after a profile edit performed by
  /// ProfileProvider). AuthProvider remains the single source of identity.
  ///
  /// Skips the rebuild only when the exact same instance is set again. We must
  /// NOT use `==` here: [User.==] compares by `id` only, so a profile edit
  /// (same id, changed fields) would be silently dropped and never propagate.
  void setCurrentUser(User user) {
    if (identical(_currentUser, user)) return;
    _currentUser = user;
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

      AppLogger.d('AuthProvider: Password reset requested (reset code issued)');
      _error = null;
      _isLoading = false;
      notifyListeners();

      return result.resetCode;
    } catch (e) {
      AppLogger.e('AuthProvider: Password reset request error - $e');
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

      AppLogger.d('AuthProvider: Password reset successful');
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('AuthProvider: Password reset error - $e');
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

      AppLogger.d('AuthProvider: Password changed successfully');
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('AuthProvider: Password change error - $e');
      _error = 'Failed to change password: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
