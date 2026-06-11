import 'package:sqflite/sqflite.dart';
import '../../domain/health_data_type.dart';
import '../../../shared/database/database_helper.dart';

/// Data Access Object for health platform data (Health Connect/HealthKit)
/// Handles all database operations for the health_platform_data table
/// This stores historical/background data not tied to specific sessions
class HealthPlatformDataDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Insert a single health data point
  Future<void> insert(HealthDataPoint dataPoint) async {
    final db = await _dbHelper.database;
    await db.insert(
      'health_platform_data',
      dataPoint.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple health data points in a batch (more efficient)
  Future<void> insertBatch(List<HealthDataPoint> dataPoints) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final dataPoint in dataPoints) {
      batch.insert(
        'health_platform_data',
        dataPoint.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get health data by user and type within a date range
  Future<List<HealthDataPoint>> getByUserAndType(
    String userId,
    HealthDataType type,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'health_platform_data',
      where:
          'user_id = ? AND data_type = ? AND start_time >= ? AND end_time <= ?',
      whereArgs: [
        userId,
        type.toJson(),
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      ],
      orderBy: 'start_time ASC',
    );

    return results.map((json) => HealthDataPoint.fromJson(json)).toList();
  }

  /// Get all health data for a user within a date range
  Future<List<HealthDataPoint>> getByUserAndDateRange(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'health_platform_data',
      where: 'user_id = ? AND start_time >= ? AND end_time <= ?',
      whereArgs: [
        userId,
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      ],
      orderBy: 'start_time ASC',
    );

    return results.map((json) => HealthDataPoint.fromJson(json)).toList();
  }

  /// Get last sync time for a specific data type
  Future<DateTime?> getLastSyncTime(String userId, HealthDataType type) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'health_platform_data',
      columns: ['synced_at'],
      where: 'user_id = ? AND data_type = ?',
      whereArgs: [userId, type.toJson()],
      orderBy: 'synced_at DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      results.first['synced_at']! as int,
    );
  }

  /// Get daily steps for a specific date
  Future<int> getDailySteps(String userId, DateTime date) async {
    final startTime = DateTime(date.year, date.month, date.day);
    final endTime = startTime.add(const Duration(days: 1));

    final dataPoints = await getByUserAndType(
      userId,
      HealthDataType.steps,
      startTime,
      endTime,
    );

    int totalSteps = 0;
    for (final point in dataPoints) {
      final steps = point.intValue;
      if (steps != null) {
        totalSteps += steps;
      }
    }

    return totalSteps;
  }

  /// Get average heart rate for a date range
  Future<double?> getAverageHeartRate(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final dataPoints = await getByUserAndType(
      userId,
      HealthDataType.heartRate,
      startTime,
      endTime,
    );

    if (dataPoints.isEmpty) return null;

    double sum = 0;
    int count = 0;

    for (final point in dataPoints) {
      final hr = point.numericValue;
      if (hr != null) {
        sum += hr;
        count++;
      }
    }

    return count > 0 ? sum / count : null;
  }

  /// Get total distance for a date range
  Future<double> getTotalDistance(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final dataPoints = await getByUserAndType(
      userId,
      HealthDataType.distance,
      startTime,
      endTime,
    );

    double total = 0;
    for (final point in dataPoints) {
      final distance = point.numericValue;
      if (distance != null) {
        total += distance;
      }
    }

    return total;
  }

  /// Get total calories for a date range
  Future<double> getTotalCalories(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final dataPoints = await getByUserAndType(
      userId,
      HealthDataType.calories,
      startTime,
      endTime,
    );

    double total = 0;
    for (final point in dataPoints) {
      final calories = point.numericValue;
      if (calories != null) {
        total += calories;
      }
    }

    return total;
  }

  /// Get latest weight measurement
  Future<double?> getLatestWeight(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'health_platform_data',
      where: 'user_id = ? AND data_type = ?',
      whereArgs: [userId, HealthDataType.weight.toJson()],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    final point = HealthDataPoint.fromJson(results.first);
    return point.numericValue;
  }

  /// Get latest resting heart rate
  Future<int?> getLatestRestingHeartRate(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'health_platform_data',
      where: 'user_id = ? AND data_type = ?',
      whereArgs: [userId, HealthDataType.restingHeartRate.toJson()],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    final point = HealthDataPoint.fromJson(results.first);
    return point.numericValue?.round();
  }

  /// Get data by source app
  Future<List<HealthDataPoint>> getBySourceApp(
    String userId,
    String sourceApp,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'health_platform_data',
      where: 'user_id = ? AND source_app = ?',
      whereArgs: [userId, sourceApp],
      orderBy: 'start_time DESC',
    );

    return results.map((json) => HealthDataPoint.fromJson(json)).toList();
  }

  /// Delete health data older than a specific date (cleanup)
  Future<void> deleteOlderThan(DateTime cutoffDate) async {
    final db = await _dbHelper.database;
    await db.delete(
      'health_platform_data',
      where: 'end_time < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  /// Delete all health data for a user
  Future<void> deleteByUser(String userId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'health_platform_data',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Delete health data for a specific type
  Future<void> deleteByType(String userId, HealthDataType type) async {
    final db = await _dbHelper.database;
    await db.delete(
      'health_platform_data',
      where: 'user_id = ? AND data_type = ?',
      whereArgs: [userId, type.toJson()],
    );
  }

  /// Get count of health data points
  Future<int> getCount(String userId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM health_platform_data WHERE user_id = ?',
      [userId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get available data types for a user
  Future<List<HealthDataType>> getAvailableDataTypes(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      'SELECT DISTINCT data_type FROM health_platform_data WHERE user_id = ?',
      [userId],
    );

    return results
        .map((row) => HealthDataType.fromJson(row['data_type']! as String))
        .toList();
  }

  /// Delete all health platform data (for testing/reset)
  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    await db.delete('health_platform_data');
  }

  /// Get weekly summary (steps, distance, calories)
  Future<Map<String, dynamic>> getWeeklySummary(
    String userId,
    DateTime weekStart,
  ) async {
    final weekEnd = weekStart.add(const Duration(days: 7));

    final steps = await getDailySteps(userId, weekStart);
    final distance = await getTotalDistance(userId, weekStart, weekEnd);
    final calories = await getTotalCalories(userId, weekStart, weekEnd);

    return {
      'steps': steps,
      'distance': distance,
      'calories': calories,
      'weekStart': weekStart,
      'weekEnd': weekEnd,
    };
  }
}
