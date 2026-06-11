import 'package:sqflite/sqflite.dart';
import '../domain/benefit.dart';
import '../domain/user_benefit.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/utils/sqlite_type_converters.dart';

/// Data Access Object for Benefit and UserBenefit entities
///
/// Handles CRUD operations for both benefits and user_benefits tables
/// Includes JOIN query for calculating total savings
class BenefitDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ========== Benefit Operations ==========

  /// Find all available benefits
  Future<List<Benefit>> findAllBenefits() async {
    final db = await _dbHelper.database;
    final results = await db.query('benefits');
    return results.map((map) => _benefitFromMap(map)).toList();
  }

  /// Find benefit by ID
  Future<Benefit?> findBenefitById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'benefits',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _benefitFromMap(results.first);
  }

  /// Insert new benefit
  Future<void> insertBenefit(Benefit benefit) async {
    final db = await _dbHelper.database;
    await db.insert(
      'benefits',
      _benefitToMap(benefit),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mark a user benefit as redeemed
  Future<void> redeemUserBenefit(String id, String redemptionCode) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.update(
      'user_benefits',
      {
        'status': 'redeemed',
        'redeemed_at': SqliteTypeConverters.dateTimeToSqlite(now),
        'redemption_code': redemptionCode,
        'updated_at': SqliteTypeConverters.dateTimeToSqlite(now),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== UserBenefit Operations ==========

  /// Find user benefits by user ID
  Future<List<UserBenefit>> findUserBenefits(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'user_benefits',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'earned_at DESC',
    );

    return results.map((map) => _userBenefitFromMap(map)).toList();
  }

  /// Find user benifits by id
  Future<UserBenefit?> findUserBenefitById(String id) async {
    final db = await _dbHelper.database;

    final results = await db.query(
      'user_benefits',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;

    return _userBenefitFromMap(results.first);
  }

  /// Insert new user benefit (award benefit to user)
  Future<void> insertUserBenefit(UserBenefit userBenefit) async {
    final db = await _dbHelper.database;
    await db.insert(
      'user_benefits',
      _userBenefitToMap(userBenefit),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ========== Calculations ==========

  /// Calculate total savings for a user using JOIN query
  ///
  /// SQL: SELECT SUM(b.discount_amount)
  ///      FROM user_benefits ub
  ///      INNER JOIN benefits b ON ub.benefit_id = b.id
  ///      WHERE ub.user_id = ?
  Future<double> calculateTotalSavings(String userId) async {
    final db = await _dbHelper.database;

    final results = await db.rawQuery(
      '''
      SELECT SUM(b.discount_amount) as total
      FROM user_benefits ub
      INNER JOIN benefits b ON ub.benefit_id = b.id
      WHERE ub.user_id = ?
    ''',
      [userId],
    );

    if (results.isEmpty || results.first['total'] == null) {
      return 0.0;
    }

    // SQLite returns sum as num, convert to double
    return (results.first['total']! as num).toDouble();
  }

  // ========== Conversion Methods ==========

  /// Convert database map to Benefit model
  Benefit _benefitFromMap(Map<String, dynamic> map) {
    return Benefit(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      discountAmount: (map['discount_amount'] as num).toDouble(),
      requiredDistance: map['required_distance'] as int?,
      requiredSessions: map['required_sessions'] as int?,
      createdAt: SqliteTypeConverters.dateTimeFromSqlite(
        map['created_at'] as int,
      ),
    );
  }

  /// Convert Benefit model to database map
  Map<String, dynamic> _benefitToMap(Benefit benefit) {
    final now = DateTime.now();
    return {
      'id': benefit.id,
      'title': benefit.title,
      'description': benefit.description,
      'discount_amount': benefit.discountAmount,
      'required_distance': benefit.requiredDistance,
      'required_sessions': benefit.requiredSessions,
      'created_at': SqliteTypeConverters.dateTimeToSqlite(benefit.createdAt),
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(now),
    };
  }

  /// Convert database map to UserBenefit model
  UserBenefit _userBenefitFromMap(Map<String, dynamic> map) {
    return UserBenefit(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      benefitId: map['benefit_id'] as String,
      sessionId: map['session_id'] as String,
      earnedAt: SqliteTypeConverters.dateTimeFromSqlite(
        map['earned_at'] as int,
      ),
      status: map['status'] == 'redeemed'
          ? BenefitStatus.redeemed
          : BenefitStatus.earned,
      redeemedAt: map['redeemed_at'] != null
          ? SqliteTypeConverters.dateTimeFromSqlite(map['redeemed_at'] as int)
          : null,
      redemptionCode: map['redemption_code'] as String?,
    );
  }

  /// Convert UserBenefit model to database map
  Map<String, dynamic> _userBenefitToMap(UserBenefit userBenefit) {
    final now = DateTime.now();
    return {
      'id': userBenefit.id,
      'user_id': userBenefit.userId,
      'benefit_id': userBenefit.benefitId,
      'session_id': userBenefit.sessionId,
      'earned_at': SqliteTypeConverters.dateTimeToSqlite(userBenefit.earnedAt),
      'status': userBenefit.status.name,
      'redeemed_at': userBenefit.redeemedAt != null
          ? SqliteTypeConverters.dateTimeToSqlite(userBenefit.redeemedAt!)
          : null,
      'redemption_code': userBenefit.redemptionCode,
      'created_at': SqliteTypeConverters.dateTimeToSqlite(now),
      'updated_at': SqliteTypeConverters.dateTimeToSqlite(now),
    };
  }
}
