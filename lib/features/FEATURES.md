---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [FEATURES_OVERVIEW.md](../../documentation/architecture/FEATURES_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../database/DATABASE.md) | [PROVIDER_GUIDE.md](../presentation/PROVIDER_GUIDE.md)
---

# Feature Modules Architecture

This document describes the technical implementation of the BeneFit feature module architecture, including data persistence, sync strategies, and how to add new features.

## Architecture Overview

The app uses a **feature-based modular architecture** where each domain entity (User, Session, Benefit) is self-contained in its own module with complete data layer, sync logic, and business rules.

### Key Principles

1. **Local-First**: All data saved to SQLite first, synced to server when online
2. **Offline-Resilient**: App works fully offline, syncs when connectivity restored
3. **Feature-Isolated**: Each module is self-contained (~300 lines of code)
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
  operation TEXT NOT NULL,          -- 'create' | 'update' | 'delete'
  data TEXT NOT NULL,               -- JSON serialized entity
  created_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT
)
```

#### Indexes for Performance

```sql
-- User lookups
CREATE INDEX idx_users_email ON users(email);

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

**Get pending sync operations**
```sql
SELECT * FROM sync_queue
ORDER BY created_at ASC
LIMIT 100
```

---

## Feature Module Structure

Each feature follows this structure:

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

### Example: Session Module

```
lib/features/session/
├── domain/
│   └── session.dart                    # Session model
└── data/
    ├── session_repository.dart         # Interface: createSession(), updateSession()
    ├── session_dao.dart                # DAO: insert(), update(), findById()
    ├── session_sync_strategy.dart      # Sync: conflict resolution rules
    └── session_repository_impl.dart    # Combines DAO + Sync
```

---

## Sync Strategies

Each entity has custom sync behavior defined in its `*_sync_strategy.dart` file.

### User Sync Strategy

**Priority**: Medium
**Conflict Resolution**: Remote wins
**Rationale**: User profiles updated infrequently, server is source of truth

```dart
class UserSyncStrategy extends BaseSyncStrategy<User> {
  @override
  int get maxRetries => 3;

  @override
  int get retryDelaySeconds => 5;

  @override
  Future<User> resolveConflict(User local, User remote) async {
    // Remote always wins for user profile
    return remote;
  }
}
```

### Session Sync Strategy

**Priority**: High
**Conflict Resolution**: Complex rules based on session status
**Rationale**: Active sessions must stay local, completed sessions sync immediately

```dart
class SessionSyncStrategy extends BaseSyncStrategy<Session> {
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
    if (local.status.isOngoing) {
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
}
```

### Benefit Sync Strategy

**Priority**: Low
**Conflict Resolution**: Remote wins
**Rationale**: Benefits are awarded by server, simple one-way sync

```dart
class BenefitSyncStrategy extends BaseSyncStrategy<UserBenefit> {
  @override
  int get maxRetries => 3;

  @override
  int get retryDelaySeconds => 5;

  @override
  Future<UserBenefit> resolveConflict(UserBenefit local, UserBenefit remote) async {
    // Remote wins (benefits awarded by server)
    return remote;
  }
}
```

---

## Repository Pattern

### Repository Interface (Contract)

Defines the public API for data operations.

```dart
abstract class SessionRepository {
  Future<Session> createSession(Session session);
  Future<Session> updateSession(Session session);
  Future<Session?> getSessionById(String id);
  Future<List<Session>> getAllSessions({required String userId});
  Future<Session?> getActiveSession({required String userId});
}
```

### Repository Implementation

Combines DAO (database operations) + Sync (network operations).

```dart
class SessionRepositoryImpl implements SessionRepository {
  final SessionDao _dao;
  final SessionSyncStrategy _syncStrategy;
  final ConnectivityService _connectivity;

  @override
  Future<Session> createSession(Session session) async {
    // 1. Save locally first (offline-first)
    await _dao.insert(session);

    // 2. Queue for sync if online
    if (await _connectivity.isOnline()) {
      await _queueForSync(session, SyncOperation.create);
    }

    return session;
  }

  @override
  Future<Session> updateSession(Session session) async {
    // 1. Update locally
    await _dao.update(session);

    // 2. Check if should sync (only completed sessions)
    if (await _syncStrategy.shouldSync(session)) {
      if (await _connectivity.isOnline()) {
        await _queueForSync(session, SyncOperation.update);
      }
    }

    return session;
  }
}
```

---

## Data Flow

### Create Operation

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
SyncManager processes queue (FIFO)
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

```dart
class AchievementSyncStrategy extends BaseSyncStrategy<Achievement> {
  @override
  int get maxRetries => 3;

  @override
  Future<Achievement> resolveConflict(
    Achievement local,
    Achievement remote,
  ) async {
    // Define your conflict resolution logic
    return remote; // Simple: remote wins
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

### Step 7: Register in RepositoryConfig

**File**: `lib/core/config/repository_config.dart`

```dart
class RepositoryConfig {
  static dynamic getAchievementRepository() {
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

  // Enum ↔ String
  static String enumToSqlite<T extends Enum>(T value) {
    return value.name;
  }

  static T enumFromSqlite<T extends Enum>(
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

### Migration Path

1. **Phase 1** (Current): SQLite only, no server
2. **Phase 2**: Add PostgREST endpoints, keep SQLite as cache
3. **Phase 3**: Implement sync_queue processing
4. **Phase 4**: Real-time sync with conflict resolution

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
└── integration/
    └── data/
        └── session_dao_test.dart
```

---

## Summary

The feature module architecture provides:

✅ **Offline-First**: SQLite ensures app works without connectivity
✅ **Scalable**: Add new entities in 3-4 hours
✅ **Maintainable**: Each module is self-contained (~300 LOC)
✅ **Flexible Sync**: Custom strategies per entity
✅ **Future-Ready**: Designed for PostgREST migration
✅ **Production-Ready**: Conflict resolution, error handling, retry logic

For high-level overview, see [README.md](../../documentation/README.md)
For seed data documentation, see [lib/core/seed/SEED.md](../core/seed/SEED.md)