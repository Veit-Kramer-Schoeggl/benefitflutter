---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [DATABASE_OVERVIEW.md](../documentation/data/DATABASE_OVERVIEW.md) - High-level concepts
>
> **Related:** [FEATURES.md](../lib/features/FEATURES.md) | [SEED.md](../lib/core/seed/SEED.md)
---

# BeneFit Database Schema

Reference [database/schema_actual.puml](schema_actual.puml) for implemented tables and [database/schema_planned.puml](schema_planned.puml) for full roadmap.

## Overview

- **Database:** SQLite (benefit_app.db)
- **Current Version:** 11 (after continuous tracking tables migration)
- **Pattern:** Offline-first with sync queue
- **Location:** Platform databases directory (`getDatabasesPath()`)

## Core Tables

### users

**Purpose:** User account management and profile data

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique user identifier
- `name` (TEXT, NOT NULL) - User's full name
- `email` (TEXT, NOT NULL) - User's email address
- `password_hash` (TEXT, NOT NULL) - SHA-256 hashed password (v7, hashed in v10)
- `display_name` (TEXT) - Display name for profile (v3)
- `gender` (TEXT) - User's gender (male/female/other) (v3)
- `date_of_birth` (INTEGER) - Date of birth timestamp (v3)
- `timezone` (TEXT) - User's timezone (v3)
- `profile_image_path` (TEXT) - Path to profile image file (v5)
- `is_verified` (INTEGER) - Email verification status 0/1 (v6)
- `verification_status` (TEXT) - Verification state: 'unverified'/'pending'/'verified' (v6)
- `created_at` (INTEGER, NOT NULL) - Account creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Index on `email` (`idx_users_email`, not unique)

**Security Note:** Passwords are stored as SHA-256 hashes (64 hex characters). Plain text passwords are never stored.

### sessions

**Purpose:** Tracking session metadata (manual or continuous)

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique session identifier (UUID)
- `user_id` (TEXT, NOT NULL, FK) - Foreign key to users table
- `tracking_mode` (TEXT, NOT NULL) - "manual" or "continuousDaily"
- `activity_type` (TEXT, NOT NULL) - "running", "walking", or "cycling"
- `status` (TEXT, NOT NULL) - "active", "paused", or "completed"
- `start_time` (INTEGER, NOT NULL) - Session start timestamp (milliseconds since epoch)
- `end_time` (INTEGER, NULL) - Session end timestamp (NULL for active sessions)
- `duration_seconds` (INTEGER, NULL) - Total duration in seconds (NULL for continuous mode)
- `distance_meters` (REAL, NULL) - Total distance calculated from GPS points
- `tracking_date` (INTEGER, NULL) - Date for continuous tracking sessions
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Wearable data fields (added in v4, all NULL unless wearable data present):**
- `avg_heart_rate` (INTEGER, NULL) - Average heart rate
- `max_heart_rate` (INTEGER, NULL) - Maximum heart rate
- `min_heart_rate` (INTEGER, NULL) - Minimum heart rate
- `avg_heart_rate_variability` (REAL, NULL) - Average heart rate variability
- `total_steps` (INTEGER, NULL) - Total steps
- `avg_cadence` (REAL, NULL) - Average cadence
- `calories_burned` (REAL, NULL) - Calories burned
- `heart_rate_zones` (TEXT, NULL) - JSON-encoded heart rate zones
- `has_wearable_data` (INTEGER, DEFAULT 0) - Whether wearable data is attached
- `connected_device_ids` (TEXT, NULL) - Connected device IDs

> **Note:** The v4 wearable columns above are populated via the wearable integration tables and are not read/written by `SessionDao` (which maps only the base columns).

**Indexes:**
- Primary key on `id`
- Index on `user_id` for user session queries
- Index on `status` for filtering active/completed sessions
- Index on `tracking_date` for date-based queries
- Index on `start_time` for chronological ordering

**Constraints:**
- Foreign key: `user_id` references `users(id)` ON DELETE CASCADE

### gps_points (NEW in v2)

**Purpose:** Detailed GPS tracking data for sessions

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique GPS point identifier (UUID)
- `session_id` (TEXT, NOT NULL, FK) - Foreign key to sessions table
- `latitude` (REAL, NOT NULL) - Latitude in decimal degrees
- `longitude` (REAL, NOT NULL) - Longitude in decimal degrees
- `altitude` (REAL, NULL) - Altitude/elevation in meters
- `accuracy_meters` (REAL, NULL) - GPS accuracy in meters
- `speed_meters_per_second` (REAL, NULL) - Instantaneous speed
- `timestamp` (INTEGER, NOT NULL) - GPS point capture time (milliseconds since epoch)
- `created_at` (INTEGER, NOT NULL) - Database insertion timestamp

**Indexes:**
- Primary key on `id`
- Composite index on `(session_id, timestamp)` for efficient session queries
- Index on `created_at` for cleanup queries

**Constraints:**
- Foreign key: `session_id` references `sessions(id)` ON DELETE CASCADE

**Data Retention:**
GPS points are deleted after successful sync to server (see [GpsTrackingConfig](../lib/core/config/gps_tracking_config.dart)). Session summary (distance, duration) is retained permanently.

### user_biometrics_reported (v3)

**Purpose:** Self-reported biometric data tracking

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique biometric entry identifier (UUID)
- `user_id` (TEXT, NOT NULL, FK) - Foreign key to users table
- `report_date` (INTEGER, NOT NULL) - Date of measurement (timestamp)
- `height_cm` (INTEGER) - Height in centimeters
- `weight_kg` (REAL) - Weight in kilograms
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Index on `user_id` for user queries
- Index on `report_date` for chronological queries

**Constraints:**
- Foreign key: `user_id` references `users(id)` ON DELETE CASCADE

**Usage:**
Stores height, weight, and other biometric measurements. Multiple entries allowed for tracking changes over time. Latest entry used for profile display.

### user_preferences (v3)

**Purpose:** User app preferences and settings (one-to-one with User)

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique preferences identifier (UUID)
- `user_id` (TEXT, NOT NULL, UNIQUE, FK) - Foreign key to users table
- `default_location_city` (TEXT) - Default location/country for profile
- `distance_unit` (TEXT, NOT NULL, DEFAULT 'metric') - Distance unit preference
- `temperature_unit` (TEXT, NOT NULL, DEFAULT 'celsius') - Temperature unit preference
- `weight_unit` (TEXT, NOT NULL, DEFAULT 'kg') - Weight unit preference
- `theme` (TEXT, NOT NULL, DEFAULT 'system') - App theme (light/dark/system)
- `language` (TEXT, NOT NULL, DEFAULT 'en') - Language preference
- `timezone` (TEXT) - User's timezone
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Unique index on `user_id` (one-to-one relationship)

**Constraints:**
- Foreign key: `user_id` references `users(id)` ON DELETE CASCADE

### benefits

**Purpose:** Reward definitions and discount information

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique benefit identifier
- `title` (TEXT, NOT NULL) - Benefit title
- `description` (TEXT, NOT NULL) - Benefit description
- `discount_amount` (REAL, NOT NULL) - Discount percentage or amount
- `required_distance` (INTEGER, NULL) - Required distance in meters (if applicable)
- `required_sessions` (INTEGER, NULL) - Required number of sessions (if applicable)
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`

### user_benefits

**Purpose:** Join table tracking earned benefits

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique record identifier
- `user_id` (TEXT, NOT NULL, FK) - Foreign key to users table
- `benefit_id` (TEXT, NOT NULL, FK) - Foreign key to benefits table
- `session_id` (TEXT, NOT NULL, FK) - Session that triggered earning the benefit
- `earned_at` (INTEGER, NOT NULL) - Timestamp when benefit was earned
- `status` (TEXT, DEFAULT 'earned') - Redemption state: 'earned' or 'redeemed' (v8)
- `redeemed_at` (INTEGER, NULL) - Timestamp when benefit was redeemed (v8)
- `redemption_code` (TEXT, NULL) - Code generated on redemption (v9)
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Index on `user_id` for user benefit queries
- Index on `benefit_id` for benefit usage queries
- Index on `earned_at` for chronological ordering

**Constraints:**
- Foreign key: `user_id` references `users(id)` ON DELETE CASCADE
- Foreign key: `benefit_id` references `benefits(id)` ON DELETE CASCADE
- Foreign key: `session_id` references `sessions(id)` ON DELETE CASCADE

### sync_queue

**Purpose:** Offline-first sync tracking

**Fields:**
- `id` (INTEGER, PRIMARY KEY, AUTOINCREMENT) - Auto-incrementing queue entry identifier
- `entity_type` (TEXT, NOT NULL) - Type of entity ("session", "user_benefit", etc.)
- `entity_id` (TEXT, NOT NULL) - ID of the entity to sync
- `operation` (TEXT, NOT NULL) - Operation type ("create", "update", "delete")
- `data` (TEXT, NOT NULL) - JSON-encoded entity data
- `created_at` (INTEGER, NOT NULL) - Queue entry creation timestamp
- `retry_count` (INTEGER, DEFAULT 0) - Number of sync attempts
- `last_error` (TEXT, NULL) - Last sync error message

**Indexes:**
- Primary key on `id`
- Index on `created_at` for FIFO processing
- Composite index on `(entity_type, entity_id)` for entity lookups

> **Note:** `sync_queue` is the only table with an INTEGER AUTOINCREMENT primary key. There is no dedicated DAO; it is referenced only by `clearAllTables()`.

**Notes:**
Sync queue entries are deleted after successful sync. Failed syncs are retried with exponential backoff.

## Wearable Integration Tables (v4)

DAOs live in `lib/features/wearable_integration/data/daos/`.

### wearable_devices

**Purpose:** Registry of connected wearable devices

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique device identifier
- `user_id` (TEXT, NOT NULL, FK) - Foreign key to users table
- `name` (TEXT, NOT NULL) - Device display name
- `device_type` (TEXT, NOT NULL) - Device type
- `integration_source` (TEXT, NOT NULL) - Integration source
- `connection_status` (TEXT, NOT NULL) - Connection status
- `capabilities` (TEXT, NOT NULL) - JSON-encoded capabilities
- `last_sync_time` (INTEGER, NULL) - Last sync timestamp
- `metadata` (TEXT, NULL) - Optional metadata
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Index on `user_id` (`idx_devices_user`)

**Constraints:**
- Foreign key: `user_id` references `users(id)` ON DELETE CASCADE

### session_biometric_data

**Purpose:** Raw biometric sensor readings (heart rate, HRV, SpO2, temperature)

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique reading identifier
- `session_id` (TEXT, NOT NULL, FK) - Foreign key to sessions table
- `device_id` (TEXT, NULL, FK) - Foreign key to wearable_devices table
- `sensor_type` (TEXT, NOT NULL) - Sensor type
- `value` (REAL, NOT NULL) - Reading value
- `timestamp` (INTEGER, NOT NULL) - Reading capture time
- `accuracy` (REAL, NULL) - Reading accuracy
- `metadata` (TEXT, NULL) - Optional metadata
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp

**Indexes:**
- Primary key on `id`
- Composite index on `(session_id, sensor_type)` (`idx_biometric_session_type`)
- Index on `timestamp` (`idx_biometric_timestamp`)

**Constraints:**
- Foreign key: `session_id` references `sessions(id)` ON DELETE CASCADE
- Foreign key: `device_id` references `wearable_devices(id)` ON DELETE SET NULL

### session_motion_data

**Purpose:** Raw motion sensor readings (cadence, power, steps, stride). Same column shape as `session_biometric_data`.

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique reading identifier
- `session_id` (TEXT, NOT NULL, FK) - Foreign key to sessions table
- `device_id` (TEXT, NULL, FK) - Foreign key to wearable_devices table
- `sensor_type` (TEXT, NOT NULL) - Sensor type
- `value` (REAL, NOT NULL) - Reading value
- `timestamp` (INTEGER, NOT NULL) - Reading capture time
- `accuracy` (REAL, NULL) - Reading accuracy
- `metadata` (TEXT, NULL) - Optional metadata
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp

**Indexes:**
- Primary key on `id`
- Composite index on `(session_id, sensor_type)` (`idx_motion_session_type`)
- Index on `timestamp` (`idx_motion_timestamp`)

**Constraints:**
- Foreign key: `session_id` references `sessions(id)` ON DELETE CASCADE
- Foreign key: `device_id` references `wearable_devices(id)` ON DELETE SET NULL

### session_sensor_summary

**Purpose:** Aggregated per-session sensor metrics (kept permanently)

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique summary identifier
- `session_id` (TEXT, NOT NULL, UNIQUE, FK) - Foreign key to sessions table
- `avg_heart_rate` (REAL, NULL) - Average heart rate
- `max_heart_rate` (REAL, NULL) - Maximum heart rate
- `min_heart_rate` (REAL, NULL) - Minimum heart rate
- `avg_heart_rate_variability` (REAL, NULL) - Average heart rate variability
- `heart_rate_zones` (TEXT, NULL) - JSON-encoded heart rate zones
- `total_steps` (INTEGER, NULL) - Total steps
- `avg_cadence` (REAL, NULL) - Average cadence
- `avg_power` (REAL, NULL) - Average power
- `calories_burned` (REAL, NULL) - Calories burned
- `data_sources` (TEXT, NULL) - JSON-encoded data sources
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Unique constraint on `session_id`

**Constraints:**
- Foreign key: `session_id` references `sessions(id)` ON DELETE CASCADE

### health_platform_data

**Purpose:** Data imported from health platforms (Health Connect / HealthKit)

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique record identifier
- `user_id` (TEXT, NOT NULL, FK) - Foreign key to users table
- `data_type` (TEXT, NOT NULL) - Health data type
- `value` (TEXT, NOT NULL) - JSON-encoded value
- `start_time` (INTEGER, NOT NULL) - Data range start
- `end_time` (INTEGER, NOT NULL) - Data range end
- `source_app` (TEXT, NULL) - Originating app
- `metadata` (TEXT, NULL) - Optional metadata
- `synced_at` (INTEGER, NOT NULL) - Sync timestamp
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp

**Indexes:**
- Primary key on `id`
- Composite index on `(user_id, data_type)` (`idx_health_data_user_type`)
- Composite index on `(start_time, end_time)` (`idx_health_data_time`)

**Constraints:**
- Foreign key: `user_id` references `users(id)` ON DELETE CASCADE

## Continuous Tracking Tables (v11)

### continuous_tracking_config

**Purpose:** Per-user continuous tracking configuration (one-to-one with User)

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique config identifier
- `user_id` (TEXT, NOT NULL, UNIQUE, FK) - Foreign key to users table
- `is_enabled` (INTEGER, NOT NULL, DEFAULT 0) - Whether continuous tracking is enabled
- `reset_points` (TEXT, NOT NULL, DEFAULT '["03:00"]') - JSON-encoded daily reset times
- `activity_detection` (TEXT, NOT NULL, DEFAULT 'hybrid') - Activity detection mode
- `gps_interval_seconds` (INTEGER, NOT NULL, DEFAULT 300) - GPS sampling interval
- `min_displacement_meters` (INTEGER, NOT NULL, DEFAULT 100) - Minimum displacement to record
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Unique index on `user_id` (`idx_continuous_config_user`)

**Constraints:**
- Foreign key: `user_id` references `users(id)` ON DELETE CASCADE

### continuous_tracking_state

**Purpose:** Runtime state of continuous tracking (one-to-one with User)

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique state identifier
- `user_id` (TEXT, NOT NULL, UNIQUE, FK) - Foreign key to users table
- `is_active` (INTEGER, NOT NULL, DEFAULT 0) - Whether tracking is currently active
- `is_paused_for_manual` (INTEGER, NOT NULL, DEFAULT 0) - Paused due to manual session
- `current_session_id` (TEXT, NULL, FK) - Active continuous session
- `started_at` (INTEGER, NULL) - When tracking started
- `last_data_received` (INTEGER, NULL) - Last data timestamp
- `current_detected_activity` (TEXT, NULL) - Currently detected activity
- `detection_confidence` (REAL, NULL) - Detection confidence
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Unique index on `user_id` (`idx_continuous_state_user`)

**Constraints:**
- Foreign key: `user_id` references `users(id)` ON DELETE CASCADE
- Foreign key: `current_session_id` references `sessions(id)` ON DELETE SET NULL

### activity_segments

**Purpose:** Detected activity segments within a session

**Fields:**
- `id` (TEXT, PRIMARY KEY) - Unique segment identifier
- `session_id` (TEXT, NOT NULL, FK) - Foreign key to sessions table
- `activity_type` (TEXT, NOT NULL) - Activity type for the segment
- `start_time` (INTEGER, NOT NULL) - Segment start time
- `end_time` (INTEGER, NULL) - Segment end time (NULL while ongoing)
- `distance_meters` (REAL, NULL) - Segment distance
- `detection_source` (TEXT, NOT NULL) - How the segment was detected
- `confidence` (REAL, NULL) - Detection confidence
- `created_at` (INTEGER, NOT NULL) - Record creation timestamp
- `updated_at` (INTEGER, NOT NULL) - Last update timestamp

**Indexes:**
- Primary key on `id`
- Index on `session_id` (`idx_activity_segments_session`)
- Composite index on `(start_time, end_time)` (`idx_activity_segments_time`)

**Constraints:**
- Foreign key: `session_id` references `sessions(id)` ON DELETE CASCADE

## Database Migrations

### v1 (Initial Schema)
- Created `users` table
- Created `sessions` table
- Created `benefits` table
- Created `user_benefits` table
- Created `sync_queue` table
- Created all indexes

### v2 (GPS Tracking)
- Created `gps_points` table
- Created composite index on `gps_points(session_id, timestamp)`
- Created index on `gps_points(created_at)`

### v3 (Profile Support)
- Added profile fields to `users` table:
  - `display_name` TEXT
  - `gender` TEXT
  - `date_of_birth` INTEGER
  - `timezone` TEXT
- Migrated existing users with defaults:
  - `display_name` = `name`
  - `timezone` = 'UTC'
- Created `user_biometrics_reported` table
- Created `user_preferences` table with defaults for existing users:
  - `distance_unit` = 'metric'
  - `temperature_unit` = 'celsius'
  - `weight_unit` = 'kg'
  - `theme` = 'system'
  - `language` = 'en'
- Created indexes on new tables

### v4 (Wearable Integration)
- Created `wearable_devices` table for device registry
- Created `session_biometric_data` table for biometric sensor readings
- Created `session_motion_data` table for motion sensor readings
- Created `session_sensor_summary` table for aggregated metrics (kept permanently)
- Created `health_platform_data` table for health platform data
- Created indexes for all of the above
- Added wearable data columns to `sessions` table: `avg_heart_rate`, `max_heart_rate`, `min_heart_rate`, `avg_heart_rate_variability`, `total_steps`, `avg_cadence`, `calories_burned`, `heart_rate_zones`, `has_wearable_data` (DEFAULT 0), `connected_device_ids`

### v5 (Profile Image)
- Added `profile_image_path` TEXT to `users` table

### v6 (Identity Verification)
- Added `is_verified` INTEGER DEFAULT 0 to `users` table
- Added `verification_status` TEXT DEFAULT 'unverified' to `users` table

### v7 (Password Support)
- Added `password_hash` TEXT to `users` table

### v8 (Benefit Redemption)
- Added `status` TEXT DEFAULT 'earned' to `user_benefits` table
- Added `redeemed_at` INTEGER to `user_benefits` table

### v9 (Redemption Code)
- Added `redemption_code` TEXT to `user_benefits` table

### v10 (Password Hashing)
- Migrates existing plain text passwords to SHA-256 hashes
- Detects unhashed passwords (not 64 hex chars) and hashes them
- All new passwords are stored as hashes via PasswordUtils

### v11 (Continuous Tracking)
- Created `continuous_tracking_config` table (+ unique index on `user_id`)
- Created `continuous_tracking_state` table (+ unique index on `user_id`)
- Created `activity_segments` table (+ indexes on `session_id` and `(start_time, end_time)`)

## GPS Tracking Configuration

GPS tracking parameters are configurable in [lib/core/config/gps_tracking_config.dart](../lib/core/config/gps_tracking_config.dart).

**Key Parameters:**
- **Frequency:** Hybrid - 5 seconds OR 10 meters (whichever comes first)
- **Accuracy:** Minimum 50 meters accuracy required
- **Data Retention:** GPS points deleted after successful sync
- **Distance Calculation:** Haversine formula from GPS coordinates

## Future Schema (from database/schema_planned.puml)

The following tables are planned for future implementation:

### session_stream_data
**Purpose:** Real-time heart rate tracking during sessions

**Fields:**
- Heart rate measurements with timestamps
- HR zone classification
- Real-time performance metrics

### session_analysis
**Purpose:** Post-session terrain validation and fitness scores

**Fields:**
- Terrain type detection (flat, hilly, mountainous)
- Performance scores
- Training effect metrics

### user_biometrics_measured
**Purpose:** Automatically measured biometric data (VO2 max, heart rate zones)

**Fields:**
- VO2 max estimation
- Resting heart rate
- Recovery heart rate
- Performance metrics

**Note:** `user_biometrics_reported` (v3) handles self-reported data (height/weight). This table will handle measured/calculated data.

### continuous_tracking_data
**Purpose:** Background data points generated during continuous tracking

**Fields:**
- `user_id` (FK) - Owning user
- `timestamp` - Data point capture time
- `latitude` / `longitude` - Background GPS location
- `detected_activity` - Detected activity type
- `detection_confidence` - Detection confidence
- `step_count` - Background step count
- `background_heart_rate` - Background heart rate
- `privacy_level` - Privacy level for the data point
- `created_at` - Record creation timestamp

> **Status update:** Continuous tracking configuration and state were planned here but are now implemented in v11. See the **Continuous Tracking Tables (v11)** section above (`continuous_tracking_config`, `continuous_tracking_state`, `activity_segments`).

## Data Flow

### Manual Session Flow
1. User starts manual session → Session created with status "active"
2. GPS points recorded every 5 seconds OR 10 meters
3. GPS points stored in `gps_points` table with session_id
4. Distance calculated from GPS points using Haversine formula
5. User stops session → Session status updated to "completed"
6. Session and GPS points added to `sync_queue`
7. Background sync uploads data to server
8. After successful sync, GPS points deleted (session summary retained)

### Continuous Tracking Flow
1. Continuous session active in background
2. GPS points recorded at lower frequency (5 min OR 100 meters)
3. User starts manual session → Continuous session completed
4. Manual session runs normally
5. User stops manual session → Continuous session restarted

### Sync Flow
1. Completed sessions added to `sync_queue` with type "session"
2. GPS points included in session sync payload
3. Background sync service processes queue (FIFO)
4. On success: GPS points deleted, sync_queue entry removed
5. On failure: Retry count incremented, exponential backoff applied

## Query Patterns

### Get active session for user
```sql
SELECT * FROM sessions
WHERE user_id = ? AND status = 'active'
ORDER BY start_time DESC
LIMIT 1;
```

### Get GPS track for session
```sql
SELECT * FROM gps_points
WHERE session_id = ?
ORDER BY timestamp ASC;
```

### Get user's completed sessions
```sql
SELECT * FROM sessions
WHERE user_id = ? AND status = 'completed'
ORDER BY start_time DESC;
```

### Get sessions for a specific date
```sql
SELECT * FROM sessions
WHERE user_id = ? AND tracking_date = ?
ORDER BY start_time DESC;
```

### Get total distance for user
```sql
SELECT SUM(distance_meters) as total_distance
FROM sessions
WHERE user_id = ? AND status = 'completed';
```

## Database Maintenance

### Cleanup old GPS points
GPS points older than 30 days should be cleaned up if sync failed:

```sql
DELETE FROM gps_points
WHERE created_at < ?;
```

### Failed sync cleanup
Remove sync queue entries with excessive retry count:

```sql
DELETE FROM sync_queue
WHERE retry_count > 10;
```

## Related Files

- **Schema Diagrams:** [database/schema_actual.puml](schema_actual.puml) | [database/schema_planned.puml](schema_planned.puml)
- **Database Helper:** [lib/features/shared/database/database_helper.dart](../lib/features/shared/database/database_helper.dart)
- **GPS Configuration:** [lib/core/config/gps_tracking_config.dart](../lib/core/config/gps_tracking_config.dart)
- **Session Model:** [lib/features/session/domain/session.dart](../lib/features/session/domain/session.dart)
- **GPS Point Model:** [lib/features/session/domain/gps_point.dart](../lib/features/session/domain/gps_point.dart)
