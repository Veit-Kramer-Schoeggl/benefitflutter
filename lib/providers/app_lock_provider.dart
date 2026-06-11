import 'package:benefitflutter/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:benefitflutter/features/security/services/biometric_service.dart';
import 'package:benefitflutter/core/config/security_config.dart';

/// Manages app lock state and biometric authentication
///
/// Tracks when the app is locked/unlocked and handles biometric
/// authentication flow. Works with lifecycle observer to trigger
/// lock after app is backgrounded.
class AppLockProvider extends ChangeNotifier {
  final BiometricService _biometricService;

  AppLockProvider({BiometricService? biometricService})
    : _biometricService = biometricService ?? BiometricService();

  // ===== STATE =====

  /// Whether the app is currently locked
  bool _isLocked = false;

  /// Time when app was last paused (backgrounded)
  DateTime? _lastPausedTime;

  /// Number of failed biometric attempts
  int _failedAttempts = 0;

  /// Whether biometric is permanently locked (too many failed attempts)
  bool _isPermanentlyLocked = false;

  /// Whether user has been authenticated this session.
  // ignore: unused_field — written but never read yet; pending dead-code decision (see documentation/ARCHITECTURE_REVIEW.md).
  bool _hasAuthenticatedThisSession = false;

  // ===== GETTERS =====

  /// Whether the app is currently locked
  bool get isLocked => _isLocked;

  /// Whether biometric is permanently locked
  bool get isPermanentlyLocked => _isPermanentlyLocked;

  /// Number of failed biometric attempts
  int get failedAttempts => _failedAttempts;

  /// Remaining biometric attempts before password required
  int get remainingAttempts =>
      SecurityConfig.maxBiometricAttempts - _failedAttempts;

  /// Access to biometric service for capability checks
  BiometricService get biometricService => _biometricService;

  // ===== LIFECYCLE METHODS =====

  /// Called when app goes to background
  ///
  /// Records the time for lock delay calculation.
  void onAppPaused() {
    _lastPausedTime = DateTime.now();
    AppLogger.d('AppLockProvider: App paused at $_lastPausedTime');
  }

  /// Called when app returns to foreground
  ///
  /// Checks if app should be locked based on:
  /// - Biometric enabled
  /// - Time since last pause
  /// - Whether activity tracking is active (skip lock if tracking)
  Future<void> onAppResumed({bool isTrackingActive = false}) async {
    AppLogger.d(
      'AppLockProvider: App resumed, tracking active: $isTrackingActive',
    );

    // Skip lock if activity tracking is active
    if (isTrackingActive) {
      AppLogger.d('AppLockProvider: Skipping lock - activity tracking active');
      return;
    }

    // Check if biometric is enabled
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    if (!biometricEnabled) {
      AppLogger.d('AppLockProvider: Biometric not enabled, skipping lock');
      return;
    }

    // Check if enough time has passed
    if (_lastPausedTime == null) {
      AppLogger.d('AppLockProvider: No pause time recorded, skipping lock');
      return;
    }

    final timeSincePause = DateTime.now().difference(_lastPausedTime!);
    if (timeSincePause < SecurityConfig.biometricLockDelay) {
      AppLogger.d(
        'AppLockProvider: Only ${timeSincePause.inSeconds}s since pause, skipping lock',
      );
      return;
    }

    // Lock the app
    AppLogger.d(
      'AppLockProvider: Locking app after ${timeSincePause.inMinutes}m',
    );
    _isLocked = true;
    notifyListeners();
  }

  // ===== AUTHENTICATION =====

  /// Attempt to unlock with biometrics
  ///
  /// Returns true if unlock successful, false otherwise.
  Future<bool> unlockWithBiometrics() async {
    if (_isPermanentlyLocked) {
      AppLogger.d('AppLockProvider: Permanently locked, cannot use biometrics');
      return false;
    }

    final result = await _biometricService.authenticate();

    if (result.success) {
      AppLogger.d('AppLockProvider: Biometric unlock successful');
      _isLocked = false;
      _failedAttempts = 0;
      _hasAuthenticatedThisSession = true;
      notifyListeners();
      return true;
    }

    if (result.userCancelled) {
      AppLogger.d('AppLockProvider: User cancelled biometric prompt');
      return false;
    }

    if (result.permanentlyLocked) {
      AppLogger.d('AppLockProvider: Biometric permanently locked by system');
      _isPermanentlyLocked = true;
      notifyListeners();
      return false;
    }

    // Failed attempt
    _failedAttempts++;
    AppLogger.d(
      'AppLockProvider: Biometric failed, attempt $_failedAttempts/${SecurityConfig.maxBiometricAttempts}',
    );

    if (_failedAttempts >= SecurityConfig.maxBiometricAttempts) {
      AppLogger.d('AppLockProvider: Max attempts reached, requiring password');
      _isPermanentlyLocked = true;
    }

    notifyListeners();
    return false;
  }

  /// Unlock with password (after biometric fails)
  ///
  /// Call this after verifying password is correct.
  void unlockWithPassword() {
    AppLogger.d('AppLockProvider: Password unlock successful');
    _isLocked = false;
    _failedAttempts = 0;
    _isPermanentlyLocked = false;
    _hasAuthenticatedThisSession = true;
    notifyListeners();
  }

  /// Lock the app immediately
  void lockApp() {
    AppLogger.d('AppLockProvider: Manually locking app');
    _isLocked = true;
    notifyListeners();
  }

  /// Reset lock state (on logout)
  void reset() {
    AppLogger.d('AppLockProvider: Resetting lock state');
    _isLocked = false;
    _lastPausedTime = null;
    _failedAttempts = 0;
    _isPermanentlyLocked = false;
    _hasAuthenticatedThisSession = false;
    notifyListeners();
  }

  // ===== INITIALIZATION =====

  /// Initialize provider on app startup
  ///
  /// Checks if app should start locked based on previous session.
  Future<void> initialize() async {
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    if (!biometricEnabled) {
      AppLogger.d('AppLockProvider: Biometric not enabled, starting unlocked');
      return;
    }

    // On fresh app start, check last unlock time
    final lastUnlock = await _biometricService.getLastUnlockTime();
    if (lastUnlock == null) {
      AppLogger.d('AppLockProvider: No previous unlock, starting unlocked');
      return;
    }

    final timeSinceLastUnlock = DateTime.now().difference(lastUnlock);
    if (timeSinceLastUnlock > SecurityConfig.biometricLockDelay) {
      AppLogger.d(
        'AppLockProvider: Last unlock was ${timeSinceLastUnlock.inMinutes}m ago, locking',
      );
      _isLocked = true;
      notifyListeners();
    }
  }
}
