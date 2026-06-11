import 'package:sqflite/sqflite.dart';
import '../domain/activity_segment.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/utils/sqlite_type_converters.dart';
import '../../../core/enums/activity_type.dart';

/// Data Access Object for ActivitySegment entity
///
/// Handles pure CRUD operations for the activity_segments table.
/// Many-to-one relationship with Session.
class ActivitySegmentDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Find all segments for a session
  Future<List<ActivitySegment>> findBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'activity_segments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'start_time ASC',
    );

    return results.map(_fromMap).toList();
  }

  /// Find segment by ID
  Future<ActivitySegment?> findById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'activity_segments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find the latest (most recent) segment for a session
  Future<ActivitySegment?> findLatestBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'activity_segments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find ongoing (no end_time) segment for a session
  Future<ActivitySegment?> findOngoingBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'activity_segments',
      where: 'session_id = ? AND end_time IS NULL',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Insert new segment
  Future<void> insert(ActivitySegment segment) async {
    final db = await _dbHelper.database;
    await db.insert(
      'activity_segments',
      _toMap(segment),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple segments in batch
  Future<void> insertBatch(List<ActivitySegment> segments) async {
    if (segments.isEmpty) return;

    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final segment in segments) {
      batch.insert(
        'activity_segments',
        _toMap(segment),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Update existing segment
  Future<void> update(ActivitySegment segment) async {
    final db = await _dbHelper.database;
    await db.update(
      'activity_segments',
      _toMap(segment),
      where: 'id = ?',
      whereArgs: [segment.id],
    );
  }

  /// End an ongoing segment (set end_time)
  Future<void> endSegment(String id, {double? distanceMeters}) async {
    final segment = await findById(id);
    if (segment == null) return;

    final updated = segment.copyWith(
      endTime: DateTime.now(),
      distanceMeters: distanceMeters,
    );
    await update(updated);
  }

  /// Delete segment by ID
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('activity_segments', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all segments for a session
  Future<void> deleteBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'activity_segments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Get total distance for a session from all segments
  Future<double> getTotalDistanceBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(distance_meters) as total
      FROM activity_segments
      WHERE session_id = ?
    ''',
      [sessionId],
    );

    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }
    return (result.first['total'] as num).toDouble();
  }

  /// Get count of segments for a session
  Future<int> getCountBySessionId(String sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM activity_segments
      WHERE session_id = ?
    ''',
      [sessionId],
    );

    if (result.isEmpty) return 0;
    return result.first['count'] as int;
  }

  /// Convert database map to ActivitySegment model
  ActivitySegment _fromMap(Map<String, dynamic> map) {
    return ActivitySegment(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      activityType: ActivityType.fromJson(map['activity_type'] as String),
      startTime: SqliteTypeConverters.dateTimeFromSqlite(
        map['start_time'] as int,
      ),
      endTime: SqliteTypeConverters.nullableDateTimeFromSqlite(
        map['end_time'] as int?,
      ),
      distanceMeters: map['distance_meters'] != null
          ? (map['distance_meters'] as num).toDouble()
          : null,
      detectionSource: DetectionSource.fromJson(
        map['detection_source'] as String?,
      ),
      confidence: map['confidence'] != null
          ? (map['confidence'] as num).toDouble()
          : null,
      createdAt: SqliteTypeConverters.dateTimeFromSqlite(
        map['created_at'] as int,
      ),
      updatedAt: SqliteTypeConverters.dateTimeFromSqlite(
        map['updated_at'] as int,
      ),
    );
  }

  /// Convert ActivitySegment model to database map
  Map<String, dynamic> _toMap(ActivitySegment segment) {
    return {
      'id': segment.id,
      'session_id': segment.sessionId,
      'activity_type': segment.activityType.toJson(),
      'start_time': SqliteTypeConverters.dateTimeToSqlite(segment.startTime),
      'end_time': SqliteTypeConverters.nullableDateTimeToSqlite(
        segment.endTime,
      ),
      'distance_meters': segment.distanceMeters,
      'detection_source': segment.detectionSource.toJson(),
      'confidence': segment.confidence,
      'created_at': SqliteTypeConverters.dateTimeToSqlite(segment.createdAt),
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(segment.updatedAt),
    };
  }
}
