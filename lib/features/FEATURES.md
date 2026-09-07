---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [FEATURES_OVERVIEW.md](../../documentation/architecture/FEATURES_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../database/DATABASE.md) | [PROVIDER_GUIDE.md](../presentation/PROVIDER_GUIDE.md)
>
> **Stand:** 2026-08-28 · **Verified against:** DB schema v12, branch `feat/phase-2-background-tracking` (WP1–WP5 done, WP6 device smoke open)
---

# Feature Modules Architecture

This document describes the technical implementation of the BeneFit feature module architecture, including data persistence, sync strategies, and how to add new features.

## Architecture Overview

The app uses a **feature-based modular architecture** where each domain entity (User, Session, Benefit) is self-contained in its own module with complete data layer, sync logic, and business rules.

### Feature Modules

`lib/features/` currently contains the following modules:

| Module | Responsibility | Notes |
|---|---|---|
| `user` | User profile, biometrics, preferences | Full repository + DAO + sync-strategy pattern (`user_dao`, `user_biometrics_dao`, `user_preferences_dao`) |
| `session` | Activity sessions, GPS, continuous tracking, segments | Repository + DAO + sync-strategy; also `gps_point_dao`, `continuous_tracking_*`, `activity_segment_dao`. Ships a **second, local-only** repository (`ContinuousTrackingRepository`) with no sync strategy — see [below](#the-sessions-second-repository-continuoustrackingrepository) |
| `benefit` | Benefits catalog & earned rewards | Repository + DAO + sync-strategy; `benefit_dao` manages both `benefits` and `user_benefits` |
| `auth` | Authentication, tokens, password validation | `auth_service`, `token_storage`, domain result types, widgets (no DAO/sync-strategy) |
| `security` | Biometric app lock, rate limiting, session timeout | Services + preferences storage (no DAO) |
| `wearable_integration` | Health Connect / HealthKit / BLE, sensor data | DAOs under `data/daos/`, sources, `health_sync_service` |
| `shared` | Cross-cutting infrastructure | `database/database_helper.dart`, `sync/base_sync_strategy.dart`, `sensors/`, `utils/` (connectivity, type converters) |

The full repository + DAO + sync-strategy pattern below applies to the three synced entities (`user`, `session`, `benefit`). The `auth`, `security`, `wearable_integration`, and `shared` modules use service/source classes and (for wearable) DAOs without a `*_sync_strategy.dart`.

**Per-module detail docs:** [SECURITY.md](security/SECURITY.md) · [SENSORS.md](shared/sensors/SENSORS.md) · [WEARABLE_INTEGRATION.md](wearable_integration/WEARABLE_INTEGRATION.md) · [WIDGETS.md](auth/widgets/WIDGETS.md)

**Size (2026-08-28):** 78 `.dart` files / ~13 900 lines across the seven modules — `benefit` 671 (8 files), `security` 789 (5), `user` 1 020 (9), `shared` 1 908 (9), `auth` 2 126 (15), `session` 3 250 (17), `wearable_integration` 4 096 (15).

### Key Principles

1. **Local-First**: All data saved to SQLite first, synced to server when online
2. **Offline-Resilient**: App works fully offline, syncs when connectivity restored
3. **Feature-Isolated**: Each module owns its own data layer. Allowed dependencies today: any module → `shared`; `auth` → `user` (`AuthService` uses `UserRepository`, `auth/data/auth_service.dart:5`); `session` ↔ `wearable_integration` (sensor summaries — `session/data/session_repository.dart:4` and `wearable_integration/data/services/health_sync_service.dart:8`, i.e. a cycle). **Known violation to clean up:** `shared/sensors/gps_sensor.dart:9` and `shared/sensors/sensor_manager.dart:6` import `session/domain/gps_point.dart`, so the cross-cutting `shared` module currently depends on a feature module.
4. **Custom Sync**: Each entity has its own sync strategy and conflict resolution

---

## Database Layer

### SQLite (Local Storage)

All data is stored locally using `sqflite` for offline-first architecture.

#### Tables

**users**
```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  password_hash TEXT NOT NULL,                    -- SHA-256 hashed password
  display_name TEXT,
  gender TEXT,
  date_of_birth INTEGER,
  timezone TEXT,
  profile_image_path TEXT,
  is_verified INTEGER DEFAULT 0,
  verification_status TEXT DEFAULT 'unverified',  -- 'unverified' | 'pending' | 'verified'
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
```

**sessions**
```sql
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  tracking_mode TEXT NOT NULL,      -- 'manual' | 'continuousDaily'
  activity_type TEXT NOT NULL,      -- 'running' | 'walking' | 'cycling' etc.
  status TEXT NOT NULL,             -- 'active' | 'paused' | 'completed' | 'cancelled'
  start_time INTEGER NOT NULL,
  end_time INTEGER,
  duration_seconds INTEGER,
  distance_meters REAL,
  tracking_date INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)
```

**benefits**
```sql
CREATE TABLE benefits (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  discount_amount REAL NOT NULL,
  required_distance INTEGER,        -- Meters needed to unlock
  required_sessions INTEGER,        -- Sessions needed to unlock
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
```

**user_benefits** (Earned rewards)
```sql
CREATE TABLE user_benefits (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  benefit_id TEXT NOT NULL,
  session_id TEXT NOT NULL,         -- Session that earned the benefit
  earned_at INTEGER NOT NULL,
  status TEXT DEFAULT 'earned',     -- 'earned' | 'redeemed'
  redeemed_at INTEGER,              -- Timestamp when redeemed
  redemption_code TEXT,             -- Code generated on redemption
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (benefit_id) REFERENCES benefits(id) ON DELETE CASCADE,
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
)
```

**sync_queue** (Pending operations)
```sql
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,        -- 'user' | 'session' | 'benefit'
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,          -- 'create' | 'update' | 'delete' (SyncOperation enum);
                                    -- BenefitRepositoryImpl also passes 'redeem'
                                    -- (benefit_repository_impl.dart:119) — extend the
                                    -- enum before the queue is wired up
  data TEXT NOT NULL,               -- JSON serialized entity
  created_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT
)
```

> **Note:** The five tables above are the core entities. The full schema (version **12**) also includes profile tables (`user_biometrics_reported`, `user_preferences`), GPS tracking (`gps_points`), wearable integration (`wearable_devices`, `session_biometric_data`, `session_motion_data`, `session_sensor_summary`, `health_platform_data`), and continuous-tracking tables (`continuous_tracking_config`, `continuous_tracking_state`, `activity_segments`) — 16 tables in total. Schema v12 added no new tables or columns: it is a data-integrity migration (orphan-row cleanup, email de-duplication with session/benefit history re-parenting, and a UNIQUE email index — `database_helper.dart:_migrateToV12`). See [DATABASE.md](../../database/DATABASE.md) for the complete schema, all columns, and migration history.

#### Indexes for Performance

```sql
-- User lookups (v12 replaced the earlier non-unique idx_users_email)
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);

-- Session queries
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_tracking_date ON sessions(tracking_date);
CREATE INDEX idx_sessions_start_time ON sessions(start_time);

-- Benefit queries
CREATE INDEX idx_user_benefits_user_id ON user_benefits(user_id);
CREATE INDEX idx_user_benefits_benefit_id ON user_benefits(benefit_id);
CREATE INDEX idx_user_benefits_earned_at ON user_benefits(earned_at);

-- Sync queue
CREATE INDEX idx_sync_queue_created_at ON sync_queue(created_at);
CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id);
```

#### Key Queries

**Get active sessions**
```sql
SELECT * FROM sessions
WHERE status = 'active'
```

**Calculate total savings (JOIN)**
```sql
SELECT SUM(b.discount_amount) as total
FROM user_benefits ub
INNER JOIN benefits b ON ub.benefit_id = b.id
WHERE ub.user_id = ?
```

**Get sessions by date range**
```sql
SELECT * FROM sessions
WHERE user_id = ?
  AND start_time >= ?
  AND start_time <= ?
ORDER BY start_time DESC
```

**Get pending sync operations** — **Status: planned.** No code reads or writes `sync_queue` today; the only production statement touching it is the `DELETE` in `DatabaseHelper.clearAllTables`.
```sql
SELECT * FROM sync_queue
ORDER BY created_at ASC
LIMIT 100
```

---

## Feature Module Structure

Each **synced** feature (`user`, `session`, `benefit`) follows this baseline; the real modules add folders on top of it:

```
lib/features/<feature_name>/
├── domain/                      # Business models
│   └── <feature>.dart          # Domain entity (User, Session, Benefit)
└── data/                        # Data layer
    ├── <feature>_repository.dart       # Interface (contract)
    ├── <feature>_dao.dart              # SQLite CRUD operations
    ├── <feature>_sync_strategy.dart    # Sync logic & conflict resolution
    └── <feature>_repository_impl.dart  # Implementation (DAO + Sync)
```

**Other shapes:** `auth` adds `utils/` and `widgets/` and has **no DAO and no repository** (service classes over secure storage); `security` has `data/` + `services/` and no DAO either; `wearable_integration` puts its repository interface in `domain/repositories/` and implements it with three platform **sources** (`HealthConnectSource`, `HealthKitSource`, `BleDataSource`) instead of a `*_repository_impl.dart`.

### Example: Session Module

The session module is the largest one and does *not* fit the 5-file template — it holds 17 files:

```
lib/features/session/                        # 17 files, ~3 250 lines
├── domain/                                  # 6 models
│   ├── session.dart
│   ├── activity_entry.dart
│   ├── activity_segment.dart
│   ├── gps_point.dart
│   ├── continuous_tracking_config.dart
│   └── continuous_tracking_state.dart
├── data/                                    # 10 files — TWO repository pairs
│   ├── session_repository.dart              # Interface: createSession(), finalizeSession(), …
│   ├── session_repository_impl.dart         # Combines DAO + Sync + transaction
│   ├── session_sync_strategy.dart           # Sync: conflict resolution rules
│   ├── session_dao.dart                     # DAO: insert(), update(), findById()
│   ├── continuous_tracking_repository.dart      # 2nd interface — local-only
│   ├── continuous_tracking_repository_impl.dart # over 3 DAOs, no sync strategy
│   ├── continuous_tracking_config_dao.dart
│   ├── continuous_tracking_state_dao.dart
│   ├── activity_segment_dao.dart
│   └── gps_point_dao.dart
└── utils/
    └── distance_calculator.dart
```

#### The session's second repository: `ContinuousTrackingRepository`

`ContinuousTrackingRepository` (`session/data/continuous_tracking_repository.dart:9`) declares 18 methods over `ContinuousTrackingConfigDao`, `ContinuousTrackingStateDao` and `ActivitySegmentDao`. It is deliberately **local-only**: no sync strategy, no `ConnectivityService`, no `queueForSync` call anywhere in its implementation.

> **Status: not wired.** It is not exposed through `RepositoryConfig` and, as of 2026-08-28, has **no callers outside its own two files**. Register it in `RepositoryConfig` before consuming it from a provider.

---

## Sync Strategies

Each entity has custom sync behavior defined in its `*_sync_strategy.dart` file.

> **The three snippets below are excerpts, not compilable files.** `BaseSyncStrategy` declares six members every concrete strategy must supply — `shouldSync`, `uploadToRemote`, `downloadFromRemote`, `queueForSync`, `processQueue` and the getter `requiresSync` (`shared/sync/base_sync_strategy.dart:16-56`); only `resolveConflict`, `maxRetries` and `retryDelaySeconds` have defaults. The excerpts show just the sync-decision and conflict-resolution overrides. The four remote-facing methods are **Phase-1 stubs** in all three real files: `uploadToRemote` returns `Future.value(true)`, `downloadFromRemote` throws `UnimplementedError('PostgREST not yet configured')`, and `queueForSync` / `processQueue` are no-ops.

### User Sync Strategy

**Priority**: Medium
**Conflict Resolution**: Remote wins
**Rationale**: User profiles updated infrequently, server is source of truth

```dart
class UserSyncStrategy extends BaseSyncStrategy<User> {
  @override
  bool get requiresSync => true;

  @override
  Future<bool> shouldSync(User entity) async {
    // Users always sync when changed
    return true;
  }

  @override
  Future<User> resolveConflict(User local, User remote) async {
    // Remote always wins for user profile
    return remote;
  }

  // maxRetries (3) and retryDelaySeconds (5) inherited from BaseSyncStrategy
  // uploadToRemote / downloadFromRemote / queueForSync / processQueue omitted — see source
}
```

### Session Sync Strategy

**Priority**: High
**Conflict Resolution**: Complex rules based on session status
**Rationale**: Active sessions must stay local, completed sessions sync immediately

```dart
class SessionSyncStrategy extends BaseSyncStrategy<Session> {
  @override
  bool get requiresSync => true;

  @override
  int get maxRetries => 5;

  @override
  int get retryDelaySeconds => 10;

  @override
  Future<bool> shouldSync(Session entity) async {
    // Only sync completed sessions
    return entity.status == SessionStatus.completed;
  }

  @override
  Future<Session> resolveConflict(Session local, Session remote) async {
    // Case 1: Local is active/paused → ALWAYS keep local
    if (local.status == SessionStatus.active ||
        local.status == SessionStatus.paused) {
      return local;
    }

    // Case 2: Both completed → Keep session with later endTime
    if (local.status == SessionStatus.completed &&
        remote.status == SessionStatus.completed) {
      if (local.endTime != null && remote.endTime != null) {
        return local.endTime!.isAfter(remote.endTime!) ? local : remote;
      }
    }

    // Case 3: Remote completed, local not → Take remote
    if (remote.status == SessionStatus.completed &&
        local.status != SessionStatus.completed) {
      return remote;
    }

    // Default: Remote wins
    return remote;
  }

  // uploadToRemote / downloadFromRemote / queueForSync / processQueue omitted — see source
}
```

### Benefit Sync Strategy

**Priority**: Low
**Conflict Resolution**: Remote wins
**Rationale**: Benefits are awarded by server, simple one-way sync

```dart
class BenefitSyncStrategy extends BaseSyncStrategy<UserBenefit> {
  @override
  bool get requiresSync => true;

  @override
  int get maxRetries => 3;

  @override
  int get retryDelaySeconds => 5;

  @override
  Future<UserBenefit> resolveConflict(UserBenefit local, UserBenefit remote) async {
    // Remote wins (benefits awarded by server)
    return remote;
  }

  // shouldSync omitted — the real class returns true for every UserBenefit
  // uploadToRemote / downloadFromRemote / queueForSync / processQueue omitted — see source
}
```

---

## Repository Pattern

### Repository Interface (Contract)

Defines the public API for data operations. `SessionSensorSummary` comes from `lib/features/wearable_integration/domain/sensor_data_point.dart` — one of the two `session` ↔ `wearable_integration` edges noted above.

```dart
abstract class SessionRepository {
  Future<List<Session>> getAllSessions({required String userId});
  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required SessionStatus status,
  });
  Future<List<Session>> getSessionsByActivityType({
    required String userId,
    required ActivityType activityType,
  });
  Future<Session> getSessionById(String sessionId);
  Future<Session> createSession(Session session);
  Future<void> updateSession(Session session);

  /// Atomically persist a completed session and its optional sensor [summary]
  /// in one DB transaction, then sync (outside the transaction).
  Future<void> finalizeSession(
    Session completed, {
    SessionSensorSummary? summary,
  });

  Future<void> deleteSession(String sessionId);
  Future<List<Session>> getSessionsInDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  });
}
```

### Repository Implementation

Combines DAO (database operations) + Sync (network operations).

```dart
class SessionRepositoryImpl implements SessionRepository {
  final SessionDao _dao;
  final SessionSyncStrategy _syncStrategy;
  final ConnectivityService _connectivity;
  final SessionSensorSummaryDao _summaryDao;

  SessionRepositoryImpl({
    required SessionDao dao,
    required SessionSyncStrategy syncStrategy,
    required ConnectivityService connectivity,
    SessionSensorSummaryDao? summaryDao, // optional — defaulted below
  })  : _dao = dao,
        _syncStrategy = syncStrategy,
        _connectivity = connectivity,
        _summaryDao = summaryDao ?? SessionSensorSummaryDao();

  /// Factory constructor with default dependencies
  factory SessionRepositoryImpl.create() {
    return SessionRepositoryImpl(
      dao: SessionDao(),
      syncStrategy: SessionSyncStrategy(),
      connectivity: ConnectivityService(),
    );
  }

  @override
  Future<Session> createSession(Session session) async {
    // 1. Save locally first (offline-first)
    await _dao.insert(session);

    // 2. Active/paused sessions stay local; only completed sessions sync
    if (session.status == SessionStatus.completed) {
      await _syncCompletedSession(session);
    }

    return session;
  }

  @override
  Future<void> updateSession(Session session) async {
    // 1. Update locally first
    await _dao.update(session);

    // 2. Completed sessions sync immediately (high priority);
    //    active/paused sessions wait until they transition to completed
    if (session.status == SessionStatus.completed) {
      await _syncCompletedSession(session);
    }
  }

  @override
  Future<void> finalizeSession(
    Session completed, {
    SessionSensorSummary? summary,
  }) async {
    // Session row + sensor summary commit atomically, so a crash can't leave
    // a completed session without its summary.
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      await _dao.update(completed, executor: txn);
      if (summary != null) {
        await _summaryDao.upsert(summary, executor: txn);
      }
    });

    // Sync only AFTER the durable commit — never inside the transaction.
    if (completed.status == SessionStatus.completed) {
      await _syncCompletedSession(completed);
    }
  }

  /// Upload completed session, queueing for later when offline or on failure
  Future<void> _syncCompletedSession(Session session) async {
    if (await _connectivity.isOnline()) {
      try {
        final success = await _syncStrategy.uploadToRemote(session);
        if (!success) {
          await _syncStrategy.queueForSync(session, 'update');
        }
      } catch (e) {
        await _syncStrategy.queueForSync(session, 'update');
      }
    } else {
      await _syncStrategy.queueForSync(session, 'update');
    }
  }
}
```

### Transactional Writes

`finalizeSession` is the app's session-completion write path and the only multi-table transactional write in the codebase. It persists the completed session **and** its optional `SessionSensorSummary` inside a single `db.transaction`, so a crash can never leave a completed session without its summary (or a summary without its session).

Two conventions make this work and are worth copying into new modules:

- **DAOs accept an `executor`.** `SessionDao.update(session, {DatabaseExecutor? executor})` (`session_dao.dart:123`) and `SessionSensorSummaryDao.upsert(summary, {DatabaseExecutor? executor})` (`session_sensor_summary_dao.dart:12-16`) fall back to the singleton database when no executor is passed, so they can either stand alone or join the caller's transaction.
- **Network work stays outside the transaction.** `_syncCompletedSession` runs only after the commit returns.

Source: `lib/features/session/data/session_repository_impl.dart:110-129`.

---

## Data Flow

### Create Operation

> **Note:** The diagram below depicts the **target PostgREST / Phase 2** flow. In the current Phase 1 (SQLite only), `createSession` writes to SQLite and stops there for active/paused sessions; only **completed** sessions are routed to sync (`uploadToRemote` is currently stubbed to return success, and `downloadFromRemote` throws `UnimplementedError`).

```
User Action (e.g., "Start Session")
    ↓
Provider calls Repository.createSession()
    ↓
Repository saves to SQLite via DAO
    ↓
Repository checks connectivity
    ↓ (if online)
Repository queues sync operation
    ↓
Background sync sends to server
    ↓
Server responds with updated entity
    ↓
Repository updates local SQLite
```

### Offline → Online Sync

> **Status: not implemented.** The flow below is the target design. None of it runs today: `queueForSync` and `processQueue` are no-ops in all three strategies, nothing inserts into or reads the `sync_queue` table, and **no `SyncManager` class exists anywhere in the repository**.

```
User goes offline
    ↓
Operations saved to SQLite only
    ↓
Sync operations queued in sync_queue table
    ↓
User comes back online
    ↓
ConnectivityService detects online
    ↓
Sync coordinator processes queue (FIFO)   ← not yet implemented
    ↓
For each queued operation:
  - Send to server
  - Handle conflicts (use SyncStrategy)
  - Update local database
  - Remove from queue
```

---

## Adding New Features

To add a new entity (e.g., "Achievement"):

### Step 1: Create Module Structure

```bash
mkdir -p lib/features/achievement/domain
mkdir -p lib/features/achievement/data
```

### Step 2: Create Domain Model

**File**: `lib/features/achievement/domain/achievement.dart`

```dart
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconUrl;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'iconUrl': iconUrl,
  };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    iconUrl: json['iconUrl'],
  );
}
```

### Step 3: Create DAO

**File**: `lib/features/achievement/data/achievement_dao.dart`

```dart
class AchievementDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Achievement?> findById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'achievements',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isEmpty ? null : _fromMap(results.first);
  }

  Future<void> insert(Achievement achievement) async {
    final db = await _dbHelper.database;
    await db.insert('achievements', _toMap(achievement));
  }

  // ... other CRUD operations
}
```

### Step 4: Create Sync Strategy

**File**: `lib/features/achievement/data/achievement_sync_strategy.dart`

`BaseSyncStrategy` declares six abstract members, so a concrete strategy must supply all of them or the file will not compile:

```dart
class AchievementSyncStrategy extends BaseSyncStrategy<Achievement> {
  @override
  bool get requiresSync => true;

  @override
  int get maxRetries => 3;

  @override
  Future<bool> shouldSync(Achievement entity) async => true;

  @override
  Future<bool> uploadToRemote(Achievement entity) async {
    // Phase 1 (SQLite only): simulate success
    return Future.value(true);
  }

  @override
  Future<Achievement> downloadFromRemote(String entityId) async {
    throw UnimplementedError('PostgREST not yet configured');
  }

  @override
  Future<Achievement> resolveConflict(
    Achievement local,
    Achievement remote,
  ) async {
    // Define your conflict resolution logic
    return remote; // Simple: remote wins
  }

  @override
  Future<void> queueForSync(Achievement entity, String operation) async {
    // Phase 1: no-op
  }

  @override
  Future<void> processQueue() async {
    // Phase 1: no-op
  }
}
```

### Step 5: Create Repository

**File**: `lib/features/achievement/data/achievement_repository.dart` (interface)

```dart
abstract class AchievementRepository {
  Future<List<Achievement>> getAllAchievements();
  Future<Achievement?> getAchievementById(String id);
}
```

**File**: `lib/features/achievement/data/achievement_repository_impl.dart`

```dart
class AchievementRepositoryImpl implements AchievementRepository {
  final AchievementDao _dao;
  final AchievementSyncStrategy _syncStrategy;

  // Implementation...
}
```

### Step 6: Add to Database Schema

Update `database_helper.dart`:

```dart
Future<void> _createAchievementsTable(Database db) async {
  await db.execute('''
    CREATE TABLE achievements (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      icon_url TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');
}
```

Defining the creator is not enough — three further edits in `lib/features/shared/database/database_helper.dart` are mandatory:

1. Bump `static const int dbVersion` (line 36, currently `12`) to `13`.
2. Call `await _createAchievementsTable(db);` from `_onCreate` (line 95) — it currently invokes eight creators plus `_migrateToV4` and `_createContinuousTrackingTables`.
3. Add an upgrade branch to `_onUpgrade` (line 177): `if (oldVersion < 13) { await _createAchievementsTable(db); }`.

Write the creator with `CREATE TABLE IF NOT EXISTS` so the *same* method can serve both paths — this is the pattern `_createContinuousTrackingTables` uses for v11 (defined at `database_helper.dart:111`, called from `_onCreate` at `:107` and from `_onUpgrade` at `:226`). Then document the migration in [DATABASE.md](../../database/DATABASE.md).

### Step 7: Register in RepositoryConfig

**File**: `lib/core/config/repository_config.dart`

```dart
class RepositoryConfig {
  // Return the repository *interface*, not `dynamic`, so the composition root
  // keeps compile-time type safety (matches the existing user/session/benefit getters).
  static AchievementRepository getAchievementRepository() {
    return AchievementRepositoryImpl.create();
  }
}
```

---

## Type Converters

SQLite stores limited types (INTEGER, REAL, TEXT, BLOB). Use converters for complex types.

**File**: `lib/features/shared/utils/sqlite_type_converters.dart`

```dart
class SqliteTypeConverters {
  // DateTime ↔ milliseconds
  static int dateTimeToSqlite(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch;
  }

  static DateTime dateTimeFromSqlite(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  // Enum ↔ String (enums expose toJson()/fromJson())
  static String enumToSqlite<T>(T enumValue) {
    return (enumValue as dynamic).toJson() as String;
  }

  static T enumFromSqlite<T>(
    String value,
    T Function(String) fromJson,
  ) {
    return fromJson(value);
  }

  // Boolean ↔ Integer (0 or 1)
  static int boolToSqlite(bool value) {
    return value ? 1 : 0;
  }

  static bool boolFromSqlite(int value) {
    return value == 1;
  }
}
```

---

## Future: PostgREST Integration

The current SQLite implementation is designed to be compatible with future PostgREST integration.

### Planned Architecture

```
Flutter App (SQLite local)
    ↓ HTTP REST
PostgREST API
    ↓
PostgreSQL (Server database)
```

### Sync Migration Stages

1. **Stage 1** (Current): SQLite only, no server
2. **Stage 2**: Add PostgREST endpoints, keep SQLite as cache
3. **Stage 3**: Implement sync_queue processing
4. **Stage 4**: Real-time sync with conflict resolution

> These stages describe remote sync only. They are **not** the same numbering as [ROADMAP.md](../../documentation/ROADMAP.md), whose "Phase 2 — Echtes Backend, Sync & Auth" also bundles the background-tracking work currently in progress on branch `feat/phase-2-background-tracking`. Where this document says "Phase 1", it always means *Stage 1 — SQLite only*.

The feature module structure already supports this migration:
- Repository interfaces remain unchanged
- Sync strategies already implement conflict resolution
- Only need to implement actual HTTP calls in repository implementations

---

## Performance Considerations

### Indexing Strategy

- Index all foreign keys for JOIN performance
- Index commonly queried fields (status, dates)
- Index fields used in WHERE clauses

### Query Optimization

- Use prepared statements (sqflite does this automatically)
- Limit result sets with LIMIT clauses
- Use transactions for bulk operations
- Avoid N+1 queries (use JOINs)

### Best Practices

✅ **DO**
- Keep DAOs pure (no business logic)
- Use transactions for related operations
- Index foreign keys and filter columns
- Handle null values properly

❌ **DON'T**
- Put business logic in DAOs
- Forget to call notifyListeners() in providers
- Skip conflict resolution in sync strategies
- Store large blobs in SQLite (use file paths)

---

## Testing Strategy

Each feature module should have:

1. **Unit Tests**: Test business logic and sync strategies
2. **Integration Tests**: Test DAO operations with real SQLite
3. **Widget Tests**: Test provider state management

Example test structure:
```
test/
├── unit/
│   ├── domain/
│   │   └── session_formatting_test.dart
│   ├── shared/
│   │   ├── utils/
│   │   │   └── sqlite_type_converters_test.dart
│   │   └── sync/
│   │       └── session_sync_strategy_test.dart
│   └── providers/
│       └── benefit_provider_test.dart
└── integration/                  # exists but is EMPTY — DAO integration tests still TODO
```

All four `test/unit/**` paths above exist. `test/integration/` currently contains no files, so item 2 of the list above is aspirational. The seams for it are already in place: `DatabaseHelper.debugDatabase` (`database_helper.dart:32`) injects the connection every DAO uses, and `DatabaseHelper.openAppDatabase(factory, path, {version})` (`database_helper.dart:52-56`) opens the real schema against an in-process `sqflite-ffi` database — the migration test `test/features/shared/database/migration_test.dart` already uses that seam.

As of 2026-08-28 the repo has **52 test files under `test/`** plus one under `integration_test/`, **823 tests, all passing**.

---

## Summary

The feature module architecture provides:

✅ **Offline-First**: SQLite ensures app works without connectivity
✅ **Scalable**: Add new entities in 3-4 hours
✅ **Maintainable**: Clear module boundaries; modules currently range from ~670 LOC (`benefit`) to ~4 100 LOC (`wearable_integration`)
✅ **Flexible Sync**: Custom strategies per entity
✅ **Future-Ready**: Designed for PostgREST migration
⚠️ **Sync scaffolded, not live**: conflict-resolution rules are written and unit-tested, but `resolveConflict` has **no production caller** and `maxRetries` / `retryDelaySeconds` are read by no code. The only strategy method called from production is `shouldSync` (`user_repository_impl.dart:141`). The retry loop and the queue processor still have to be built.

For high-level overview, see [README.md](../../documentation/README.md)
For seed data documentation, see [lib/core/seed/SEED.md](../core/seed/SEED.md)