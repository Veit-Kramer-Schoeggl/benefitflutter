import 'package:sqflite/sqflite.dart';
import '../../domain/sensor_data_point.dart';
import '../../domain/enums.dart';
import '../../../shared/database/database_helper.dart';

/// Data Access Object for biometric sensor data (HR, HRV, SpO2, temperature)
/// Handles all database operations for the session_biometric_data table
class SessionBiometricDataDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Insert a single biometric data point
  Future<void> insert(SensorDataPoint dataPoint) async {
    if (!dataPoint.isBiometric) {
      throw ArgumentError('Only biometric data points can be inserted here');
    }

    final db = await _dbHelper.database;
    await db.insert(
      'session_biometric_data',
      dataPoint.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple biometric data points in a batch (more efficient)
  Future<void> insertBatch(List<SensorDataPoint> dataPoints) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final dataPoint in dataPoints) {
      if (!dataPoint.isBiometric) {
        throw ArgumentError('Only biometric data points can be inserted here');
      }
      batch.insert(
        'session_biometric_data',
        dataPoint.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all biometric data for a session
  Future<List<SensorDataPoint>> getBySession(String sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_biometric_data',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return results.map((json) => SensorDataPoint.fromJson(json)).toList();
  }

  /// Get biometric data by sensor type for a session
  Future<List<SensorDataPoint>> getBySensorType(
    String sessionId,
    SensorType sensorType,
  ) async {
    if (!sensorType.isBiometric) {
      throw ArgumentError('Only biometric sensor types are supported');
    }

    final db = await _dbHelper.database;
    final results = await db.query(
      'session_biometric_data',
      where: 'session_id = ? AND sensor_type = ?',
      whereArgs: [sessionId, sensorType.toJson()],
      orderBy: 'timestamp ASC',
    );

    return results.map((json) => SensorDataPoint.fromJson(json)).toList();
  }

  /// Get biometric data within a time range
  Future<List<SensorDataPoint>> getByTimeRange(
    String sessionId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_biometric_data',
      where: 'session_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        sessionId,
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp ASC',
    );

    return results.map((json) => SensorDataPoint.fromJson(json)).toList();
  }

  /// Get count of data points for a session
  Future<int> getCountBySession(String sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM session_biometric_data WHERE session_id = ?',
      [sessionId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get latest biometric reading for a session and sensor type
  Future<SensorDataPoint?> getLatest(
    String sessionId,
    SensorType sensorType,
  ) async {
    if (!sensorType.isBiometric) {
      throw ArgumentError('Only biometric sensor types are supported');
    }

    final db = await _dbHelper.database;
    final results = await db.query(
      'session_biometric_data',
      where: 'session_id = ? AND sensor_type = ?',
      whereArgs: [sessionId, sensorType.toJson()],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return SensorDataPoint.fromJson(results.first);
  }

  /// Delete all biometric data for a session (cleanup after sync)
  Future<void> deleteBySession(String sessionId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'session_biometric_data',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Delete biometric data older than a specific date (cleanup)
  Future<void> deleteOlderThan(DateTime cutoffDate) async {
    final db = await _dbHelper.database;
    await db.delete(
      'session_biometric_data',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  /// Get average value for a sensor type in a session
  Future<double?> getAverage(String sessionId, SensorType sensorType) async {
    if (!sensorType.isBiometric) {
      throw ArgumentError('Only biometric sensor types are supported');
    }

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT AVG(value) as avg_value FROM session_biometric_data '
      'WHERE session_id = ? AND sensor_type = ?',
      [sessionId, sensorType.toJson()],
    );

    if (result.isEmpty || result.first['avg_value'] == null) return null;
    return (result.first['avg_value']! as num).toDouble();
  }

  /// Get min/max values for a sensor type in a session
  Future<Map<String, double?>> getMinMax(
    String sessionId,
    SensorType sensorType,
  ) async {
    if (!sensorType.isBiometric) {
      throw ArgumentError('Only biometric sensor types are supported');
    }

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT MIN(value) as min_value, MAX(value) as max_value '
      'FROM session_biometric_data '
      'WHERE session_id = ? AND sensor_type = ?',
      [sessionId, sensorType.toJson()],
    );

    if (result.isEmpty) {
      return {'min': null, 'max': null};
    }

    return {
      'min': result.first['min_value'] != null
          ? (result.first['min_value']! as num).toDouble()
          : null,
      'max': result.first['max_value'] != null
          ? (result.first['max_value']! as num).toDouble()
          : null,
    };
  }

  /// Get all heart rate readings for a session (convenience method)
  Future<List<SensorDataPoint>> getHeartRateData(String sessionId) async {
    return getBySensorType(sessionId, SensorType.heartRate);
  }

  /// Delete all biometric data (for testing/reset)
  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    await db.delete('session_biometric_data');
  }
}
