---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [DATABASE.md](../../database/DATABASE.md) - Implementation details with code examples
>
> **Related:** [FEATURES Overview](../architecture/FEATURES_OVERVIEW.md) | [SEED Overview](./SEED_OVERVIEW.md)
---

# Database Schema Overview

## Purpose

The BeneFit app uses SQLite for local data storage with an offline-first architecture. All user data, sessions, and benefits are stored locally and synced to the server when connectivity is available.

## Database Information

- **Database Type:** SQLite
- **File Name:** benefit_app.db
- **Current Version:** 11
- **Pattern:** Offline-first with sync queue
- **Location:** Platform databases directory (`getDatabasesPath()`)

## Core Tables

### Users
Stores user account information and profile data:
- User identification and authentication
- Profile information (name, email, gender, date of birth)
- Email verification status
- Profile image path

### Sessions
Tracks activity sessions (workouts):
- Session metadata (start time, end time, duration)
- Activity type (walking, running, cycling)
- Tracking mode (manual or continuous)
- Distance and performance metrics

### GPS Points
Detailed GPS tracking data for sessions:
- Latitude and longitude coordinates
- Altitude and accuracy measurements
- Speed data at each point
- Timestamps for route reconstruction

### Benefits
Available rewards in the system:
- Benefit titles and descriptions
- Discount amounts
- Requirements to unlock (distance or sessions)

### User Benefits
Records of benefits earned by users:
- Links user to earned benefit
- Session that triggered the reward
- Timestamp of earning

### Sync Queue
Manages offline operations:
- Pending create/update/delete operations
- Retry count and error tracking
- Ensures data consistency across devices

## Additional Tables

Beyond the core tables, the schema includes feature-specific table groups:

- **Profile (v3):** `user_biometrics_reported`, `user_preferences`
- **Wearable integration (v4):** `wearable_devices`, `session_biometric_data`, `session_motion_data`, `session_sensor_summary`, `health_platform_data`
- **Continuous tracking (v11):** `continuous_tracking_config`, `continuous_tracking_state`, `activity_segments`

## Data Relationships

```
┌─────────┐       ┌──────────────┐       ┌───────────┐
│  Users  │◄──────│   Sessions   │───────►│GPS Points │
└─────────┘       └──────────────┘       └───────────┘
     │                   │
     │                   │
     ▼                   ▼
┌─────────────┐   ┌─────────────┐
│User Benefits│───│  Benefits   │
└─────────────┘   └─────────────┘
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Offline-First** | All data saved locally before sync |
| **Cascade Deletes** | Related records deleted automatically |
| **Indexed Queries** | Performance-optimized for common queries |
| **Migration Support** | Schema versioning for updates |
| **Data Retention** | GPS points cleaned after successful sync |

## Schema Versioning

The database uses incremental migrations to evolve the schema:
- **v1-v2:** Core tables (users, sessions, GPS points)
- **v3:** Profile enhancements (reported biometrics, user preferences, demographics)
- **v4:** Wearable integration (devices, biometric/motion/sensor data, health platform)
- **v5:** Profile image support
- **v6-v7:** Authentication (verification status, password hashing)
- **v8-v9:** Benefit redemption (status, redeemed timestamp, redemption codes)
- **v10:** Password security (rehash plaintext passwords to SHA-256)
- **v11:** Continuous tracking (config, state, activity segments)

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Feature Modules | [FEATURES.md](../../lib/features/FEATURES.md) | [FEATURES_OVERVIEW](../architecture/FEATURES_OVERVIEW.md) |
| Seeding System | [SEED.md](../../lib/core/seed/SEED.md) | [SEED_OVERVIEW](./SEED_OVERVIEW.md) |
| Authentication | [AUTH.md](../../AUTH.md) | [AUTH_OVERVIEW](../architecture/AUTH_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
