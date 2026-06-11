import 'package:sqflite/sqflite.dart';
import '../domain/user_preferences.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/utils/sqlite_type_converters.dart';

/// Data Access Object for UserPreferences entity
///
/// Handles pure CRUD operations for the user_preferences table
/// One-to-one relationship with User
/// No business logic - just database operations
class UserPreferencesDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Find preferences by user ID (one-to-one)
  Future<UserPreferences?> findByUserId(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'user_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find preferences by ID
  Future<UserPreferences?> findById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'user_preferences',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Insert new preferences
  Future<void> insert(UserPreferences preferences) async {
    final db = await _dbHelper.database;
    await db.insert(
      'user_preferences',
      _toMap(preferences),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing preferences
  Future<void> update(UserPreferences preferences) async {
    final db = await _dbHelper.database;
    await db.update(
      'user_preferences',
      _toMap(preferences),
      where: 'id = ?',
      whereArgs: [preferences.id],
    );
  }

  /// Delete preferences by ID
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('user_preferences', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete preferences by user ID
  Future<void> deleteByUserId(String userId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'user_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Convert database map to UserPreferences model
  UserPreferences _fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      defaultLocationCity: map['default_location_city'] as String?,
      distanceUnit: map['distance_unit'] as String? ?? 'metric',
      temperatureUnit: map['temperature_unit'] as String? ?? 'celsius',
      weightUnit: map['weight_unit'] as String? ?? 'kg',
      theme: map['theme'] as String? ?? 'system',
      language: map['language'] as String? ?? 'en',
      timezone: map['timezone'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// Convert UserPreferences model to database map
  Map<String, dynamic> _toMap(UserPreferences preferences) {
    return {
      'id': preferences.id,
      'user_id': preferences.userId,
      'default_location_city': preferences.defaultLocationCity,
      'distance_unit': preferences.distanceUnit,
      'temperature_unit': preferences.temperatureUnit,
      'weight_unit': preferences.weightUnit,
      'theme': preferences.theme,
      'language': preferences.language,
      'timezone': preferences.timezone,
      'created_at': SqliteTypeConverters.dateTimeToSqlite(
        preferences.createdAt,
      ),
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(
        preferences.updatedAt,
      ),
    };
  }
}
