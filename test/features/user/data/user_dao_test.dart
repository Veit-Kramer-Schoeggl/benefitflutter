import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:benefitflutter/features/shared/database/database_helper.dart';
import 'package:benefitflutter/features/user/data/user_dao.dart';
import 'package:benefitflutter/features/user/domain/user.dart';

/// Exercises the real UserDao against an in-process sqflite-ffi database.
/// Focuses on findByEmail (added for DB-backed authentication), including the
/// COLLATE NOCASE case-insensitive match.
void main() {
  setUpAll(sqfliteFfiInit);

  final helper = DatabaseHelper();
  late Database db;
  late UserDao dao;

  setUp(() async {
    db = await helper.openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
    DatabaseHelper.debugDatabase = db; // point all DAOs at this ffi connection
    dao = UserDao();
  });

  tearDown(() async {
    DatabaseHelper.debugDatabase = null;
    await db.close();
  });

  User user({String id = 'u1', String email = 'alice@example.com'}) =>
      User(id: id, name: 'Alice', email: email, passwordHash: 'hash');

  test('findByEmail returns the matching user', () async {
    await dao.insert(user());

    final found = await dao.findByEmail('alice@example.com');

    expect(found, isNotNull);
    expect(found!.id, 'u1');
    expect(found.email, 'alice@example.com');
  });

  test('findByEmail is case-insensitive (COLLATE NOCASE)', () async {
    await dao.insert(user(email: 'alice@example.com'));

    final found = await dao.findByEmail('ALICE@Example.com');

    expect(found?.id, 'u1');
  });

  test('findByEmail returns null for an unknown email', () async {
    await dao.insert(user());

    final found = await dao.findByEmail('nobody@example.com');

    expect(found, isNull);
  });

  test('findByEmail reflects an updated email', () async {
    await dao.insert(user());
    await dao.update(user().copyWith(email: 'new@example.com'));

    expect(await dao.findByEmail('alice@example.com'), isNull);
    expect((await dao.findByEmail('new@example.com'))?.id, 'u1');
  });
}
