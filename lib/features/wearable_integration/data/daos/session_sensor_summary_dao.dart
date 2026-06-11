import 'package:sqflite/sqflite.dart';
import '../../domain/sensor_data_point.dart';
import '../../../shared/database/database_helper.dart';

/// Data Access Object for session sensor summaries
/// Handles all database operations for the session_sensor_summary table
/// These summaries are kept permanently, even after detailed readings are deleted
class SessionSensorSummaryDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Insert or update a session sensor summary
  Future<void> upsert(SessionSensorSummary summary) async {
    final db = await _dbHelper.database;
    await db.insert(
      'session_sensor_summary',
      summary.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get summary for a specific session
  Future<SessionSensorSummary?> getBySession(String sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return SessionSensorSummary.fromJson(results.first);
  }

  /// Check if a summary exists for a session
  Future<bool> exists(String sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      columns: ['id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  /// Delete summary for a session
  Future<void> deleteBySession(String sessionId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'session_sensor_summary',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Get all summaries (for reporting/analytics)
  Future<List<SessionSensorSummary>> getAll() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      orderBy: 'created_at DESC',
    );

    return results.map((json) => SessionSensorSummary.fromJson(json)).toList();
  }

  /// Get summaries within a date range (based on creation time)
  Future<List<SessionSensorSummary>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );

    return results.map((json) => SessionSensorSummary.fromJson(json)).toList();
  }

  /// Get summaries with heart rate data
  Future<List<SessionSensorSummary>> getWithHeartRateData() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      where: 'avg_heart_rate IS NOT NULL',
      orderBy: 'created_at DESC',
    );

    return results.map((json) => SessionSensorSummary.fromJson(json)).toList();
  }

  /// Get summaries with motion data
  Future<List<SessionSensorSummary>> getWithMotionData() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      where: 'total_steps IS NOT NULL OR avg_cadence IS NOT NULL',
      orderBy: 'created_at DESC',
    );

    return results.map((json) => SessionSensorSummary.fromJson(json)).toList();
  }

  /// Get count of summaries
  Future<int> getCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM session_sensor_summary',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get average heart rate across all sessions
  Future<double?> getAverageHeartRateAcrossSessions() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT AVG(avg_heart_rate) as overall_avg FROM session_sensor_summary '
      'WHERE avg_heart_rate IS NOT NULL',
    );

    if (result.isEmpty || result.first['overall_avg'] == null) return null;
    return (result.first['overall_avg']! as num).toDouble();
  }

  /// Get total steps across all sessions
  Future<int> getTotalStepsAcrossSessions() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(total_steps) as total FROM session_sensor_summary '
      'WHERE total_steps IS NOT NULL',
    );

    if (result.isEmpty || result.first['total'] == null) return 0;
    return (result.first['total']! as num).toInt();
  }

  /// Get total calories burned across all sessions
  Future<double> getTotalCaloriesAcrossSessions() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(calories_burned) as total FROM session_sensor_summary '
      'WHERE calories_burned IS NOT NULL',
    );

    if (result.isEmpty || result.first['total'] == null) return 0;
    return (result.first['total']! as num).toDouble();
  }

  /// Update specific fields of a summary (partial update)
  Future<void> updateFields(
    String sessionId,
    Map<String, dynamic> fields,
  ) async {
    final db = await _dbHelper.database;
    fields['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'session_sensor_summary',
      fields,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Delete all summaries (for testing/reset)
  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    await db.delete('session_sensor_summary');
  }

  /// Get sessions with highest average heart rate (top N)
  Future<List<SessionSensorSummary>> getTopByHeartRate(int limit) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      where: 'avg_heart_rate IS NOT NULL',
      orderBy: 'avg_heart_rate DESC',
      limit: limit,
    );

    return results.map((json) => SessionSensorSummary.fromJson(json)).toList();
  }

  /// Get sessions with most steps (top N)
  Future<List<SessionSensorSummary>> getTopBySteps(int limit) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      where: 'total_steps IS NOT NULL',
      orderBy: 'total_steps DESC',
      limit: limit,
    );

    return results.map((json) => SessionSensorSummary.fromJson(json)).toList();
  }

  /// Get sessions with most calories burned (top N)
  Future<List<SessionSensorSummary>> getTopByCalories(int limit) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'session_sensor_summary',
      where: 'calories_burned IS NOT NULL',
      orderBy: 'calories_burned DESC',
      limit: limit,
    );

    return results.map((json) => SessionSensorSummary.fromJson(json)).toList();
  }
}
