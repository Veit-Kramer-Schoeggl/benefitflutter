import 'package:sqflite/sqflite.dart';
import '../domain/continuous_tracking_state.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/utils/sqlite_type_converters.dart';

/// Data Access Object for ContinuousTrackingState entity
///
/// Handles pure CRUD operations for the continuous_tracking_state table.
/// One-to-one relationship with User.
class ContinuousTrackingStateDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Find state by user ID (one-to-one)
  Future<ContinuousTrackingState?> findByUserId(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'continuous_tracking_state',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find state by ID
  Future<ContinuousTrackingState?> findById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'continuous_tracking_state',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Get or create default state for a user
  ///
  /// Returns existing state if found, otherwise creates and returns
  /// a default (inactive) state.
  Future<ContinuousTrackingState> getOrCreateDefault(String userId) async {
    final existing = await findByUserId(userId);
    if (existing != null) return existing;

    final defaultState = ContinuousTrackingState.defaultFor(userId);
    await insert(defaultState);
    return defaultState;
  }

  /// Insert new state
  Future<void> insert(ContinuousTrackingState state) async {
    final db = await _dbHelper.database;
    await db.insert(
      'continuous_tracking_state',
      _toMap(state),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing state
  Future<void> update(ContinuousTrackingState state) async {
    final db = await _dbHelper.database;
    await db.update(
      'continuous_tracking_state',
      _toMap(state),
      where: 'id = ?',
      whereArgs: [state.id],
    );
  }

  /// Set tracking to active with a new session
  Future<void> setActive(String userId, String sessionId) async {
    final state = await getOrCreateDefault(userId);
    final updated = state.copyWith(
      isActive: true,
      isPausedForManual: false,
      currentSessionId: sessionId,
      startedAt: DateTime.now(),
      lastDataReceived: DateTime.now(),
    );
    await update(updated);
  }

  /// Set tracking to inactive
  Future<void> setInactive(String userId) async {
    final state = await findByUserId(userId);
    if (state == null) return;

    final updated = state.copyWith(
      isActive: false,
      isPausedForManual: false,
      currentSessionId: null,
      startedAt: null,
    );
    await update(updated);
  }

  /// Pause tracking for a manual session
  Future<void> setPausedForManual(String userId, bool paused) async {
    final state = await findByUserId(userId);
    if (state == null) return;

    final updated = state.copyWith(isPausedForManual: paused);
    await update(updated);
  }

  /// Update the last data received timestamp
  Future<void> updateLastDataReceived(String userId) async {
    final state = await findByUserId(userId);
    if (state == null) return;

    final updated = state.copyWith(lastDataReceived: DateTime.now());
    await update(updated);
  }

  /// Update detected activity
  Future<void> updateDetectedActivity(
    String userId,
    String? activity,
    double? confidence,
  ) async {
    final state = await findByUserId(userId);
    if (state == null) return;

    final updated = state.copyWith(
      currentDetectedActivity: activity,
      detectionConfidence: confidence,
    );
    await update(updated);
  }

  /// Delete state by ID
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'continuous_tracking_state',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete state by user ID
  Future<void> deleteByUserId(String userId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'continuous_tracking_state',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Convert database map to ContinuousTrackingState model
  ContinuousTrackingState _fromMap(Map<String, dynamic> map) {
    return ContinuousTrackingState(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      isActive: SqliteTypeConverters.boolFromSqlite(map['is_active'] as int),
      isPausedForManual:
          SqliteTypeConverters.boolFromSqlite(map['is_paused_for_manual'] as int),
      currentSessionId: map['current_session_id'] as String?,
      startedAt: SqliteTypeConverters.nullableDateTimeFromSqlite(
        map['started_at'] as int?,
      ),
      lastDataReceived: SqliteTypeConverters.nullableDateTimeFromSqlite(
        map['last_data_received'] as int?,
      ),
      currentDetectedActivity: map['current_detected_activity'] as String?,
      detectionConfidence: map['detection_confidence'] != null
          ? (map['detection_confidence'] as num).toDouble()
          : null,
      updatedAt: SqliteTypeConverters.dateTimeFromSqlite(map['updated_at'] as int),
    );
  }

  /// Convert ContinuousTrackingState model to database map
  Map<String, dynamic> _toMap(ContinuousTrackingState state) {
    return {
      'id': state.id,
      'user_id': state.userId,
      'is_active': SqliteTypeConverters.boolToSqlite(state.isActive),
      'is_paused_for_manual': SqliteTypeConverters.boolToSqlite(state.isPausedForManual),
      'current_session_id': state.currentSessionId,
      'started_at': SqliteTypeConverters.nullableDateTimeToSqlite(state.startedAt),
      'last_data_received':
          SqliteTypeConverters.nullableDateTimeToSqlite(state.lastDataReceived),
      'current_detected_activity': state.currentDetectedActivity,
      'detection_confidence': state.detectionConfidence,
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(state.updatedAt),
    };
  }
}
