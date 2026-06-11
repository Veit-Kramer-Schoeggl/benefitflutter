import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:benefitflutter/features/shared/database/database_helper.dart';

/// Migration / schema tests run against an in-process SQLite (ffi), exercising
/// the real onConfigure/onCreate/onUpgrade via DatabaseHelper.openAppDatabase.
void main() {
  setUpAll(sqfliteFfiInit);

  final helper = DatabaseHelper();

  const expectedTables = {
    'users',
    'user_biometrics_reported',
    'user_preferences',
    'sessions',
    'gps_points',
    'benefits',
    'user_benefits',
    'sync_queue',
    'wearable_devices',
    'session_biometric_data',
    'session_motion_data',
    'session_sensor_summary',
    'health_platform_data',
    'continuous_tracking_config',
    'continuous_tracking_state',
    'activity_segments',
  };

  Future<Set<String>> tableNames(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
    );
    return rows.map((r) => r['name']! as String).toSet();
  }

  test(
    'fresh onCreate builds the full v11 schema with FK on and no orphans',
    () async {
      final db = await helper.openAppDatabase(
        databaseFactoryFfi,
        inMemoryDatabasePath,
      );
      addTearDown(db.close);

      expect(await tableNames(db), containsAll(expectedTables));

      // onConfigure enabled foreign keys for this connection.
      final fk = await db.rawQuery('PRAGMA foreign_keys');
      expect(fk.first.values.first, 1);

      // No orphan rows on a fresh DB.
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      // Spot-check a continuous-tracking column exists.
      final cols = await db.rawQuery(
        'PRAGMA table_info(continuous_tracking_config)',
      );
      expect(cols.map((c) => c['name']), contains('gps_interval_seconds'));
    },
  );

  test(
    'v10 -> v11 upgrade recreates continuous-tracking tables (fresh == upgraded)',
    () async {
      final dir = await Directory.systemTemp.createTemp('benefit_mig_test');
      final path = '${dir.path}/app.db';
      addTearDown(() => dir.delete(recursive: true));

      // Fresh v11, capture canonical continuous-tracking schema.
      final fresh = await helper.openAppDatabase(databaseFactoryFfi, path);
      final freshConfigCols = (await fresh.rawQuery(
        'PRAGMA table_info(continuous_tracking_config)',
      )).length;

      // Simulate a pre-v11 DB: drop the v11 tables and roll the version back.
      await fresh.execute('DROP TABLE continuous_tracking_config');
      await fresh.execute('DROP TABLE continuous_tracking_state');
      await fresh.execute('DROP TABLE activity_segments');
      await fresh.execute('PRAGMA user_version = 10');
      await fresh.close();

      // Reopen at v11 -> triggers onUpgrade(10, 11).
      final upgraded = await helper.openAppDatabase(databaseFactoryFfi, path);
      addTearDown(upgraded.close);

      expect(
        await tableNames(upgraded),
        containsAll({
          'continuous_tracking_config',
          'continuous_tracking_state',
          'activity_segments',
        }),
      );

      final upgradedConfigCols = (await upgraded.rawQuery(
        'PRAGMA table_info(continuous_tracking_config)',
      )).length;
      expect(upgradedConfigCols, freshConfigCols);
    },
  );
}
