import 'package:flutter/foundation.dart';
import 'package:benefitflutter/features/wearable_integration/data/services/health_sync_service.dart';
import 'package:benefitflutter/features/session/domain/session.dart';

/// Provider for health platform (Health Connect / HealthKit) integration
/// Manages connection status, syncing, and data retrieval
class HealthPlatformProvider extends ChangeNotifier {
  final HealthSyncService _syncService;

  HealthPlatformProvider({HealthSyncService? syncService})
    : _syncService = syncService ?? HealthSyncService();

  bool _isConnected = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _errorMessage;
  String? _currentUserId;

  // ========================================
  // GETTERS
  // ========================================

  /// Whether health platform is connected (permissions granted)
  bool get isConnected => _isConnected;

  /// Whether a sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Last successful sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Current error message (null if no error)
  String? get errorMessage => _errorMessage;

  /// Whether health platform is available on this device
  Future<bool> get isAvailable => _syncService.isAvailable();

  /// Check if Health Connect is installed (Android only)
  Future<bool> isHealthConnectInstalled() async {
    return await _syncService.isHealthConnectInstalled();
  }

  // ========================================
  // CONNECTION
  // ========================================

  /// Initialize and check connection status
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _checkConnectionStatus();
  }

  /// Check if health platform permissions are granted
  Future<void> _checkConnectionStatus() async {
    try {
      _isConnected = await _syncService.hasPermissions();
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to check connection status: $e');
    }
  }

  /// Request permissions and connect to health platform
  Future<bool> connect() async {
    try {
      _clearError();
      notifyListeners();

      final granted = await _syncService.requestPermissions();

      if (granted) {
        _isConnected = true;
        _clearError();
        notifyListeners();

        // Trigger initial sync after successful connection
        if (_currentUserId != null) {
          await syncAll(_currentUserId!);
        }
      } else {
        _isConnected = false;
        _setError(
          'Health platform permissions were denied. Please grant permissions in your device settings.',
        );
      }

      return granted;
    } catch (e) {
      _isConnected = false;
      // Extract the clean error message
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring('Exception: '.length);
      }
      _setError(errorMsg);
      return false;
    }
  }

  /// Disconnect from health platform (clears connection state)
  void disconnect() {
    _isConnected = false;
    _lastSyncTime = null;
    _clearError();
    notifyListeners();
  }

  // ========================================
  // SYNCING
  // ========================================

  /// Sync all health data for the past N days
  Future<bool> syncAll(String userId, {int daysBack = 7}) async {
    if (!_isConnected) {
      _setError('Health platform not connected');
      return false;
    }

    if (_isSyncing) {
      debugPrint('[HealthPlatformProvider] Sync already in progress');
      return false;
    }

    _isSyncing = true;
    _clearError();
    notifyListeners();

    try {
      final success = await _syncService.syncAll(userId, daysBack: daysBack);

      if (success) {
        _lastSyncTime = DateTime.now();
        _clearError();
      } else {
        _setError('Sync completed with errors');
      }

      return success;
    } catch (e) {
      _setError('Sync failed: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sync only steps data
  Future<void> syncSteps(String userId, {int daysBack = 7}) async {
    if (!_isConnected) return;

    final endTime = DateTime.now();
    final startTime = endTime.subtract(Duration(days: daysBack));

    try {
      await _syncService.syncSteps(userId, startTime, endTime);
      _lastSyncTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      _setError('Failed to sync steps: $e');
    }
  }

  /// Sync only heart rate data
  Future<void> syncHeartRate(String userId, {int daysBack = 7}) async {
    if (!_isConnected) return;

    final endTime = DateTime.now();
    final startTime = endTime.subtract(Duration(days: daysBack));

    try {
      await _syncService.syncHeartRate(userId, startTime, endTime);
      _lastSyncTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      _setError('Failed to sync heart rate: $e');
    }
  }

  // ========================================
  // SESSION ENRICHMENT
  // ========================================

  /// Enrich a session with health platform data
  Future<Session?> enrichSession(Session session) async {
    if (!_isConnected) return null;

    try {
      return await _syncService.enrichSession(session);
    } catch (e) {
      _setError('Failed to enrich session: $e');
      return null;
    }
  }

  // ========================================
  // DATA RETRIEVAL
  // ========================================

  /// Get daily steps for a specific date
  Future<int> getDailySteps(String userId, DateTime date) async {
    try {
      return await _syncService.getDailySteps(userId, date);
    } catch (e) {
      _setError('Failed to get daily steps: $e');
      return 0;
    }
  }

  /// Get average heart rate for today
  Future<double?> getTodayAverageHeartRate(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      return await _syncService.getAverageHeartRate(userId, startOfDay, now);
    } catch (e) {
      _setError('Failed to get heart rate: $e');
      return null;
    }
  }

  /// Get latest weight measurement
  Future<double?> getLatestWeight(String userId) async {
    try {
      return await _syncService.getLatestWeight(userId);
    } catch (e) {
      _setError('Failed to get weight: $e');
      return null;
    }
  }

  /// Get latest resting heart rate
  Future<int?> getLatestRestingHeartRate(String userId) async {
    try {
      return await _syncService.getLatestRestingHeartRate(userId);
    } catch (e) {
      _setError('Failed to get resting heart rate: $e');
      return null;
    }
  }

  /// Get weekly summary
  Future<Map<String, dynamic>> getWeeklySummary(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      return await _syncService.getWeeklySummary(userId, weekStart);
    } catch (e) {
      _setError('Failed to get weekly summary: $e');
      return {'steps': 0, 'distance': 0.0, 'calories': 0.0};
    }
  }

  // ========================================
  // CLEANUP
  // ========================================

  /// Clean up old health data (older than 90 days)
  Future<void> cleanupOldData() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      await _syncService.cleanupOldData(cutoffDate);
    } catch (e) {
      _setError('Failed to cleanup old data: $e');
    }
  }

  // ========================================
  // ERROR HANDLING
  // ========================================

  void _setError(String message) {
    _errorMessage = message;
    debugPrint('[HealthPlatformProvider] Error: $message');
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Clear current error message
  void clearError() {
    _clearError();
    notifyListeners();
  }

  // ========================================
  // LIFECYCLE
  // ========================================

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}
