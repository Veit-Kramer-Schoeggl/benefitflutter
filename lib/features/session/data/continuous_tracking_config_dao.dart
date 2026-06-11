import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/continuous_tracking_config.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/utils/sqlite_type_converters.dart';

/// Data Access Object for ContinuousTrackingConfig entity
///
/// Handles pure CRUD operations for the continuous_tracking_config table.
/// One-to-one relationship with User.
class ContinuousTrackingConfigDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Find config by user ID (one-to-one)
  Future<ContinuousTrackingConfig?> findByUserId(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'continuous_tracking_config',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find config by ID
  Future<ContinuousTrackingConfig?> findById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'continuous_tracking_config',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Get or create default config for a user
  ///
  /// Returns existing config if found, otherwise creates and returns
  /// a default configuration.
  Future<ContinuousTrackingConfig> getOrCreateDefault(String userId) async {
    final existing = await findByUserId(userId);
    if (existing != null) return existing;

    final defaultConfig = ContinuousTrackingConfig.defaultFor(userId);
    await insert(defaultConfig);
    return defaultConfig;
  }

  /// Insert new config
  Future<void> insert(ContinuousTrackingConfig config) async {
    final db = await _dbHelper.database;
    await db.insert(
      'continuous_tracking_config',
      _toMap(config),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing config
  Future<void> update(ContinuousTrackingConfig config) async {
    final db = await _dbHelper.database;
    await db.update(
      'continuous_tracking_config',
      _toMap(config),
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  /// Delete config by ID
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'continuous_tracking_config',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete config by user ID
  Future<void> deleteByUserId(String userId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'continuous_tracking_config',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Convert database map to ContinuousTrackingConfig model
  ContinuousTrackingConfig _fromMap(Map<String, dynamic> map) {
    return ContinuousTrackingConfig(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      isEnabled: SqliteTypeConverters.boolFromSqlite(map['is_enabled'] as int),
      resetPoints: _parseResetPoints(map['reset_points']),
      activityDetection: map['activity_detection'] as String? ?? 'hybrid',
      gpsIntervalSeconds: map['gps_interval_seconds'] as int? ?? 300,
      minDisplacementMeters: map['min_displacement_meters'] as int? ?? 100,
      createdAt: SqliteTypeConverters.dateTimeFromSqlite(
        map['created_at'] as int,
      ),
      updatedAt: SqliteTypeConverters.dateTimeFromSqlite(
        map['updated_at'] as int,
      ),
    );
  }

  List<String> _parseResetPoints(dynamic value) {
    if (value == null) return ['03:00'];
    if (value is String) {
      try {
        return List<String>.from(jsonDecode(value) as List);
      } catch (_) {
        return ['03:00'];
      }
    }
    return ['03:00'];
  }

  /// Convert ContinuousTrackingConfig model to database map
  Map<String, dynamic> _toMap(ContinuousTrackingConfig config) {
    return {
      'id': config.id,
      'user_id': config.userId,
      'is_enabled': SqliteTypeConverters.boolToSqlite(config.isEnabled),
      'reset_points': jsonEncode(config.resetPoints),
      'activity_detection': config.activityDetection,
      'gps_interval_seconds': config.gpsIntervalSeconds,
      'min_displacement_meters': config.minDisplacementMeters,
      'created_at': SqliteTypeConverters.dateTimeToSqlite(config.createdAt),
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(config.updatedAt),
    };
  }
}
