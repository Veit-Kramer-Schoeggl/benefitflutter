import 'package:sqflite/sqflite.dart';
import '../domain/user.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/utils/sqlite_type_converters.dart';

/// Data Access Object for User entity
///
/// Handles pure CRUD operations for the users table
/// No business logic - just database operations
class UserDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Find user by ID
  Future<User?> findById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find user by email (case-insensitive).
  ///
  /// Used by DB-backed authentication. `COLLATE NOCASE` makes the match
  /// case-insensitive; callers should still `.trim().toLowerCase()` the input
  /// (SQLite does not strip whitespace) for parity with the mock auth path.
  Future<User?> findByEmail(String email) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'users',
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [email],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Find first user (for getCurrentUser - single user app)
  Future<User?> findFirst() async {
    final db = await _dbHelper.database;
    final results = await db.query('users', limit: 1);

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Insert new user
  Future<void> insert(User user) async {
    final db = await _dbHelper.database;
    await db.insert(
      'users',
      _toMap(user),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing user
  Future<void> update(User user) async {
    final db = await _dbHelper.database;
    // Never overwrite created_at on update: _toMap() always stamps it with
    // DateTime.now() (correct for insert), but the User domain has no createdAt
    // field to preserve, so drop the column here and keep the stored value.
    final map = _toMap(user)..remove('created_at');
    await db.update('users', map, where: 'id = ?', whereArgs: [user.id]);
  }

  /// Delete user by ID
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  /// Find all users
  Future<List<User>> findAll() async {
    final db = await _dbHelper.database;
    final results = await db.query('users');
    return results.map((map) => _fromMap(map)).toList();
  }

  /// Convert database map to User model
  User _fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      displayName: map['display_name'] as String?,
      gender: map['gender'] as String?,
      dateOfBirth: map['date_of_birth'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date_of_birth'] as int)
          : null,
      timezone: map['timezone'] as String?,
      profileImagePath: map['profile_image_path'] as String?,
      isVerified: (map['is_verified'] ?? 0) == 1,
      verificationStatus: map['verification_status'] as String? ?? 'unverified',
    );
  }

  /// Convert User model to database map
  Map<String, dynamic> _toMap(User user) {
    final now = DateTime.now();
    return {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'password_hash': user.passwordHash,
      'display_name': user.displayName,
      'gender': user.gender,
      'date_of_birth': user.dateOfBirth != null
          ? SqliteTypeConverters.dateTimeToSqlite(user.dateOfBirth!)
          : null,
      'timezone': user.timezone,
      'profile_image_path': user.profileImagePath,
      'created_at': SqliteTypeConverters.dateTimeToSqlite(now),
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(now),
      'is_verified': user.isVerified ? 1 : 0,
      'verification_status': user.verificationStatus,
    };
  }
}
