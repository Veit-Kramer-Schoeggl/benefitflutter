---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [SEED.md](../../lib/core/seed/SEED.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](./DATABASE_OVERVIEW.md) | [FEATURES Overview](../architecture/FEATURES_OVERVIEW.md)
>
> **Last verified:** 2026-08-28 against `lib/core/seed/` on branch `feat/phase-2-background-tracking`
---

# Database Seeding Overview

## Purpose

The seeding system automatically populates the database with test data during development. This enables rapid development and testing without manually creating data each time the app starts.

## How It Works

```
App Start (seed gate on)
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
 Create preferences + biometrics
       │
       ▼
 Create test benefits
       │
       ▼
 Create test sessions
       │
       ▼
 (+ GPS, wearables, sensor data, summaries, health data)
       │
       ▼
 Award user benefits
       │
       ▼
 Mark as seeded
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Debug-Only by default** | Seeding runs when the `SEED_ENABLED` dart-define is true; with no flag it defaults to debug builds only |
| **One-Time** | Data created once, persists across restarts |
| **Configurable** | Enable/disable via feature flags |
| **Realistic Data** | Test data reflects production scenarios |

## Test Data Created

### Test Users
Pre-configured user accounts for testing:
- Two accounts: `test@gmail.com` (Test Developer, Vienna) and `test2@gmail.com` (Sarah Runner, Berlin)
- Both use the password `1234` (stored as a SHA-256 hash)
- Each has profile preferences, a biometrics history and its own wearable devices

Full field-by-field data is in [SEED.md](../../lib/core/seed/SEED.md).

### Test Sessions
Sample workout sessions:
- Mix of walking, running, cycling, and yoga
- Various durations and distances (including one active session)
- Different time periods

### Test Benefits
Sample rewards and achievements:
- Distance-based rewards
- Session count rewards
- Various discount amounts

## Configuration

Seeding behavior is controlled through configuration:
- **Enabled/Disabled:** Build-time `SEED_ENABLED` dart-define (`flutter run --dart-define-from-file=config/dev.json`); defaults to debug-only when the flag is absent
- **Per-Entity Flags:** 12 compile-time flags in `SeedConfig` (users, preferences, biometrics, benefits, sessions, GPS points, wearable devices, biometric sensor data, motion sensor data, sensor summaries, health platform data, user benefits) - all enabled today
- **Version Key:** `database_seeded_v4` in SharedPreferences; bump it to force a team-wide reseed
- **Reset Option:** `forceReseed` flag, or the debug reseed buttons that clear all tables and reseed

## Resetting Data

In debug builds two buttons trigger a full clear-and-reseed: the orange **Reset Seed Data** button in the Benefits screen's *Developer Tools* section, and the **Reset Test Data** button on the Login screen (which also signs you out). Both wipe every table, clear the seed flag, and reseed - hand-created data is destroyed too. See [SEED.md](../../lib/core/seed/SEED.md) for the full procedure and safety notes.

## When Seeding Runs

- **First Launch:** Seeds when the seed flag has not yet been set
- **Debug Mode by Default:** Controlled by the `SEED_ENABLED` dart-define (`config/dev.json` = true, `config/staging.json` and `config/prod.json` = false); with no flag it follows `kDebugMode`, so release builds do not seed
- **Configurable:** Can be disabled for specific testing

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Database Schema | [DATABASE.md](../../database/DATABASE.md) | [DATABASE_OVERVIEW](./DATABASE_OVERVIEW.md) |
| Feature Modules | [FEATURES.md](../../lib/features/FEATURES.md) | [FEATURES_OVERVIEW](../architecture/FEATURES_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
