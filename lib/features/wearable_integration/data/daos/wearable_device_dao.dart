import 'package:sqflite/sqflite.dart';
import '../../domain/wearable_device.dart';
import '../../domain/enums.dart';
import '../../../shared/database/database_helper.dart';

/// Data Access Object for wearable devices
/// Handles all database operations for the wearable_devices table
class WearableDeviceDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Insert a new wearable device
  Future<void> insert(WearableDevice device) async {
    final db = await _dbHelper.database;
    await db.insert(
      'wearable_devices',
      device.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing wearable device
  Future<void> update(WearableDevice device) async {
    final db = await _dbHelper.database;
    final deviceJson = device.toJson();
    deviceJson['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'wearable_devices',
      deviceJson,
      where: 'id = ?',
      whereArgs: [device.id],
    );
  }

  /// Delete a wearable device
  Future<void> delete(String deviceId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'wearable_devices',
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  /// Get a device by ID
  Future<WearableDevice?> getById(String deviceId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'wearable_devices',
      where: 'id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return WearableDevice.fromJson(results.first);
  }

  /// Get all devices for a user
  Future<List<WearableDevice>> getByUserId(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'wearable_devices',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return results.map((json) => WearableDevice.fromJson(json)).toList();
  }

  /// Get all connected devices for a user
  Future<List<WearableDevice>> getConnectedDevices(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'wearable_devices',
      where: 'user_id = ? AND connection_status = ?',
      whereArgs: [userId, ConnectionStatus.connected.toJson()],
      orderBy: 'last_sync_time DESC',
    );

    return results.map((json) => WearableDevice.fromJson(json)).toList();
  }

  /// Get devices by integration source
  Future<List<WearableDevice>> getBySource(
    String userId,
    IntegrationSource source,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'wearable_devices',
      where: 'user_id = ? AND integration_source = ?',
      whereArgs: [userId, source.toJson()],
      orderBy: 'created_at DESC',
    );

    return results.map((json) => WearableDevice.fromJson(json)).toList();
  }

  /// Update connection status of a device
  Future<void> updateConnectionStatus(
    String deviceId,
    ConnectionStatus status,
  ) async {
    final db = await _dbHelper.database;
    await db.update(
      'wearable_devices',
      {
        'connection_status': status.toJson(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  /// Update last sync time for a device
  Future<void> updateLastSyncTime(String deviceId, DateTime time) async {
    final db = await _dbHelper.database;
    await db.update(
      'wearable_devices',
      {
        'last_sync_time': time.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  /// Update device metadata (battery level, firmware, etc.)
  Future<void> updateMetadata(
    String deviceId,
    Map<String, dynamic> metadata,
  ) async {
    final db = await _dbHelper.database;
    await db.update(
      'wearable_devices',
      {
        'metadata': metadata.toString(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  /// Check if a device exists
  Future<bool> exists(String deviceId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'wearable_devices',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  /// Get count of devices for a user
  Future<int> getCountByUser(String userId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM wearable_devices WHERE user_id = ?',
      [userId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count of connected devices for a user
  Future<int> getConnectedCount(String userId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM wearable_devices WHERE user_id = ? AND connection_status = ?',
      [userId, ConnectionStatus.connected.toJson()],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete all devices for a user
  Future<void> deleteByUser(String userId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'wearable_devices',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Get all devices (for admin/testing purposes)
  Future<List<WearableDevice>> getAll() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'wearable_devices',
      orderBy: 'created_at DESC',
    );

    return results.map((json) => WearableDevice.fromJson(json)).toList();
  }
}
