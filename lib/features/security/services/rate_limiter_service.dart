import 'package:benefitflutter/core/config/security_config.dart';
import 'package:benefitflutter/features/security/data/rate_limit_storage.dart';

/// Service for rate limiting login attempts
///
/// Prevents brute force attacks by limiting login attempts.
/// After [SecurityConfig.maxLoginAttempts] failed attempts,
/// user is locked out for [SecurityConfig.lockoutDuration].
///
/// State persists across app restarts using secure storage.
class RateLimiterService {
  final RateLimitStorage _storage;

  // Cached state to avoid frequent storage reads
  RateLimitState? _cachedState;

  RateLimiterService({RateLimitStorage? storage})
      : _storage = storage ?? RateLimitStorage();

  /// Check if login attempt is allowed
  ///
  /// Returns true if user can attempt login.
  /// Returns false if locked out or rate limit exceeded.
  Future<bool> canAttempt() async {
    if (!SecurityConfig.enableRateLimiting) return true;

    final state = await _getState();

    // Check if locked out
    if (state.isLockedOut) {
      return false;
    }

    // Check if window has expired (reset attempts)
    if (_isWindowExpired(state)) {
      await _resetWindow();
      return true;
    }

    // Check if under limit
    return state.attemptCount < SecurityConfig.maxLoginAttempts;
  }

  /// Record a failed login attempt
  ///
  /// Increments attempt counter and triggers lockout if limit exceeded.
  Future<void> recordFailedAttempt() async {
    if (!SecurityConfig.enableRateLimiting) return;

    var state = await _getState();

    // Reset window if expired
    if (_isWindowExpired(state)) {
      state = RateLimitState(
        attemptCount: 0,
        windowStart: DateTime.now(),
        lockoutEnd: null,
      );
    }

    // Increment attempt count
    final newCount = state.attemptCount + 1;

    // Set window start if first attempt
    final windowStart = state.windowStart ?? DateTime.now();

    // Check if lockout should be triggered
    DateTime? lockoutEnd;
    if (newCount >= SecurityConfig.maxLoginAttempts) {
      lockoutEnd = DateTime.now().add(SecurityConfig.lockoutDuration);
    }

    // Save new state
    final newState = RateLimitState(
      attemptCount: newCount,
      windowStart: windowStart,
      lockoutEnd: lockoutEnd,
    );

    await _storage.saveState(newState);
    _cachedState = newState;
  }

  /// Reset rate limiter on successful login
  ///
  /// Clears all attempt data and lockout state.
  Future<void> resetOnSuccess() async {
    await _storage.clearAll();
    _cachedState = null;
  }

  /// Get remaining login attempts
  ///
  /// Returns number of attempts remaining before lockout.
  /// Returns 0 if currently locked out.
  Future<int> getRemainingAttempts() async {
    if (!SecurityConfig.enableRateLimiting) {
      return SecurityConfig.maxLoginAttempts;
    }

    final state = await _getState();

    // If locked out, no attempts remaining
    if (state.isLockedOut) return 0;

    // If window expired, full attempts available
    if (_isWindowExpired(state)) {
      return SecurityConfig.maxLoginAttempts;
    }

    // Calculate remaining
    final remaining = SecurityConfig.maxLoginAttempts - state.attemptCount;
    return remaining.clamp(0, SecurityConfig.maxLoginAttempts);
  }

  /// Get lockout remaining duration
  ///
  /// Returns Duration.zero if not locked out.
  Future<Duration> getLockoutRemaining() async {
    final state = await _getState();
    return state.remainingLockout;
  }

  /// Get lockout end time
  ///
  /// Returns null if not locked out.
  Future<DateTime?> getLockoutEndTime() async {
    final state = await _getState();
    if (!state.isLockedOut) return null;
    return state.lockoutEnd;
  }

  /// Check if currently locked out
  Future<bool> isLockedOut() async {
    final state = await _getState();
    return state.isLockedOut;
  }

  /// Get current state (cached for performance)
  Future<RateLimitState> _getState() async {
    _cachedState ??= await _storage.getState();
    return _cachedState!;
  }

  /// Check if attempt window has expired
  bool _isWindowExpired(RateLimitState state) {
    if (state.windowStart == null) return true;
    final windowEnd =
        state.windowStart!.add(SecurityConfig.attemptWindowDuration);
    return DateTime.now().isAfter(windowEnd);
  }

  /// Reset the attempt window
  Future<void> _resetWindow() async {
    await _storage.clearAll();
    _cachedState = null;
  }

  /// Force refresh cached state from storage
  ///
  /// Call this if state may have changed externally.
  Future<void> refreshState() async {
    _cachedState = await _storage.getState();
  }
}
