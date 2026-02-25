---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [SEED.md](../../lib/core/seed/SEED.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](./DATABASE_OVERVIEW.md) | [FEATURES Overview](../architecture/FEATURES_OVERVIEW.md)
---

# Database Seeding Overview

## Purpose

The seeding system automatically populates the database with test data during development. This enables rapid development and testing without manually creating data each time the app starts.

## How It Works

```
App Start (Debug Mode)
       │
       ▼
 Check if seeded ───► Already seeded? ───► Skip
       │
       No
       │
       ▼
 Create test users
       │
       ▼
 Create test sessions
       │
       ▼
 Create test benefits
       │
       ▼
 Mark as seeded
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Debug-Only** | Seeding only runs in development mode |
| **One-Time** | Data created once, persists across restarts |
| **Configurable** | Enable/disable via feature flags |
| **Realistic Data** | Test data reflects production scenarios |

## Test Data Created

### Test Users
Pre-configured user accounts for testing:
- Various profile configurations
- Different activity levels
- Test credentials for login

### Test Sessions
Sample workout sessions:
- Mix of walking, running, cycling
- Various durations and distances
- Different time periods

### Test Benefits
Sample rewards and achievements:
- Distance-based rewards
- Session count rewards
- Various discount amounts

## Configuration

Seeding behavior is controlled through configuration:
- **Enabled/Disabled:** Toggle seeding on/off
- **Data Volume:** Control amount of test data
- **Reset Option:** Clear and reseed database

## When Seeding Runs

- **First Launch:** Seeds if database is empty
- **Debug Mode Only:** Never seeds in production
- **Configurable:** Can be disabled for specific testing

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Database Schema | [DATABASE.md](../../database/DATABASE.md) | [DATABASE_OVERVIEW](./DATABASE_OVERVIEW.md) |
| Feature Modules | [FEATURES.md](../../lib/features/FEATURES.md) | [FEATURES_OVERVIEW](../architecture/FEATURES_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
