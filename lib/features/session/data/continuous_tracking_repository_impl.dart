import '../domain/continuous_tracking_config.dart';
import '../domain/continuous_tracking_state.dart';
import '../domain/activity_segment.dart';
import 'continuous_tracking_repository.dart';
import 'continuous_tracking_config_dao.dart';
import 'continuous_tracking_state_dao.dart';
import 'activity_segment_dao.dart';

/// Implementation of ContinuousTrackingRepository
///
/// Uses DAOs for database operations. Coordinates configuration,
/// state, and segment management for continuous tracking.
class ContinuousTrackingRepositoryImpl implements ContinuousTrackingRepository {
  final ContinuousTrackingConfigDao _configDao;
  final ContinuousTrackingStateDao _stateDao;
  final ActivitySegmentDao _segmentDao;

  ContinuousTrackingRepositoryImpl({
    required ContinuousTrackingConfigDao configDao,
    required ContinuousTrackingStateDao stateDao,
    required ActivitySegmentDao segmentDao,
  }) : _configDao = configDao,
       _stateDao = stateDao,
       _segmentDao = segmentDao;

  /// Factory constructor with default dependencies
  factory ContinuousTrackingRepositoryImpl.create() {
    return ContinuousTrackingRepositoryImpl(
      configDao: ContinuousTrackingConfigDao(),
      stateDao: ContinuousTrackingStateDao(),
      segmentDao: ActivitySegmentDao(),
    );
  }

  // ============================================================
  // CONFIGURATION
  // ============================================================

  @override
  Future<ContinuousTrackingConfig> getConfig({required String userId}) async {
    return await _configDao.getOrCreateDefault(userId);
  }

  @override
  Future<void> updateConfig(ContinuousTrackingConfig config) async {
    await _configDao.update(config);
  }

  @override
  Future<void> enableContinuousTracking({required String userId}) async {
    final config = await getConfig(userId: userId);
    final updated = config.copyWith(isEnabled: true);
    await _configDao.update(updated);
  }

  @override
  Future<void> disableContinuousTracking({required String userId}) async {
    final config = await getConfig(userId: userId);
    final updated = config.copyWith(isEnabled: false);
    await _configDao.update(updated);

    // Also stop any active tracking
    await stopTracking(userId: userId);
  }

  @override
  Future<void> updateResetPoints({
    required String userId,
    required List<String> resetPoints,
  }) async {
    final config = await getConfig(userId: userId);
    final updated = config.copyWith(resetPoints: resetPoints);
    await _configDao.update(updated);
  }

  @override
  Future<void> updateActivityDetection({
    required String userId,
    required String mode,
  }) async {
    final config = await getConfig(userId: userId);
    final updated = config.copyWith(activityDetection: mode);
    await _configDao.update(updated);
  }

  // ============================================================
  // STATE MANAGEMENT
  // ============================================================

  @override
  Future<ContinuousTrackingState?> getState({required String userId}) async {
    return await _stateDao.findByUserId(userId);
  }

  @override
  Future<void> startTracking({
    required String userId,
    required String sessionId,
  }) async {
    await _stateDao.setActive(userId, sessionId);
  }

  @override
  Future<void> stopTracking({required String userId}) async {
    await _stateDao.setInactive(userId);
  }

  @override
  Future<void> pauseForManualSession({required String userId}) async {
    await _stateDao.setPausedForManual(userId, true);
  }

  @override
  Future<void> resumeFromManualSession({
    required String userId,
    required String sessionId,
  }) async {
    // Get current state
    final state = await _stateDao.getOrCreateDefault(userId);

    // Update state with new session and clear pause flag
    final updated = state.copyWith(
      isActive: true,
      isPausedForManual: false,
      currentSessionId: sessionId,
      startedAt: DateTime.now(),
      lastDataReceived: DateTime.now(),
    );
    await _stateDao.update(updated);
  }

  @override
  Future<void> updateDetectedActivity({
    required String userId,
    required String? activity,
    required double? confidence,
  }) async {
    await _stateDao.updateDetectedActivity(userId, activity, confidence);
  }

  @override
  Future<void> recordDataReceived({required String userId}) async {
    await _stateDao.updateLastDataReceived(userId);
  }

  // ============================================================
  // ACTIVITY SEGMENTS
  // ============================================================

  @override
  Future<List<ActivitySegment>> getSessionSegments({
    required String sessionId,
  }) async {
    return await _segmentDao.findBySessionId(sessionId);
  }

  @override
  Future<void> addSegment(ActivitySegment segment) async {
    await _segmentDao.insert(segment);
  }

  @override
  Future<void> updateSegment(ActivitySegment segment) async {
    await _segmentDao.update(segment);
  }

  @override
  Future<void> endCurrentSegment({
    required String sessionId,
    double? distanceMeters,
  }) async {
    final ongoing = await _segmentDao.findOngoingBySessionId(sessionId);
    if (ongoing != null) {
      await _segmentDao.endSegment(ongoing.id, distanceMeters: distanceMeters);
    }
  }

  @override
  Future<void> deleteSessionSegments({required String sessionId}) async {
    await _segmentDao.deleteBySessionId(sessionId);
  }
}
