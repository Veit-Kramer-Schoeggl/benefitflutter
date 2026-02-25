import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/health_data_type.dart';
import '../../domain/repositories/wearable_repository.dart';
import '../sources/health_connect_source.dart';
import '../sources/healthkit_source.dart';
import '../daos/health_platform_data_dao.dart';
import '../../../session/domain/session.dart';

/// Service to sync health data from Health Connect/HealthKit
/// Handles background syncing and enriching sessions with health data
class HealthSyncService {
  final HealthPlatformDataDao _healthDao = HealthPlatformDataDao();
  late final WearableRepository _healthSource;

  HealthSyncService() {
    // Initialize platform-specific health source
    if (Platform.isAndroid) {
      _healthSource = HealthConnectSource();
    } else if (Platform.isIOS) {
      _healthSource = HealthKitSource();
    } else {
      throw UnsupportedError('Health platform integration only supported on Android/iOS');
    }
  }

  // ========================================
  // CONNECTION & PERMISSIONS
  // ========================================

  /// Check if health platform is available
  Future<bool> isAvailable() async {
    try {
      final devices = await _healthSource.getAvailableDevices();
      return devices.isNotEmpty;
    } catch (e) {
      _log('Error checking availability: $e');
      return false;
    }
  }

  /// Check if Health Connect is installed (Android only)
  Future<bool> isHealthConnectInstalled() async {
    if (!Platform.isAndroid) return false;

    try {
      final source = _healthSource;
      if (source is HealthConnectSource) {
        return await source.isHealthConnectInstalled();
      }
      return false;
    } catch (e) {
      _log('Error checking Health Connect installation: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      return await _healthSource.hasPermissions();
    } catch (e) {
      _log('Error checking permissions: $e');
      return false;
    }
  }

  /// Request health platform permissions
  /// Throws an exception if Health Connect/HealthKit is not available
  Future<bool> requestPermissions() async {
    try {
      return await _healthSource.requestPermissions();
    } catch (e) {
      _log('Error requesting permissions: $e');
      // Check if the error indicates Health Connect is not installed
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('permission launcher not found') ||
          errorMsg.contains('not found') ||
          errorMsg.contains('not installed')) {
        throw Exception('Health Connect is not installed. Please install it from the Play Store to sync health data.');
      }
      // Rethrow other errors
      rethrow;
    }
  }

  /// Connect to health platform (request permissions if needed)
  Future<bool> connect() async {
    final hasPerms = await hasPermissions();
    if (hasPerms) return true;

    return await requestPermissions();
  }

  // ========================================
  // DATA SYNCING
  // ========================================

  /// Sync all health data for the past N days
  /// Returns true if sync was successful
  Future<bool> syncAll(String userId, {int daysBack = 7}) async {
    try {
      final endTime = DateTime.now();
      final startTime = endTime.subtract(Duration(days: daysBack));

      // Sync all data types
      await syncSteps(userId, startTime, endTime);
      await syncHeartRate(userId, startTime, endTime);
      await syncDistance(userId, startTime, endTime);
      await syncCalories(userId, startTime, endTime);
      await syncWeight(userId, startTime, endTime);
      await syncRestingHeartRate(userId, startTime, endTime);

      _log('Successfully synced all health data for $daysBack days');
      return true;
    } catch (e) {
      _log('Error syncing all health data: $e');
      return false;
    }
  }

  /// Sync steps data
  Future<void> syncSteps(String userId, DateTime startTime, DateTime endTime) async {
    try {
      final dataPoints = await _healthSource.getHistoricalData(
        HealthDataType.steps,
        startTime,
        endTime,
      );

      if (dataPoints.isEmpty) {
        _log('No steps data to sync');
        return;
      }

      // Update userId for all data points
      final updatedPoints = dataPoints.map((p) => p.copyWith(userId: userId)).toList();

      await _healthDao.insertBatch(updatedPoints);
      _log('Synced ${dataPoints.length} steps data points');
    } catch (e) {
      _log('Error syncing steps: $e');
    }
  }

  /// Sync heart rate data
  Future<void> syncHeartRate(String userId, DateTime startTime, DateTime endTime) async {
    try {
      final dataPoints = await _healthSource.getHistoricalData(
        HealthDataType.heartRate,
        startTime,
        endTime,
      );

      if (dataPoints.isEmpty) {
        _log('No heart rate data to sync');
        return;
      }

      final updatedPoints = dataPoints.map((p) => p.copyWith(userId: userId)).toList();
      await _healthDao.insertBatch(updatedPoints);
      _log('Synced ${dataPoints.length} heart rate data points');
    } catch (e) {
      _log('Error syncing heart rate: $e');
    }
  }

  /// Sync distance data
  Future<void> syncDistance(String userId, DateTime startTime, DateTime endTime) async {
    try {
      final dataPoints = await _healthSource.getHistoricalData(
        HealthDataType.distance,
        startTime,
        endTime,
      );

      if (dataPoints.isEmpty) {
        _log('No distance data to sync');
        return;
      }

      final updatedPoints = dataPoints.map((p) => p.copyWith(userId: userId)).toList();
      await _healthDao.insertBatch(updatedPoints);
      _log('Synced ${dataPoints.length} distance data points');
    } catch (e) {
      _log('Error syncing distance: $e');
    }
  }

  /// Sync calories data
  Future<void> syncCalories(String userId, DateTime startTime, DateTime endTime) async {
    try {
      final dataPoints = await _healthSource.getHistoricalData(
        HealthDataType.calories,
        startTime,
        endTime,
      );

      if (dataPoints.isEmpty) {
        _log('No calories data to sync');
        return;
      }

      final updatedPoints = dataPoints.map((p) => p.copyWith(userId: userId)).toList();
      await _healthDao.insertBatch(updatedPoints);
      _log('Synced ${dataPoints.length} calories data points');
    } catch (e) {
      _log('Error syncing calories: $e');
    }
  }

  /// Sync weight data
  Future<void> syncWeight(String userId, DateTime startTime, DateTime endTime) async {
    try {
      final dataPoints = await _healthSource.getHistoricalData(
        HealthDataType.weight,
        startTime,
        endTime,
      );

      if (dataPoints.isEmpty) {
        _log('No weight data to sync');
        return;
      }

      final updatedPoints = dataPoints.map((p) => p.copyWith(userId: userId)).toList();
      await _healthDao.insertBatch(updatedPoints);
      _log('Synced ${dataPoints.length} weight data points');
    } catch (e) {
      _log('Error syncing weight: $e');
    }
  }

  /// Sync resting heart rate data
  Future<void> syncRestingHeartRate(String userId, DateTime startTime, DateTime endTime) async {
    try {
      final dataPoints = await _healthSource.getHistoricalData(
        HealthDataType.restingHeartRate,
        startTime,
        endTime,
      );

      if (dataPoints.isEmpty) {
        _log('No resting heart rate data to sync');
        return;
      }

      final updatedPoints = dataPoints.map((p) => p.copyWith(userId: userId)).toList();
      await _healthDao.insertBatch(updatedPoints);
      _log('Synced ${dataPoints.length} resting heart rate data points');
    } catch (e) {
      _log('Error syncing resting heart rate: $e');
    }
  }

  // ========================================
  // SESSION ENRICHMENT
  // ========================================

  /// Enrich a session with health platform data
  /// Returns an updated session with health data filled in
  Future<Session> enrichSession(Session session) async {
    if (session.endTime == null) {
      _log('Cannot enrich active session');
      return session;
    }

    try {
      // Get health data for session timeframe
      final startTime = session.startTime;
      final endTime = session.endTime!;

      // Fetch relevant data
      final avgHR = await _healthDao.getAverageHeartRate(session.userId, startTime, endTime);
      final steps = await _healthDao.getDailySteps(session.userId, startTime);
      final distance = await _healthDao.getTotalDistance(session.userId, startTime, endTime);
      final calories = await _healthDao.getTotalCalories(session.userId, startTime, endTime);

      // Update session with enriched data
      return session.copyWith(
        avgHeartRate: avgHR?.round(),
        totalSteps: steps > 0 ? steps : null,
        distanceMeters: distance > 0 ? distance : session.distanceMeters,
        caloriesBurned: calories > 0 ? calories : null,
        hasWearableData: avgHR != null || steps > 0 || distance > 0,
      );
    } catch (e) {
      _log('Error enriching session: $e');
      return session;
    }
  }

  // ========================================
  // DATA RETRIEVAL
  // ========================================

  /// Get daily steps for a specific date
  Future<int> getDailySteps(String userId, DateTime date) async {
    try {
      return await _healthDao.getDailySteps(userId, date);
    } catch (e) {
      _log('Error getting daily steps: $e');
      return 0;
    }
  }

  /// Get average heart rate for a date range
  Future<double?> getAverageHeartRate(String userId, DateTime startTime, DateTime endTime) async {
    try {
      return await _healthDao.getAverageHeartRate(userId, startTime, endTime);
    } catch (e) {
      _log('Error getting average heart rate: $e');
      return null;
    }
  }

  /// Get latest weight measurement
  Future<double?> getLatestWeight(String userId) async {
    try {
      return await _healthDao.getLatestWeight(userId);
    } catch (e) {
      _log('Error getting latest weight: $e');
      return null;
    }
  }

  /// Get latest resting heart rate
  Future<int?> getLatestRestingHeartRate(String userId) async {
    try {
      return await _healthDao.getLatestRestingHeartRate(userId);
    } catch (e) {
      _log('Error getting latest resting heart rate: $e');
      return null;
    }
  }

  /// Get weekly summary (steps, distance, calories)
  Future<Map<String, dynamic>> getWeeklySummary(String userId, DateTime weekStart) async {
    try {
      return await _healthDao.getWeeklySummary(userId, weekStart);
    } catch (e) {
      _log('Error getting weekly summary: $e');
      return {
        'steps': 0,
        'distance': 0.0,
        'calories': 0.0,
        'weekStart': weekStart,
        'weekEnd': weekStart.add(const Duration(days: 7)),
      };
    }
  }

  // ========================================
  // CLEANUP
  // ========================================

  /// Delete health data older than specified date
  Future<void> cleanupOldData(DateTime cutoffDate) async {
    try {
      await _healthDao.deleteOlderThan(cutoffDate);
      _log('Cleaned up health data older than $cutoffDate');
    } catch (e) {
      _log('Error cleaning up old data: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _healthSource.dispose();
  }

  // ========================================
  // HELPERS
  // ========================================

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[HealthSyncService] $message');
    }
  }
}
