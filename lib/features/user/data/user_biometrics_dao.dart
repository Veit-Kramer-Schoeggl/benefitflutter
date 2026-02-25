import 'package:sqflite/sqflite.dart';
import '../domain/user_biometrics_reported.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/utils/sqlite_type_converters.dart';

/// Data Access Object for UserBiometricsReported entity
///
/// Handles pure CRUD operations for the user_biometrics_reported table
/// No business logic - just database operations
class UserBiometricsDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Find latest biometrics entry for a user
  Future<UserBiometricsReported?> findLatestByUserId(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'user_biometrics_reported',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'report_date DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find biometrics entry by user ID and date
  Future<UserBiometricsReported?> findByUserIdAndDate(
    String userId,
    DateTime date,
  ) async {
    final db = await _dbHelper.database;
    final timestamp = SqliteTypeConverters.dateTimeToSqlite(date);
    final results = await db.query(
      'user_biometrics_reported',
      where: 'user_id = ? AND report_date = ?',
      whereArgs: [userId, timestamp],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find all biometrics entries for a user
  Future<List<UserBiometricsReported>> findAllByUserId(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'user_biometrics_reported',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'report_date DESC',
    );

    return results.map((map) => _fromMap(map)).toList();
  }

  /// Insert new biometrics entry
  Future<void> insert(UserBiometricsReported biometrics) async {
    final db = await _dbHelper.database;
    await db.insert(
      'user_biometrics_reported',
      _toMap(biometrics),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing biometrics entry
  Future<void> update(UserBiometricsReported biometrics) async {
    final db = await _dbHelper.database;
    await db.update(
      'user_biometrics_reported',
      _toMap(biometrics),
      where: 'id = ?',
      whereArgs: [biometrics.id],
    );
  }

  /// Delete biometrics entry by ID
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'user_biometrics_reported',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete ALL biometrics entries for a user (Account deletion)
  Future<void> deleteByUserId(String userId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'user_biometrics_reported',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Convert database map to UserBiometricsReported model
  UserBiometricsReported _fromMap(Map<String, dynamic> map) {
    return UserBiometricsReported(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      reportDate: DateTime.fromMillisecondsSinceEpoch(map['report_date'] as int),
      heightCm: map['height_cm'] as int?,
      weightKg: map['weight_kg'] != null ? (map['weight_kg'] as num).toDouble() : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// Convert UserBiometricsReported model to database map
  Map<String, dynamic> _toMap(UserBiometricsReported biometrics) {
    return {
      'id': biometrics.id,
      'user_id': biometrics.userId,
      'report_date': SqliteTypeConverters.dateTimeToSqlite(biometrics.reportDate),
      'height_cm': biometrics.heightCm,
      'weight_kg': biometrics.weightKg,
      'created_at': SqliteTypeConverters.dateTimeToSqlite(biometrics.createdAt),
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(biometrics.updatedAt),
    };
  }
}
