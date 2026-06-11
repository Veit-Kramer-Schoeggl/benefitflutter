import 'package:sqflite/sqflite.dart';
import '../domain/session.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/utils/sqlite_type_converters.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

/// Data Access Object for Session entity
///
/// Handles pure CRUD operations for the sessions table
/// Includes specialized queries for active sessions and user filtering
class SessionDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Find session by ID
  Future<Session?> findById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find sessions by user ID with optional limit and sorting
  Future<List<Session>> findByUserId(
    String userId, {
    int? limit,
    bool sortDesc = true,
  }) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_time ${sortDesc ? 'DESC' : 'ASC'}',
      limit: limit,
    );

    return results.map((map) => _fromMap(map)).toList();
  }

  /// Find active sessions (for Activity screen)
  Future<List<Session>> findActive() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sessions',
      where: 'status = ?',
      whereArgs: [SessionStatus.active.toJson()],
    );

    return results.map((map) => _fromMap(map)).toList();
  }

  /// Find sessions by status
  Future<List<Session>> findByStatus(
    String userId,
    SessionStatus status,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sessions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, status.toJson()],
      orderBy: 'start_time DESC',
    );

    return results.map((map) => _fromMap(map)).toList();
  }

  /// Find sessions by activity type
  Future<List<Session>> findByActivityType(
    String userId,
    ActivityType activityType,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sessions',
      where: 'user_id = ? AND activity_type = ?',
      whereArgs: [userId, activityType.toJson()],
      orderBy: 'start_time DESC',
    );

    return results.map((map) => _fromMap(map)).toList();
  }

  /// Find sessions in date range
  Future<List<Session>> findByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbHelper.database;
    final startMs = SqliteTypeConverters.dateTimeToSqlite(startDate);
    final endMs = SqliteTypeConverters.dateTimeToSqlite(endDate);

    final results = await db.query(
      'sessions',
      where: 'user_id = ? AND start_time >= ? AND start_time <= ?',
      whereArgs: [userId, startMs, endMs],
      orderBy: 'start_time DESC',
    );

    return results.map((map) => _fromMap(map)).toList();
  }

  /// Insert new session
  Future<void> insert(Session session) async {
    final db = await _dbHelper.database;
    await db.insert(
      'sessions',
      _toMap(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing session
  Future<void> update(Session session, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _dbHelper.database;
    await db.update(
      'sessions',
      _toMap(session),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Delete session by ID
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  /// Convert database map to Session model
  Session _fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      trackingMode: TrackingMode.fromJson(map['tracking_mode'] as String),
      activityType: ActivityType.fromJson(map['activity_type'] as String),
      status: SessionStatus.fromJson(map['status'] as String),
      startTime: SqliteTypeConverters.dateTimeFromSqlite(
        map['start_time'] as int,
      ),
      endTime: SqliteTypeConverters.nullableDateTimeFromSqlite(
        map['end_time'] as int?,
      ),
      durationSeconds: map['duration_seconds'] as int?,
      distanceMeters: map['distance_meters'] != null
          ? (map['distance_meters'] as num).toDouble()
          : null,
      trackingDate: SqliteTypeConverters.nullableDateTimeFromSqlite(
        map['tracking_date'] as int?,
      ),
      createdAt: SqliteTypeConverters.dateTimeFromSqlite(
        map['created_at'] as int,
      ),
    );
  }

  /// Convert Session model to database map
  Map<String, dynamic> _toMap(Session session) {
    final now = DateTime.now();
    return {
      'id': session.id,
      'user_id': session.userId,
      'tracking_mode': session.trackingMode.toJson(),
      'activity_type': session.activityType.toJson(),
      'status': session.status.toJson(),
      'start_time': SqliteTypeConverters.dateTimeToSqlite(session.startTime),
      'end_time': SqliteTypeConverters.nullableDateTimeToSqlite(
        session.endTime,
      ),
      'duration_seconds': session.durationSeconds,
      'distance_meters': session.distanceMeters,
      'tracking_date': SqliteTypeConverters.nullableDateTimeToSqlite(
        session.trackingDate,
      ),
      'created_at': SqliteTypeConverters.dateTimeToSqlite(session.createdAt),
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(now),
    };
  }
}
