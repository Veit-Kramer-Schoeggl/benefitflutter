import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:benefitflutter/core/utils/password_utils.dart';

/// Central database helper managing all SQLite operations
///
/// Responsibilities:
/// - Database initialization and versioning
/// - Table creation for all entities (users, sessions, benefits, user_benefits)
/// - Schema migrations
/// - Singleton pattern to ensure single database instance
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// Get database instance (lazy initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'benefit_app.db');

    final db = await openDatabase(
      path,
      version: 11,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _logForeignKeyViolations(db);
    return db;
  }

  /// Enable foreign-key enforcement. PRAGMA foreign_keys is per-connection and
  /// must be set in onConfigure (before onCreate/onUpgrade). Without this every
  /// ON DELETE CASCADE in the schema is silently inert.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// One-time defensive check: enabling foreign_keys does NOT validate existing
  /// rows on open, so pre-existing orphans won't crash the app — but they could
  /// make a future write fail. Surface them in logs (count only) without crashing.
  /// Actual orphan cleanup is a separate Phase 1 migration.
  Future<void> _logForeignKeyViolations(Database db) async {
    try {
      final violations = await db.rawQuery('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) {
        debugPrint(
          'DatabaseHelper: WARNING — ${violations.length} foreign-key violation(s) '
          '(orphan rows) found in existing data. Not enforced retroactively; '
          'cleanup pending (Phase 1).',
        );
      }
    } catch (e) {
      debugPrint('DatabaseHelper: foreign_key_check failed - $e');
    }
  }

  /// Create all tables on first database creation
  Future<void> _onCreate(Database db, int version) async {
    await _createUsersTable(db);
    await _createUserBiometricsReportedTable(db);
    await _createUserPreferencesTable(db);
    await _createSessionsTable(db);
    await _createGpsPointsTable(db);
    await _createBenefitsTable(db);
    await _createUserBenefitsTable(db);
    await _createSyncQueueTable(db);
    // v4: Wearable integration tables
    await _migrateToV4(db);
    // v11: Continuous tracking tables
    await _createContinuousTrackingTables(db);
  }

  /// Create continuous tracking tables (v11)
  Future<void> _createContinuousTrackingTables(Database db) async {
    // Create continuous_tracking_config table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS continuous_tracking_config (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        is_enabled INTEGER NOT NULL DEFAULT 0,
        reset_points TEXT NOT NULL DEFAULT '["03:00"]',
        activity_detection TEXT NOT NULL DEFAULT 'hybrid',
        gps_interval_seconds INTEGER NOT NULL DEFAULT 300,
        min_displacement_meters INTEGER NOT NULL DEFAULT 100,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_continuous_config_user ON continuous_tracking_config(user_id)',
    );

    // Create continuous_tracking_state table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS continuous_tracking_state (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 0,
        is_paused_for_manual INTEGER NOT NULL DEFAULT 0,
        current_session_id TEXT,
        started_at INTEGER,
        last_data_received INTEGER,
        current_detected_activity TEXT,
        detection_confidence REAL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (current_session_id) REFERENCES sessions(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_continuous_state_user ON continuous_tracking_state(user_id)',
    );

    // Create activity_segments table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_segments (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        distance_meters REAL,
        detection_source TEXT NOT NULL,
        confidence REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_segments_session ON activity_segments(session_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_segments_time ON activity_segments(start_time, end_time)',
    );
  }

  /// Handle database upgrades (migrations)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: Add GPS tracking
    if (oldVersion < 2) {
      await _createGpsPointsTable(db);
    }

    // v2 → v3: Add profile support (user extensions, biometrics, preferences)
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }

    // v3 → v4: Add wearable integration support
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }

    // v4 → v5: Add profile image support
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }

    // v5 → v6: Identity Verification
    if (oldVersion < 6) {
      await _migrateToV6(db);
    }

    // v6 → v7: Add password support
    if (oldVersion < 7) {
      await _migrateToV7(db);
    }

    // v7 → v8: Add benefit redemption support
    if (oldVersion < 8) {
      await _migrateToV8(db);
    }

    // v8 → v9: Add benefit redemption support
    if (oldVersion < 9) {
      await _migrateToV9(db);
    }

    // v9 → v10: Hash existing plain text passwords
    if (oldVersion < 10) {
      await _migrateToV10(db);
    }

    // v10 → v11: Add continuous tracking tables
    if (oldVersion < 11) {
      await _migrateToV11(db);
    }
  }

  /// Migration v3 → v4: Add wearable integration support
  Future<void> _migrateToV4(Database db) async {
    // Step 1: Create wearable device registry table
    await db.execute('''
      CREATE TABLE wearable_devices (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        device_type TEXT NOT NULL,
        integration_source TEXT NOT NULL,
        connection_status TEXT NOT NULL,
        capabilities TEXT NOT NULL,
        last_sync_time INTEGER,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_devices_user ON wearable_devices(user_id)',
    );

    // Step 2: Create biometric sensor data table (heart rate, HRV, SpO2, temp)
    await db.execute('''
      CREATE TABLE session_biometric_data (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        device_id TEXT,
        sensor_type TEXT NOT NULL,
        value REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        accuracy REAL,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES wearable_devices(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_biometric_session_type ON session_biometric_data(session_id, sensor_type)',
    );
    await db.execute(
      'CREATE INDEX idx_biometric_timestamp ON session_biometric_data(timestamp)',
    );

    // Step 3: Create motion sensor data table (cadence, power, steps, stride)
    await db.execute('''
      CREATE TABLE session_motion_data (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        device_id TEXT,
        sensor_type TEXT NOT NULL,
        value REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        accuracy REAL,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES wearable_devices(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_motion_session_type ON session_motion_data(session_id, sensor_type)',
    );
    await db.execute(
      'CREATE INDEX idx_motion_timestamp ON session_motion_data(timestamp)',
    );

    // Step 4: Create aggregated sensor summary table (kept permanently)
    await db.execute('''
      CREATE TABLE session_sensor_summary (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL UNIQUE,
        avg_heart_rate REAL,
        max_heart_rate REAL,
        min_heart_rate REAL,
        avg_heart_rate_variability REAL,
        heart_rate_zones TEXT,
        total_steps INTEGER,
        avg_cadence REAL,
        avg_power REAL,
        calories_burned REAL,
        data_sources TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // Step 5: Create health platform data table (Health Connect/HealthKit)
    await db.execute('''
      CREATE TABLE health_platform_data (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        data_type TEXT NOT NULL,
        value TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        source_app TEXT,
        metadata TEXT,
        synced_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_health_data_user_type ON health_platform_data(user_id, data_type)',
    );
    await db.execute(
      'CREATE INDEX idx_health_data_time ON health_platform_data(start_time, end_time)',
    );

    // Step 6: Extend sessions table with wearable data fields
    await db.execute('ALTER TABLE sessions ADD COLUMN avg_heart_rate INTEGER');
    await db.execute('ALTER TABLE sessions ADD COLUMN max_heart_rate INTEGER');
    await db.execute('ALTER TABLE sessions ADD COLUMN min_heart_rate INTEGER');
    await db.execute(
      'ALTER TABLE sessions ADD COLUMN avg_heart_rate_variability REAL',
    );
    await db.execute('ALTER TABLE sessions ADD COLUMN total_steps INTEGER');
    await db.execute('ALTER TABLE sessions ADD COLUMN avg_cadence REAL');
    await db.execute('ALTER TABLE sessions ADD COLUMN calories_burned REAL');
    await db.execute('ALTER TABLE sessions ADD COLUMN heart_rate_zones TEXT');
    await db.execute(
      'ALTER TABLE sessions ADD COLUMN has_wearable_data INTEGER DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE sessions ADD COLUMN connected_device_ids TEXT',
    );
  }

  /// Migration v4 → v5: Add profile image support
  Future<void> _migrateToV5(Database db) async {
    final result = await db.rawQuery("PRAGMA table_info(users)");
    final exists = result.any(
      (column) => column['name'] == 'profile_image_path',
    );

    if (!exists) {
      await db.execute('ALTER TABLE users ADD COLUMN profile_image_path TEXT');
    }
  }

  /// Migration v5 → v6: Add identity verification flow
  Future<void> _migrateToV6(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(users)");
    final columnNames = columns.map((c) => c['name'] as String).toSet();

    if (!columnNames.contains('is_verified')) {
      await db.execute(
        'ALTER TABLE users ADD COLUMN is_verified INTEGER DEFAULT 0',
      );
    }

    if (!columnNames.contains('verification_status')) {
      await db.execute(
        "ALTER TABLE users ADD COLUMN verification_status TEXT DEFAULT 'unverified'",
      );
    }
  }

  /// Migration v6 → v7: Add password change
  Future<void> _migrateToV7(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(users)");
    final columnNames = columns.map((c) => c['name'] as String).toSet();

    if (!columnNames.contains('password_hash')) {
      await db.execute(
        "ALTER TABLE users ADD COLUMN password_hash TEXT DEFAULT ''",
      );
    }
  }

  /// Migration v7 → v8: Add benefit redemption support
  Future<void> _migrateToV8(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(user_benefits)");
    final columnNames = columns.map((c) => c['name'] as String).toSet();

    if (!columnNames.contains('status')) {
      await db.execute(
        "ALTER TABLE user_benefits ADD COLUMN status TEXT DEFAULT 'earned'",
      );
    }

    if (!columnNames.contains('redeemed_at')) {
      await db.execute(
        "ALTER TABLE user_benefits ADD COLUMN redeemed_at INTEGER",
      );
    }

    await db.execute(
      "UPDATE user_benefits SET status = 'earned' WHERE status IS NULL",
    );
  }

  /// Migration v8 → v9: Add redemption code
  Future<void> _migrateToV9(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(user_benefits)");
    final columnNames = columns.map((c) => c['name'] as String).toSet();

    if (!columnNames.contains('redemption_code')) {
      await db.execute(
        "ALTER TABLE user_benefits ADD COLUMN redemption_code TEXT",
      );
    }
  }

  /// Migration v9 → v10: Hash existing plain text passwords
  ///
  /// Converts any plain text passwords to SHA-256 hashes.
  /// SHA-256 hashes are 64 hex characters, so we detect plain text
  /// passwords by checking if the value doesn't match this pattern.
  Future<void> _migrateToV10(Database db) async {
    // Get all users with their password_hash
    final users = await db.query('users', columns: ['id', 'password_hash']);

    // SHA-256 hash pattern: exactly 64 lowercase hex characters
    final hashPattern = RegExp(r'^[a-f0-9]{64}$');

    for (final user in users) {
      final userId = user['id'] as String;
      final passwordHash = user['password_hash'] as String? ?? '';

      // Skip if already hashed or empty
      if (passwordHash.isEmpty || hashPattern.hasMatch(passwordHash)) {
        continue;
      }

      // Plain text password found - hash it
      final hashedPassword = PasswordUtils.hashPassword(passwordHash);

      await db.update(
        'users',
        {'password_hash': hashedPassword},
        where: 'id = ?',
        whereArgs: [userId],
      );

      debugPrint('Migration v10: Hashed password for user $userId');
    }
  }

  /// Migration v10 → v11: Add continuous tracking tables
  ///
  /// Creates tables for continuous tracking configuration, state, and activity segments.
  Future<void> _migrateToV11(Database db) async {
    // Step 1: Create continuous_tracking_config table (user preferences)
    await db.execute('''
      CREATE TABLE continuous_tracking_config (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        is_enabled INTEGER NOT NULL DEFAULT 0,
        reset_points TEXT NOT NULL DEFAULT '["03:00"]',
        activity_detection TEXT NOT NULL DEFAULT 'hybrid',
        gps_interval_seconds INTEGER NOT NULL DEFAULT 300,
        min_displacement_meters INTEGER NOT NULL DEFAULT 100,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_continuous_config_user ON continuous_tracking_config(user_id)',
    );

    // Step 2: Create continuous_tracking_state table (runtime state)
    await db.execute('''
      CREATE TABLE continuous_tracking_state (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 0,
        is_paused_for_manual INTEGER NOT NULL DEFAULT 0,
        current_session_id TEXT,
        started_at INTEGER,
        last_data_received INTEGER,
        current_detected_activity TEXT,
        detection_confidence REAL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (current_session_id) REFERENCES sessions(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_continuous_state_user ON continuous_tracking_state(user_id)',
    );

    // Step 3: Create activity_segments table (segments within sessions)
    await db.execute('''
      CREATE TABLE activity_segments (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        distance_meters REAL,
        detection_source TEXT NOT NULL,
        confidence REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_activity_segments_session ON activity_segments(session_id)',
    );
    await db.execute(
      'CREATE INDEX idx_activity_segments_time ON activity_segments(start_time, end_time)',
    );
  }

  /// Migration v2 → v3: Add profile support
  Future<void> _migrateToV3(Database db) async {
    // Step 1: Add new columns to users table
    await db.execute('ALTER TABLE users ADD COLUMN display_name TEXT');
    await db.execute('ALTER TABLE users ADD COLUMN gender TEXT');
    await db.execute('ALTER TABLE users ADD COLUMN date_of_birth INTEGER');
    await db.execute('ALTER TABLE users ADD COLUMN timezone TEXT');

    // Step 2: Migrate existing users with defaults
    await db.execute('''
      UPDATE users
      SET display_name = name,
          timezone = 'UTC'
      WHERE display_name IS NULL
    ''');

    // Step 3: Create new tables
    await _createUserBiometricsReportedTable(db);
    await _createUserPreferencesTable(db);

    // Step 4: Create default preferences for existing users
    await db.execute(
      '''
      INSERT INTO user_preferences (
        id,
        user_id,
        distance_unit,
        temperature_unit,
        weight_unit,
        theme,
        language,
        created_at,
        updated_at
      )
      SELECT
        'pref-' || id,
        id,
        'metric',
        'celsius',
        'kg',
        'system',
        'en',
        ?,
        ?
      FROM users
    ''',
      [
        DateTime.now().millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// Create users table
  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        display_name TEXT,
        gender TEXT,
        date_of_birth INTEGER,
        timezone TEXT,
        profile_image_path TEXT,
        is_verified INTEGER DEFAULT 0,
        verification_status TEXT DEFAULT 'unverified',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Index for email lookups
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
  }

  /// Create user_biometrics_reported table (v3 - Profile support)
  Future<void> _createUserBiometricsReportedTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_biometrics_reported (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        report_date INTEGER NOT NULL,
        height_cm INTEGER,
        weight_kg REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for common queries
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_biometrics_user_id ON user_biometrics_reported(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_biometrics_report_date ON user_biometrics_reported(report_date)',
    );
  }

  /// Create user_preferences table (v3 - Profile support)
  Future<void> _createUserPreferencesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_preferences (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        default_location_city TEXT,
        distance_unit TEXT NOT NULL DEFAULT 'metric',
        temperature_unit TEXT NOT NULL DEFAULT 'celsius',
        weight_unit TEXT NOT NULL DEFAULT 'kg',
        theme TEXT NOT NULL DEFAULT 'system',
        language TEXT NOT NULL DEFAULT 'en',
        timezone TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Index for user lookups (one-to-one relationship)
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id)',
    );
  }

  /// Create sessions table
  Future<void> _createSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        tracking_mode TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        status TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration_seconds INTEGER,
        distance_meters REAL,
        tracking_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for common queries
    await db.execute('CREATE INDEX idx_sessions_user_id ON sessions(user_id)');
    await db.execute('CREATE INDEX idx_sessions_status ON sessions(status)');
    await db.execute(
      'CREATE INDEX idx_sessions_tracking_date ON sessions(tracking_date)',
    );
    await db.execute(
      'CREATE INDEX idx_sessions_start_time ON sessions(start_time)',
    );
  }

  /// Create gps_points table (v2 - GPS tracking)
  Future<void> _createGpsPointsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gps_points (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy_meters REAL,
        speed_meters_per_second REAL,
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // Composite index for efficient session queries
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gps_points_session_timestamp ON gps_points(session_id, timestamp)',
    );

    // Index for cleanup queries
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gps_points_created_at ON gps_points(created_at)',
    );
  }

  /// Create benefits table
  Future<void> _createBenefitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE benefits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        discount_amount REAL NOT NULL,
        required_distance INTEGER,
        required_sessions INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  /// Create user_benefits table (join table for earned benefits)
  Future<void> _createUserBenefitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_benefits (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        benefit_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        earned_at INTEGER NOT NULL,
        status TEXT DEFAULT 'earned',
        redeemed_at INTEGER,
        redemption_code TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (benefit_id) REFERENCES benefits(id) ON DELETE CASCADE,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for common queries
    await db.execute(
      'CREATE INDEX idx_user_benefits_user_id ON user_benefits(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_user_benefits_benefit_id ON user_benefits(benefit_id)',
    );
    await db.execute(
      'CREATE INDEX idx_user_benefits_earned_at ON user_benefits(earned_at)',
    );
  }

  /// Create sync_queue table (tracks pending changes to sync)
  Future<void> _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Index for processing queue
    await db.execute(
      'CREATE INDEX idx_sync_queue_created_at ON sync_queue(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id)',
    );
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete the entire database (useful for testing/reset)
  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'benefit_app.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// Clear all tables (useful for logout/reset)
  ///
  /// Tables are deleted in reverse dependency order to respect foreign keys.
  /// Missing tables (older DB versions) are silently ignored.
  Future<void> clearAllTables() async {
    final db = await database;

    // List of tables in reverse dependency order
    final tables = [
      'sync_queue',
      'user_benefits',
      'activity_segments',
      'session_biometric_data',
      'session_motion_data',
      'session_sensor_summary',
      'health_platform_data',
      'wearable_devices',
      'gps_points',
      'continuous_tracking_state',
      'sessions',
      'continuous_tracking_config',
      'user_biometrics_reported',
      'user_preferences',
      'benefits',
      'users',
    ];

    await db.transaction((txn) async {
      for (final table in tables) {
        try {
          await txn.delete(table);
        } catch (e) {
          // Table might not exist in older DB versions - ignore
          debugPrint('Note: Could not clear table $table: $e');
        }
      }
    });
  }
}
