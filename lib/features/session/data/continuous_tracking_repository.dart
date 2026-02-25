import '../domain/continuous_tracking_config.dart';
import '../domain/continuous_tracking_state.dart';
import '../domain/activity_segment.dart';

/// Repository interface for continuous tracking operations
///
/// Provides high-level operations for managing continuous tracking
/// configuration, state, and activity segments.
abstract class ContinuousTrackingRepository {
  // ============================================================
  // CONFIGURATION
  // ============================================================

  /// Get continuous tracking configuration for a user
  ///
  /// Creates default configuration if none exists.
  Future<ContinuousTrackingConfig> getConfig({required String userId});

  /// Update continuous tracking configuration
  Future<void> updateConfig(ContinuousTrackingConfig config);

  /// Enable continuous tracking for a user
  ///
  /// Sets isEnabled to true in the configuration.
  Future<void> enableContinuousTracking({required String userId});

  /// Disable continuous tracking for a user
  ///
  /// Sets isEnabled to false in the configuration and stops any active tracking.
  Future<void> disableContinuousTracking({required String userId});

  /// Update reset points for a user
  Future<void> updateResetPoints({
    required String userId,
    required List<String> resetPoints,
  });

  /// Update activity detection mode
  Future<void> updateActivityDetection({
    required String userId,
    required String mode,
  });

  // ============================================================
  // STATE MANAGEMENT
  // ============================================================

  /// Get current tracking state for a user
  ///
  /// Returns null if no state exists and createIfMissing is false.
  Future<ContinuousTrackingState?> getState({required String userId});

  /// Start continuous tracking
  ///
  /// Creates a new session and updates the tracking state to active.
  Future<void> startTracking({
    required String userId,
    required String sessionId,
  });

  /// Stop continuous tracking
  ///
  /// Updates the tracking state to inactive and clears session reference.
  Future<void> stopTracking({required String userId});

  /// Pause continuous tracking for a manual session
  ///
  /// Sets isPausedForManual to true, preserving the current session.
  Future<void> pauseForManualSession({required String userId});

  /// Resume continuous tracking after a manual session
  ///
  /// Sets isPausedForManual to false and optionally starts a new session.
  Future<void> resumeFromManualSession({
    required String userId,
    required String sessionId,
  });

  /// Update the detected activity for the current session
  Future<void> updateDetectedActivity({
    required String userId,
    required String? activity,
    required double? confidence,
  });

  /// Record that data was received (updates lastDataReceived)
  Future<void> recordDataReceived({required String userId});

  // ============================================================
  // ACTIVITY SEGMENTS
  // ============================================================

  /// Get all activity segments for a session
  Future<List<ActivitySegment>> getSessionSegments({required String sessionId});

  /// Add a new activity segment
  Future<void> addSegment(ActivitySegment segment);

  /// Update an existing activity segment
  Future<void> updateSegment(ActivitySegment segment);

  /// End the current ongoing segment
  Future<void> endCurrentSegment({
    required String sessionId,
    double? distanceMeters,
  });

  /// Delete all segments for a session
  Future<void> deleteSessionSegments({required String sessionId});
}
