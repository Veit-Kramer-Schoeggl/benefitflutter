import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage for rate limiting state
///
/// Persists login attempt data across app restarts using secure storage.
/// Tracks:
/// - Number of failed login attempts
/// - Time of first attempt in current window
/// - Lockout end time (if locked)
class RateLimitStorage {
  final FlutterSecureStorage _storage;

  // Storage keys
  static const String _attemptCountKey = 'rate_limit_attempt_count';
  static const String _windowStartKey = 'rate_limit_window_start';
  static const String _lockoutEndKey = 'rate_limit_lockout_end';

  RateLimitStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Get current attempt count
  Future<int> getAttemptCount() async {
    final value = await _storage.read(key: _attemptCountKey);
    if (value == null) return 0;
    return int.tryParse(value) ?? 0;
  }

  /// Set attempt count
  Future<void> setAttemptCount(int count) async {
    await _storage.write(key: _attemptCountKey, value: count.toString());
  }

  /// Get window start time (when first attempt in current window occurred)
  Future<DateTime?> getWindowStart() async {
    final value = await _storage.read(key: _windowStartKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Set window start time
  Future<void> setWindowStart(DateTime time) async {
    await _storage.write(key: _windowStartKey, value: time.toIso8601String());
  }

  /// Get lockout end time (null if not locked out)
  Future<DateTime?> getLockoutEnd() async {
    final value = await _storage.read(key: _lockoutEndKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Set lockout end time
  Future<void> setLockoutEnd(DateTime? time) async {
    if (time == null) {
      await _storage.delete(key: _lockoutEndKey);
    } else {
      await _storage.write(key: _lockoutEndKey, value: time.toIso8601String());
    }
  }

  /// Clear all rate limit data (on successful login)
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _attemptCountKey),
      _storage.delete(key: _windowStartKey),
      _storage.delete(key: _lockoutEndKey),
    ]);
  }

  /// Get full rate limit state
  Future<RateLimitState> getState() async {
    final attemptCount = await getAttemptCount();
    final windowStart = await getWindowStart();
    final lockoutEnd = await getLockoutEnd();

    return RateLimitState(
      attemptCount: attemptCount,
      windowStart: windowStart,
      lockoutEnd: lockoutEnd,
    );
  }

  /// Save full rate limit state
  Future<void> saveState(RateLimitState state) async {
    await setAttemptCount(state.attemptCount);
    if (state.windowStart != null) {
      await setWindowStart(state.windowStart!);
    }
    await setLockoutEnd(state.lockoutEnd);
  }
}

/// Immutable rate limit state
class RateLimitState {
  final int attemptCount;
  final DateTime? windowStart;
  final DateTime? lockoutEnd;

  const RateLimitState({
    required this.attemptCount,
    this.windowStart,
    this.lockoutEnd,
  });

  /// Check if currently locked out
  bool get isLockedOut {
    if (lockoutEnd == null) return false;
    return DateTime.now().isBefore(lockoutEnd!);
  }

  /// Get remaining lockout duration (Duration.zero if not locked)
  Duration get remainingLockout {
    if (lockoutEnd == null) return Duration.zero;
    final remaining = lockoutEnd!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Copy with modifications
  RateLimitState copyWith({
    int? attemptCount,
    DateTime? windowStart,
    DateTime? lockoutEnd,
    bool clearLockout = false,
  }) {
    return RateLimitState(
      attemptCount: attemptCount ?? this.attemptCount,
      windowStart: windowStart ?? this.windowStart,
      lockoutEnd: clearLockout ? null : (lockoutEnd ?? this.lockoutEnd),
    );
  }

  @override
  String toString() {
    return 'RateLimitState(attempts: $attemptCount, windowStart: $windowStart, lockoutEnd: $lockoutEnd)';
  }
}
