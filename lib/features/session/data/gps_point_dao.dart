import 'package:sqflite/sqflite.dart';
import 'package:benefitflutter/features/shared/database/database_helper.dart';
import 'package:benefitflutter/features/shared/utils/sqlite_type_converters.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';

/// Data Access Object for GPS tracking points
///
/// Provides CRUD operations for the gps_points table.
/// GPS points are captured during active tracking sessions and used to:
/// - Calculate distance using Haversine formula
/// - Calculate elevation gain/loss
/// - Display route on map (future feature)
///
/// Data retention:
/// GPS points are deleted after successful sync to server (see GpsTrackingConfig).
/// Use deleteBySessionId() after successful sync to free storage.
///
/// See: DATABASE.md for gps_points table schema
/// See: GpsTrackingConfig for retention settings
class GpsPointDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ===== CREATE =====

  /// Insert single GPS point
  ///
  /// Used for real-time GPS point storage during tracking.
  ///
  /// Example:
  /// ```dart
  /// final point = GpsPoint(
  ///   id: Uuid().v4(),
  ///   sessionId: sessionId,
  ///   latitude: 37.7749,
  ///   longitude: -122.4194,
  ///   timestamp: DateTime.now(),
  /// );
  /// await gpsPointDao.insert(point);
  /// ```
  ///
  /// Throws DatabaseException on failure
  Future<void> insert(GpsPoint point) async {
    final db = await _dbHelper.database;
    await db.insert('gps_points', _toMap(point));
  }

  /// Insert multiple GPS points in batch (more efficient)
  ///
  /// Use this when inserting multiple points at once (e.g., after reconnection).
  /// Significantly faster than multiple insert() calls.
  ///
  /// Example:
  /// ```dart
  /// final points = [point1, point2, point3];
  /// await gpsPointDao.insertBatch(points);
  /// ```
  ///
  /// Throws DatabaseException on failure
  Future<void> insertBatch(List<GpsPoint> points) async {
    if (points.isEmpty) return;

    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final point in points) {
      batch.insert('gps_points', _toMap(point));
    }

    await batch.commit(noResult: true);
  }

  // ===== READ =====

  /// Get all GPS points for a session
  ///
  /// Returns points ordered by timestamp (chronological order).
  /// Use this to calculate distance and display route.
  ///
  /// Example:
  /// ```dart
  /// final points = await gpsPointDao.findBySessionId(sessionId);
  /// final distance = DistanceCalculator.calculateTotalDistance(points);
  /// ```
  ///
  /// Returns empty list if no points found
  Future<List<GpsPoint>> findBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'gps_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return results.map((map) => _fromMap(map)).toList();
  }

  /// Get GPS points in time range for a session
  ///
  /// Returns points between startTime and endTime (inclusive).
  /// Useful for analyzing specific portions of a session.
  ///
  /// Example:
  /// ```dart
  /// final start = DateTime.now().subtract(Duration(hours: 1));
  /// final end = DateTime.now();
  /// final recentPoints = await gpsPointDao.findBySessionIdAndTimeRange(
  ///   sessionId, start, end
  /// );
  /// ```
  ///
  /// Returns empty list if no points found in range
  Future<List<GpsPoint>> findBySessionIdAndTimeRange(
    String sessionId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final db = await _dbHelper.database;
    final startMs = SqliteTypeConverters.dateTimeToSqlite(startTime);
    final endMs = SqliteTypeConverters.dateTimeToSqlite(endTime);

    final results = await db.query(
      'gps_points',
      where: 'session_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [sessionId, startMs, endMs],
      orderBy: 'timestamp ASC',
    );

    return results.map((map) => _fromMap(map)).toList();
  }

  /// Get last GPS point for a session
  ///
  /// Returns the most recent GPS point for a session.
  /// Useful for:
  /// - Calculating distance since last point
  /// - Determining if time/distance threshold met
  /// - Getting current position
  ///
  /// Example:
  /// ```dart
  /// final lastPoint = await gpsPointDao.findLastBySessionId(sessionId);
  /// if (lastPoint != null) {
  ///   final distance = currentPoint.distanceTo(lastPoint);
  ///   final shouldStore = distance >= minMetersBetweenPoints;
  /// }
  /// ```
  ///
  /// Returns null if no points found
  Future<GpsPoint?> findLastBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'gps_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Count GPS points for a session
  ///
  /// Returns the number of GPS points stored for a session.
  /// Useful for:
  /// - Data quality assessment
  /// - Storage usage estimation
  /// - Checking if GPS data exists
  ///
  /// Example:
  /// ```dart
  /// final count = await gpsPointDao.countBySessionId(sessionId);
  /// print('Session has $count GPS points');
  /// ```
  Future<int> countBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM gps_points WHERE session_id = ?',
      [sessionId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total number of GPS points in database
  ///
  /// Returns total count across all sessions.
  /// Useful for monitoring storage usage.
  ///
  /// Example:
  /// ```dart
  /// final totalPoints = await gpsPointDao.countAll();
  /// print('Database contains $totalPoints GPS points');
  /// ```
  Future<int> countAll() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM gps_points',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ===== DELETE =====

  /// Delete all GPS points for a session (after sync)
  ///
  /// Called after successful sync to server to free local storage.
  /// Session summary (distance, duration) is kept in sessions table.
  ///
  /// Example:
  /// ```dart
  /// // After successful sync
  /// await gpsPointDao.deleteBySessionId(sessionId);
  /// ```
  ///
  /// Returns number of rows deleted
  Future<int> deleteBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'gps_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Delete GPS points older than cutoff date (cleanup)
  ///
  /// Removes stale GPS points that failed to sync.
  /// Recommended to run periodically (e.g., monthly) to free storage.
  ///
  /// Example:
  /// ```dart
  /// // Delete GPS points older than 30 days
  /// final cutoff = DateTime.now().subtract(Duration(days: 30));
  /// final deleted = await gpsPointDao.deleteOlderThan(cutoff);
  /// print('Deleted $deleted stale GPS points');
  /// ```
  ///
  /// Returns number of rows deleted
  Future<int> deleteOlderThan(DateTime cutoffDate) async {
    final db = await _dbHelper.database;
    final cutoffMs = SqliteTypeConverters.dateTimeToSqlite(cutoffDate);

    return await db.delete(
      'gps_points',
      where: 'created_at < ?',
      whereArgs: [cutoffMs],
    );
  }

  /// Delete all GPS points (use with caution)
  ///
  /// Removes all GPS points from database.
  /// Only use for:
  /// - Testing/debugging
  /// - User-requested data wipe
  ///
  /// WARNING: This is irreversible. Unsent GPS data will be lost.
  ///
  /// Returns number of rows deleted
  Future<int> deleteAll() async {
    final db = await _dbHelper.database;
    return await db.delete('gps_points');
  }

  // ===== BATCH OPERATIONS =====

  /// Delete GPS points for multiple sessions
  ///
  /// Efficient batch deletion after syncing multiple sessions.
  ///
  /// Example:
  /// ```dart
  /// final syncedSessionIds = ['session1', 'session2', 'session3'];
  /// await gpsPointDao.deleteBySessions(syncedSessionIds);
  /// ```
  ///
  /// Returns number of rows deleted
  Future<int> deleteBySessions(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return 0;

    final db = await _dbHelper.database;
    final placeholders = List.filled(sessionIds.length, '?').join(',');

    return await db.delete(
      'gps_points',
      where: 'session_id IN ($placeholders)',
      whereArgs: sessionIds,
    );
  }

  // ===== UTILITY METHODS =====

  /// Get storage size estimate for session GPS points
  ///
  /// Returns approximate storage size in bytes.
  /// Calculation: count × average bytes per point (≈80 bytes)
  ///
  /// Example:
  /// ```dart
  /// final bytes = await gpsPointDao.getStorageSizeEstimate(sessionId);
  /// final kb = bytes / 1024;
  /// print('GPS data: ${kb.toStringAsFixed(1)} KB');
  /// ```
  Future<int> getStorageSizeEstimate(String sessionId) async {
    final count = await countBySessionId(sessionId);
    // Estimate: ~80 bytes per GPS point (including indexes)
    return count * 80;
  }

  /// Check if session has GPS data
  ///
  /// Quick check if any GPS points exist for a session.
  ///
  /// Example:
  /// ```dart
  /// final hasGps = await gpsPointDao.hasGpsData(sessionId);
  /// if (hasGps) {
  ///   // Display "View Route" button
  /// }
  /// ```
  Future<bool> hasGpsData(String sessionId) async {
    final count = await countBySessionId(sessionId);
    return count > 0;
  }

  // ===== CONVERSION METHODS =====

  /// Convert database map to GpsPoint object
  GpsPoint _fromMap(Map<String, dynamic> map) {
    return GpsPoint(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: map['altitude'] != null
          ? (map['altitude'] as num).toDouble()
          : null,
      accuracyMeters: map['accuracy_meters'] != null
          ? (map['accuracy_meters'] as num).toDouble()
          : null,
      speedMetersPerSecond: map['speed_meters_per_second'] != null
          ? (map['speed_meters_per_second'] as num).toDouble()
          : null,
      timestamp: SqliteTypeConverters.dateTimeFromSqlite(
        map['timestamp'] as int,
      ),
      createdAt: SqliteTypeConverters.dateTimeFromSqlite(
        map['created_at'] as int,
      ),
    );
  }

  /// Convert GpsPoint object to database map
  Map<String, dynamic> _toMap(GpsPoint point) {
    return {
      'id': point.id,
      'session_id': point.sessionId,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'altitude': point.altitude,
      'accuracy_meters': point.accuracyMeters,
      'speed_meters_per_second': point.speedMetersPerSecond,
      'timestamp': SqliteTypeConverters.dateTimeToSqlite(point.timestamp),
      'created_at': SqliteTypeConverters.dateTimeToSqlite(point.createdAt),
    };
  }
}
