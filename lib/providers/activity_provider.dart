import 'package:benefitflutter/core/logging/app_logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_state.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_manager.dart';
import 'package:benefitflutter/features/session/data/gps_point_dao.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/session/utils/distance_calculator.dart';
import 'package:benefitflutter/core/config/gps_tracking_config.dart';
import 'package:benefitflutter/features/wearable_integration/data/sources/ble_data_source.dart';
import 'package:benefitflutter/features/wearable_integration/domain/sensor_data_point.dart';
import 'package:benefitflutter/features/wearable_integration/domain/enums.dart';
import 'package:benefitflutter/features/wearable_integration/data/daos/session_biometric_data_dao.dart';

/// Provider for Activity screen state management
///
/// Manages manual tracking sessions with start/pause/resume/stop functionality.
/// Handles integration with continuous tracking sessions - ending continuous
/// when manual starts, and restarting continuous when manual ends.
///
/// State machine: IDLE → TRACKING → PAUSED → IDLE
class ActivityProvider extends ChangeNotifier {
  final SessionRepository _sessionRepository;
  final SensorManager _sensorManager;
  final GpsPointDao _gpsPointDao;
  final BleDataSource _bleDataSource;
  final SessionBiometricDataDao _biometricDao;

  // Core state
  TrackingState _trackingState = TrackingState.idle;
  ActivityType _selectedActivityType = ActivityType.running;

  // Session data
  Session? _currentSession;
  bool _wasContinuousActive = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  // GPS tracking state
  StreamSubscription<GpsPoint>? _gpsSubscription;
  double _currentDistance = 0.0;
  GpsPoint? _lastGpsPoint;
  DateTime? _lastGpsPointTime;
  final List<GpsPoint> _sessionGpsPoints = [];

  // Heart rate tracking state
  String? _heartRateDeviceId;
  StreamSubscription<SensorDataPoint>? _heartRateSubscription;
  int? _currentHeartRate;
  final List<int> _sessionHeartRates = [];

  // UI state
  bool _isLoading = false;
  String? _error;

  // User ID (set by UserProvider via ProxyProvider)
  String? _userId;

  ActivityProvider(
    this._sessionRepository, {
    String? userId,
    SensorManager? sensorManager,
    GpsPointDao? gpsPointDao,
    BleDataSource? bleDataSource,
    SessionBiometricDataDao? biometricDao,
  }) : _userId = userId,
       _sensorManager = sensorManager ?? SensorManager(),
       _gpsPointDao = gpsPointDao ?? GpsPointDao(),
       _bleDataSource = bleDataSource ?? BleDataSource(),
       _biometricDao = biometricDao ?? SessionBiometricDataDao();

  // ===== GETTERS =====

  /// Current tracking state (idle/tracking/paused)
  TrackingState get trackingState => _trackingState;

  /// Currently selected activity type
  ActivityType get selectedActivityType => _selectedActivityType;

  /// Elapsed time in seconds
  int get elapsedSeconds => _elapsedSeconds;

  /// Loading state
  bool get isLoading => _isLoading;

  /// Error message if any
  String? get error => _error;

  /// Whether there is an error
  bool get hasError => _error != null;

  /// Current distance in meters
  double get currentDistance => _currentDistance;

  /// Current heart rate (BPM)
  int? get currentHeartRate => _currentHeartRate;

  /// Whether heart rate monitoring is active
  bool get hasHeartRateMonitor => _heartRateDeviceId != null;

  // Convenience state checks
  bool get isIdle => _trackingState == TrackingState.idle;
  bool get isTracking => _trackingState == TrackingState.tracking;
  bool get isPaused => _trackingState == TrackingState.paused;

  /// Whether to show the stop button (visible when tracking or paused)
  bool get canShowStopButton => isTracking || isPaused;

  /// Current user ID
  String? get userId => _userId;

  // ===== USER ID MANAGEMENT =====

  /// Update user ID from UserProvider
  ///
  /// Called automatically via ProxyProvider when user changes.
  /// Completes any active session and resets state when user switches.
  void updateUserId(String? newUserId) {
    if (_userId != newUserId) {
      AppLogger.d(
        'ActivityProvider: User ID updated from $_userId to $newUserId',
      );

      // Complete active session before switching users
      if (_currentSession != null && _trackingState != TrackingState.idle) {
        _completeSessionOnUserChange();
      }

      // Reset all session state when user changes
      _resetSessionState();

      _userId = newUserId;
      // Don't notify listeners here - ProxyProvider handles rebuilds
    }
  }

  /// Complete the current session when user logs out or switches
  Future<void> _completeSessionOnUserChange() async {
    if (_currentSession == null) return;

    AppLogger.d('ActivityProvider: Completing session on user change');

    try {
      _stopTimer();
      await _gpsSubscription?.cancel();
      await _heartRateSubscription?.cancel();
      await _sensorManager.stopSession();

      final now = DateTime.now();
      final hrStats = _calculateHeartRateStats();

      final completedSession = Session(
        id: _currentSession!.id,
        userId: _currentSession!.userId,
        trackingMode: _currentSession!.trackingMode,
        activityType: _currentSession!.activityType,
        status: SessionStatus.completed,
        startTime: _currentSession!.startTime,
        endTime: now,
        durationSeconds: _elapsedSeconds,
        distanceMeters: _currentDistance,
        trackingDate: _currentSession!.trackingDate,
        createdAt: _currentSession!.createdAt,
        avgHeartRate: hrStats['avgHeartRate'],
        maxHeartRate: hrStats['maxHeartRate'],
        minHeartRate: hrStats['minHeartRate'],
        hasWearableData: _sessionHeartRates.isNotEmpty,
        connectedDeviceIds: _heartRateDeviceId != null
            ? [_heartRateDeviceId!]
            : null,
      );

      await _sessionRepository.updateSession(completedSession);
      AppLogger.d(
        'ActivityProvider: Session saved - Duration: $_elapsedSeconds sec',
      );
    } catch (e) {
      AppLogger.d(
        'ActivityProvider: Error completing session on user change - $e',
      );
    }
  }

  /// Reset all session state
  void _resetSessionState() {
    _stopTimer();
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;

    _trackingState = TrackingState.idle;
    _currentSession = null;
    _elapsedSeconds = 0;
    _currentDistance = 0.0;
    _sessionGpsPoints.clear();
    _lastGpsPoint = null;
    _lastGpsPointTime = null;
    _currentHeartRate = null;
    _sessionHeartRates.clear();
    _heartRateDeviceId = null;
    _wasContinuousActive = false;
    _error = null;
  }

  /// Formatted time string (HH:MM:SS)
  String get formattedTime {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ===== PUBLIC METHODS =====

  /// Start a new manual tracking session
  ///
  /// Process:
  /// 1. Check for active continuous sessions and end them
  /// 2. Create new manual session
  /// 3. Start timer
  /// 4. Start GPS and optional heart rate tracking
  Future<void> startSession({String? heartRateDeviceId}) async {
    // Guard: Only start from idle state
    if (_trackingState != TrackingState.idle) {
      AppLogger.d('ActivityProvider: Cannot start session - not in idle state');
      return;
    }

    // Guard: Must have authenticated user
    if (_userId == null) {
      AppLogger.d('ActivityProvider: Cannot start session - no user logged in');
      _error = 'Please log in to start tracking';
      notifyListeners();
      return;
    }

    _heartRateDeviceId = heartRateDeviceId;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // End any active continuous sessions
      await _endActiveContinuousSessions();

      // Create new manual session
      final now = DateTime.now();
      final session = Session(
        id: const Uuid().v4(),
        userId: _userId!,
        trackingMode: TrackingMode.manual,
        activityType: _selectedActivityType,
        status: SessionStatus.active,
        startTime: now,
        endTime: null,
        durationSeconds: 0,
        distanceMeters: 0.0,
        trackingDate: now,
        createdAt: now,
      );

      // Save to repository (local only, no sync until completed)
      _currentSession = await _sessionRepository.createSession(session);

      // Initialize tracking state
      _elapsedSeconds = 0;
      _currentDistance = 0.0;
      _sessionGpsPoints.clear();
      _currentHeartRate = null;
      _sessionHeartRates.clear();
      _trackingState = TrackingState.tracking;

      // Start timer
      _startTimer();

      // Start GPS tracking
      await _startGpsTracking();

      // Start heart rate tracking if device specified
      if (_heartRateDeviceId != null) {
        await _startHeartRateTracking();
      }

      _error = null;
      AppLogger.d(
        'ActivityProvider: Session started - ID: ${_currentSession!.id}',
      );
    } catch (e) {
      _error = 'Failed to start session: ${e.toString()}';
      _trackingState = TrackingState.idle;
      AppLogger.e('ActivityProvider: Start session error - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pause the current tracking session
  ///
  /// Stops the timer and updates session status to paused
  Future<void> pauseSession() async {
    // Guard: Only pause from tracking state
    if (_trackingState != TrackingState.tracking || _currentSession == null) {
      AppLogger.d(
        'ActivityProvider: Cannot pause - not tracking or no session',
      );
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Stop timer
      _stopTimer();

      // Update session status
      final updatedSession = Session(
        id: _currentSession!.id,
        userId: _currentSession!.userId,
        trackingMode: _currentSession!.trackingMode,
        activityType: _currentSession!.activityType,
        status: SessionStatus.paused,
        startTime: _currentSession!.startTime,
        endTime: null,
        durationSeconds: _elapsedSeconds,
        distanceMeters: _currentSession!.distanceMeters,
        trackingDate: _currentSession!.trackingDate,
        createdAt: _currentSession!.createdAt,
      );

      await _sessionRepository.updateSession(updatedSession);
      _currentSession = updatedSession;

      _trackingState = TrackingState.paused;
      _error = null;
      AppLogger.d('ActivityProvider: Session paused');
    } catch (e) {
      _error = 'Failed to pause session: ${e.toString()}';
      // Resume timer on error
      _startTimer();
      AppLogger.e('ActivityProvider: Pause error - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resume the paused tracking session
  ///
  /// Restarts the timer and updates session status to active
  Future<void> resumeSession() async {
    // Guard: Only resume from paused state
    if (_trackingState != TrackingState.paused || _currentSession == null) {
      AppLogger.d('ActivityProvider: Cannot resume - not paused or no session');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Update session status
      final updatedSession = Session(
        id: _currentSession!.id,
        userId: _currentSession!.userId,
        trackingMode: _currentSession!.trackingMode,
        activityType: _currentSession!.activityType,
        status: SessionStatus.active,
        startTime: _currentSession!.startTime,
        endTime: null,
        durationSeconds: _elapsedSeconds,
        distanceMeters: _currentSession!.distanceMeters,
        trackingDate: _currentSession!.trackingDate,
        createdAt: _currentSession!.createdAt,
      );

      await _sessionRepository.updateSession(updatedSession);
      _currentSession = updatedSession;

      _trackingState = TrackingState.tracking;

      // Restart timer
      _startTimer();

      _error = null;
      AppLogger.d('ActivityProvider: Session resumed');
    } catch (e) {
      _error = 'Failed to resume session: ${e.toString()}';
      _trackingState = TrackingState.paused;
      AppLogger.e('ActivityProvider: Resume error - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stop and complete the current tracking session
  ///
  /// Process:
  /// 1. Complete manual session (triggers sync)
  /// 2. If continuous was active before, restart it
  /// 3. Reset state to idle
  Future<void> stopSession() async {
    // Guard: Must have active session
    if (_currentSession == null || _trackingState == TrackingState.idle) {
      AppLogger.d('ActivityProvider: Cannot stop - no active session');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Stop timer
      _stopTimer();

      // Stop GPS tracking
      await _stopGpsTracking();

      // Stop heart rate tracking
      await _stopHeartRateTracking();

      final now = DateTime.now();

      // Calculate heart rate statistics
      final hrStats = _calculateHeartRateStats();

      // Complete the session with actual distance and heart rate data
      final completedSession = Session(
        id: _currentSession!.id,
        userId: _currentSession!.userId,
        trackingMode: _currentSession!.trackingMode,
        activityType: _currentSession!.activityType,
        status: SessionStatus.completed,
        startTime: _currentSession!.startTime,
        endTime: now,
        durationSeconds: _elapsedSeconds,
        distanceMeters: _currentDistance,
        trackingDate: _currentSession!.trackingDate,
        createdAt: _currentSession!.createdAt,
        avgHeartRate: hrStats['avgHeartRate'],
        maxHeartRate: hrStats['maxHeartRate'],
        minHeartRate: hrStats['minHeartRate'],
        hasWearableData: _sessionHeartRates.isNotEmpty,
        connectedDeviceIds: _heartRateDeviceId != null
            ? [_heartRateDeviceId!]
            : null,
      );

      // Atomically persist the completed session + its HR summary in one
      // transaction (sync runs after commit). On failure the catch below keeps
      // the session active — no false "stopped" state.
      final summary = _sessionHeartRates.isNotEmpty
          ? _buildSessionSummary(completedSession)
          : null;
      await _sessionRepository.finalizeSession(
        completedSession,
        summary: summary,
      );

      AppLogger.d(
        'ActivityProvider: Session completed - Duration: $_elapsedSeconds seconds, Distance: ${_currentDistance.toStringAsFixed(1)}m, HR Data Points: ${_sessionHeartRates.length}',
      );

      // Restart continuous session if it was active before
      if (_wasContinuousActive) {
        await _startContinuousSession();
      }

      // Reset state
      _currentSession = null;
      _elapsedSeconds = 0;
      _currentDistance = 0.0;
      _sessionGpsPoints.clear();
      _lastGpsPoint = null;
      _lastGpsPointTime = null;
      _currentHeartRate = null;
      _sessionHeartRates.clear();
      _heartRateDeviceId = null;
      _trackingState = TrackingState.idle;
      _wasContinuousActive = false;
      _error = null;
    } catch (e) {
      _error = 'Failed to stop session: ${e.toString()}';
      AppLogger.e('ActivityProvider: Stop session error - $e');
      // Keep current state on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select activity type (only works in idle state)
  void selectActivityType(ActivityType type) {
    // Guard: Only allow changing type when idle
    if (_trackingState != TrackingState.idle) {
      AppLogger.d(
        'ActivityProvider: Cannot change activity type while tracking',
      );
      return;
    }

    _selectedActivityType = type;
    notifyListeners();
    AppLogger.d(
      'ActivityProvider: Activity type selected - ${type.displayName}',
    );
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Find and complete all active continuous sessions
  ///
  /// Called before starting a manual session to ensure clean state
  Future<void> _endActiveContinuousSessions() async {
    if (_userId == null) return;

    try {
      // Get all sessions for user
      final allSessions = await _sessionRepository.getAllSessions(
        userId: _userId!,
      );

      // Filter for active continuous sessions
      final activeContinuous = allSessions.where(
        (session) =>
            session.status == SessionStatus.active &&
            session.trackingMode == TrackingMode.continuousDaily,
      );

      if (activeContinuous.isNotEmpty) {
        AppLogger.d(
          'ActivityProvider: Found ${activeContinuous.length} active continuous session(s)',
        );

        // Complete all active continuous sessions
        for (final session in activeContinuous) {
          final now = DateTime.now();
          final completedSession = Session(
            id: session.id,
            userId: session.userId,
            trackingMode: session.trackingMode,
            activityType: session.activityType,
            status: SessionStatus.completed,
            startTime: session.startTime,
            endTime: now,
            durationSeconds: now.difference(session.startTime).inSeconds,
            distanceMeters: session.distanceMeters ?? 0.0,
            trackingDate: session.trackingDate,
            createdAt: session.createdAt,
          );

          await _sessionRepository.updateSession(completedSession);
          AppLogger.d(
            'ActivityProvider: Completed continuous session - ID: ${session.id}',
          );
        }

        // Remember that continuous was active
        _wasContinuousActive = true;
      } else {
        _wasContinuousActive = false;
        AppLogger.d('ActivityProvider: No active continuous sessions found');
      }
    } catch (e) {
      AppLogger.e('ActivityProvider: Error ending continuous sessions - $e');
      // Don't fail manual session start if this fails
      _wasContinuousActive = false;
    }
  }

  /// Start a new continuous session
  ///
  /// Called after completing a manual session if continuous was previously active.
  /// Note: This is a placeholder for future continuous tracking module.
  Future<void> _startContinuousSession() async {
    if (_userId == null) return;

    try {
      final now = DateTime.now();

      // Create new continuous session
      final continuousSession = Session(
        id: const Uuid().v4(),
        userId: _userId!,
        trackingMode: TrackingMode.continuousDaily,
        activityType: ActivityType.walking, // Default for continuous
        status: SessionStatus.active,
        startTime: now,
        endTime: null,
        durationSeconds: null,
        distanceMeters: 0.0,
        trackingDate: now, // Track by date for continuous mode
        createdAt: now,
      );

      await _sessionRepository.createSession(continuousSession);
      AppLogger.d(
        'ActivityProvider: Continuous session restarted - ID: ${continuousSession.id}',
      );
    } catch (e) {
      AppLogger.e('ActivityProvider: Error restarting continuous session - $e');
      // Don't fail manual session completion if this fails
    }
  }

  /// Start the timer for tracking elapsed time
  ///
  /// Updates every second and notifies listeners
  void _startTimer() {
    _timer?.cancel(); // Ensure no duplicate timers

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
    });

    AppLogger.d('ActivityProvider: Timer started');
  }

  /// Stop the timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    AppLogger.d('ActivityProvider: Timer stopped');
  }

  // ===== GPS TRACKING METHODS =====

  /// Start GPS tracking for current session
  Future<void> _startGpsTracking() async {
    if (_currentSession == null) return;

    try {
      // Start sensor manager session
      final results = await _sensorManager.startSession(
        sessionId: _currentSession!.id,
        activityType: _selectedActivityType,
      );

      if (results['gps'] == true) {
        // Subscribe to GPS data stream
        _gpsSubscription = _sensorManager.gpsSensor.onDataStream.listen(
          _onGpsPoint,
          onError: (error) {
            AppLogger.e('ActivityProvider: GPS stream error - $error');
          },
        );

        AppLogger.d('ActivityProvider: GPS tracking started');
      } else {
        AppLogger.d(
          'ActivityProvider: Failed to start GPS - permission denied or unavailable',
        );
        _error = 'GPS unavailable. Distance tracking disabled.';
        notifyListeners();
      }
    } catch (e) {
      AppLogger.e('ActivityProvider: GPS tracking error - $e');
      _error = 'GPS error: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Stop GPS tracking
  Future<void> _stopGpsTracking() async {
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    await _sensorManager.stopSession();
    AppLogger.d('ActivityProvider: GPS tracking stopped');
  }

  /// Handle incoming GPS point
  Future<void> _onGpsPoint(GpsPoint point) async {
    if (_currentSession == null) {
      AppLogger.d('ActivityProvider: GPS point received but no active session');
      return;
    }

    AppLogger.d(
      'ActivityProvider: GPS point received - Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}, Acc: ${point.accuracyMeters?.toStringAsFixed(1)}m',
    );

    try {
      // Check if should store based on time/distance thresholds
      final shouldStore = _shouldStoreGpsPoint(point);

      if (shouldStore) {
        AppLogger.d('ActivityProvider: Storing GPS point (threshold met)');

        // Add to in-memory cache
        _sessionGpsPoints.add(point);
        _lastGpsPoint = point;
        _lastGpsPointTime = point.timestamp;

        // Persist to database
        await _gpsPointDao.insert(point);
        AppLogger.d('ActivityProvider: GPS point saved to database');

        // Recalculate distance
        _currentDistance = DistanceCalculator.calculateTotalDistance(
          _sessionGpsPoints,
        );

        // Update session with new distance
        if (_currentSession != null) {
          final updatedSession = Session(
            id: _currentSession!.id,
            userId: _currentSession!.userId,
            trackingMode: _currentSession!.trackingMode,
            activityType: _currentSession!.activityType,
            status: _currentSession!.status,
            startTime: _currentSession!.startTime,
            endTime: _currentSession!.endTime,
            durationSeconds: _currentSession!.durationSeconds,
            distanceMeters: _currentDistance,
            trackingDate: _currentSession!.trackingDate,
            createdAt: _currentSession!.createdAt,
          );
          _currentSession = updatedSession;
          await _sessionRepository.updateSession(updatedSession);
        }

        // Notify UI
        notifyListeners();

        AppLogger.d(
          'ActivityProvider: GPS point stored - Total points: ${_sessionGpsPoints.length}, Distance: ${_currentDistance.toStringAsFixed(1)}m',
        );
      } else {
        AppLogger.d('ActivityProvider: GPS point skipped (below threshold)');
      }
    } catch (e) {
      AppLogger.e('ActivityProvider: Error storing GPS point - $e');
    }
  }

  /// Check if GPS point should be stored
  bool _shouldStoreGpsPoint(GpsPoint point) {
    // First point always stored
    if (_lastGpsPoint == null || _lastGpsPointTime == null) {
      return true;
    }

    // Calculate distance from last point
    final distanceDiff = point.distanceTo(_lastGpsPoint!);

    // Use config to determine if should store
    return GpsTrackingConfig.shouldStorePoint(
      lastPointTime: _lastGpsPointTime!,
      distanceFromLastPoint: distanceDiff,
      isContinuousMode: false, // Manual session
    );
  }

  // ===== HEART RATE TRACKING METHODS =====

  /// Start heart rate tracking for current session
  Future<void> _startHeartRateTracking() async {
    if (_currentSession == null || _heartRateDeviceId == null) return;

    try {
      // Start streaming from BLE device
      await _bleDataSource.startStreaming(
        _heartRateDeviceId!,
        SensorType.heartRate,
      );

      // Subscribe to heart rate data stream
      final stream = _bleDataSource.getSensorStream(
        _heartRateDeviceId!,
        SensorType.heartRate,
      );
      if (stream != null) {
        _heartRateSubscription = stream.listen(
          _onHeartRatePoint,
          onError: (error) {
            AppLogger.e('ActivityProvider: Heart rate stream error - $error');
          },
        );

        AppLogger.d('ActivityProvider: Heart rate tracking started');
      } else {
        AppLogger.d('ActivityProvider: Failed to get heart rate stream');
      }
    } catch (e) {
      AppLogger.e('ActivityProvider: Heart rate tracking error - $e');
      _error = 'Heart rate error: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Stop heart rate tracking
  Future<void> _stopHeartRateTracking() async {
    await _heartRateSubscription?.cancel();
    _heartRateSubscription = null;

    if (_heartRateDeviceId != null) {
      try {
        await _bleDataSource.stopStreaming(
          _heartRateDeviceId!,
          SensorType.heartRate,
        );
      } catch (e) {
        AppLogger.e(
          'ActivityProvider: Error stopping heart rate tracking - $e',
        );
      }
    }

    AppLogger.d('ActivityProvider: Heart rate tracking stopped');
  }

  /// Handle incoming heart rate data point
  Future<void> _onHeartRatePoint(SensorDataPoint point) async {
    if (_currentSession == null) {
      AppLogger.d(
        'ActivityProvider: Heart rate received but no active session',
      );
      return;
    }

    final bpm = point.value.round();
    _currentHeartRate = bpm;
    _sessionHeartRates.add(bpm);

    AppLogger.d('ActivityProvider: Heart rate received - $bpm BPM');

    try {
      // Store biometric data point
      final dataPoint = SensorDataPoint(
        id: const Uuid().v4(),
        sessionId: _currentSession!.id,
        deviceId: _heartRateDeviceId,
        sensorType: SensorType.heartRate,
        value: bpm.toDouble(),
        timestamp: DateTime.now(),
      );

      await _biometricDao.insert(dataPoint);

      // Notify UI
      notifyListeners();
    } catch (e) {
      AppLogger.e('ActivityProvider: Error storing heart rate data - $e');
    }
  }

  /// Calculate heart rate statistics from session data
  Map<String, int?> _calculateHeartRateStats() {
    if (_sessionHeartRates.isEmpty) {
      return {'avgHeartRate': null, 'maxHeartRate': null, 'minHeartRate': null};
    }

    final sum = _sessionHeartRates.reduce((a, b) => a + b);
    final avg = (sum / _sessionHeartRates.length).round();
    final max = _sessionHeartRates.reduce((a, b) => a > b ? a : b);
    final min = _sessionHeartRates.reduce((a, b) => a < b ? a : b);

    return {'avgHeartRate': avg, 'maxHeartRate': max, 'minHeartRate': min};
  }

  /// Create session sensor summary with wearable data
  /// Build the per-session sensor summary. Persisted atomically with the
  /// session via SessionRepository.finalizeSession.
  SessionSensorSummary _buildSessionSummary(Session session) {
    final hrStats = _calculateHeartRateStats();
    return SessionSensorSummary(
      id: const Uuid().v4(),
      sessionId: session.id,
      avgHeartRate: hrStats['avgHeartRate']?.toDouble(),
      maxHeartRate: hrStats['maxHeartRate'],
      minHeartRate: hrStats['minHeartRate'],
      dataSources: _heartRateDeviceId != null
          ? ['ble:$_heartRateDeviceId']
          : null,
      createdAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _stopTimer();
    _gpsSubscription?.cancel();
    _heartRateSubscription?.cancel();
    _sensorManager.dispose();
    _bleDataSource.dispose();
    super.dispose();
    AppLogger.d('ActivityProvider: Disposed');
  }
}
