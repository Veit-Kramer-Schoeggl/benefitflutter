---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [FEATURES.md](../../lib/features/FEATURES.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
>
> **Stand:** 2026-08-28 · **Verified against:** DB schema v12, branch `feat/phase-2-background-tracking` (WP1–WP5 done, WP6 device smoke open)
---

# Feature Modules Architecture Overview

## What Are Feature Modules?

The BeneFit app uses a **feature-based modular architecture** where each domain area (Auth, User, Session, Benefit, Security, Wearable Integration) is self-contained in its own module under `lib/features/`. This design enables clean separation of concerns and makes the codebase maintainable as it grows.

## Key Design Principles

### 1. Local-First Architecture
All data is saved to the local SQLite database first. The repository layer is structured so that, once a remote API is available, data can be synced to the server when online. This local-first design ensures the app works seamlessly without network connectivity.

> **Implementation status:** Remote synchronization is not yet active. The sync strategies and repository implementations currently run in "Stage 1: SQLite only" mode — `uploadToRemote`/`downloadFromRemote`/`queueForSync`/`processQueue` are stubs (PostgREST not yet configured), so no data leaves the device. The conflict-resolution rules below are written and unit-tested, but have **no production caller** — `resolveConflict` is invoked only from `test/unit/shared/sync/session_sync_strategy_test.dart`.
>
> **One exception to local-first:** `BenefitRepositoryImpl.getPartnersForBenefit` returns two hardcoded `BenefitPartner` records ("FitCafe" / Graz and "SportShop Pro" / Vienna — `benefit_repository_impl.dart:129-148`). **Seed data only:** there is no `benefit_partners` table among the 16 tables the schema creates; partner data will arrive with the backend.

### 2. Offline-Resilient
The app functions fully offline. Because all reads and writes go through the local SQLite database, no network is required for any feature. The architecture is prepared to queue pending operations for later synchronization once remote sync is enabled.

### 3. Feature-Isolated
Each feature module owns its own layers, but the shape varies by need — only three of the seven modules carry the full stack:

- `user`, `session` and `benefit` have domain models, DAO, repository interface + implementation **and** a sync strategy.
- `auth` and `security` have **neither DAO nor repository**. They expose service classes (`AuthService`, `TokenStorage`, `BiometricService`, `RateLimiterService`, `SessionTimeoutService`) over secure storage and `SharedPreferences`.
- `wearable_integration` has five DAOs plus a `WearableRepository` interface under `domain/repositories/`, implemented by three platform **sources** (`HealthConnectSource`, `HealthKitSource`, `BleDataSource`) rather than by a `*_repository_impl.dart`.

Modules are not fully independent of one another: `auth` depends on `user` (`AuthService` uses `UserRepository`), `session` and `wearable_integration` depend on each other (sensor summaries), and — a known violation to clean up — the cross-cutting `shared` module imports `session/domain/gps_point.dart` in `gps_sensor.dart` and `sensor_manager.dart`.

The modules are:
- **auth** — authentication & token storage (`AuthService`, `TokenStorage`)
- **user** — user profiles, biometrics & preferences
- **session** — activity tracking (manual + continuous), GPS, activity segments
- **benefit** — rewards & benefits catalog, earned/redeemed user benefits
- **security** — biometric app lock, rate limiting, session timeout
- **wearable_integration** — Health Connect / HealthKit & BLE sensor data
- **shared** — cross-cutting utilities (`database`, `sensors`, `sync`, `utils`; an empty `api/` placeholder directory awaits the future PostgREST client)

### 4. Custom Sync Strategies
The entities with bidirectional sync each define their own sync strategy and conflict-resolution rules, all extending `BaseSyncStrategy<T>` (`lib/features/shared/sync/base_sync_strategy.dart`). The default `resolveConflict` is "remote wins":
- **User data** (`UserSyncStrategy`): Server-authoritative (remote wins in conflicts).
- **Sessions** (`SessionSyncStrategy`): Status-aware. Active/paused sessions always keep the local copy (user is currently tracking); when both copies are completed the one with the later `endTime` wins; a completed remote beats a non-completed local; otherwise remote wins.
- **Benefits** (`BenefitSyncStrategy`): Server-authoritative (remote wins). `UserBenefit` rows are created once and then mutated at most once — on redemption, `BenefitDao.redeemUserBenefit` sets `status` → `'redeemed'` plus `redeemed_at` and `redemption_code` (`benefit_dao.dart:48-62`) — so conflicts are expected to be rare. Note that `BenefitRepositoryImpl.redeemBenefit` queues the operation string `'redeem'` (`benefit_repository_impl.dart:119`), which is **not** a member of the `SyncOperation` enum (`create` | `update` | `delete`); the enum has to be extended before the queue is wired up.

## Module Structure

Each feature lives in its own folder under `lib/features/` (78 `.dart` files, ~13 900 lines in total as of 2026-08-28):

```
lib/features/
├── auth/                  # Authentication & token storage
├── user/                  # User management feature
├── session/               # Activity tracking feature
├── benefit/               # Rewards & benefits feature
├── security/              # Biometric lock, rate limiting, session timeout
├── wearable_integration/  # Health platform & BLE sensor integration
└── shared/                # Shared utilities (database, sensors, sync, utils)
```

A module typically contains a `domain/` folder (models, enums) and a `data/` folder (DAO, repository interface, repository implementation, sync strategy). Modules vary: `security` exposes `services/` and `data/`, and `wearable_integration` adds `daos/`, `sensors/`, `services/`, and `sources/`. `auth` adds `utils/` and `widgets/`, and `session` adds `utils/`. Module sizes differ widely — from ~670 lines (`benefit`) to ~4 100 lines (`wearable_integration`).

## Data Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Screen    │────►│  Provider   │────►│ Repository  │
│    (UI)     │     │  (State)    │     │   (Data)    │
└─────────────┘     └─────────────┘     └─────────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    │                         │                         │
                    ▼                         ▼                         ▼
              ┌──────────┐            ┌────────────┐            ┌────────────┐
              │   DAO    │            │ Sync Queue │            │  API Call  │
              │ (SQLite) │            │  (Offline) │            │  (Online)  │
              └──────────┘            └────────────┘            └────────────┘
```

> **Known deviations from this chain:** GPS points and sensor readings have no repository yet, so three production call sites reach a DAO directly, skipping the Repository (and in two cases the Provider too): `ActivityProvider` holds `GpsPointDao` + `SessionBiometricDataDao` (`lib/providers/activity_provider.dart:107, 109`); `SessionDetailScreen` — a Screen — holds its own `GpsPointDao` and queries it in `_loadData` (`lib/presentation/screens/session/session_detail_screen.dart:49, 63`); `SessionSummaryScreen` instantiates `SessionSensorSummaryDao` (`lib/presentation/screens/activity/session_summary_screen.dart:25, 38`). Introducing a GPS/sensor repository is tracked cleanup.

> **Note:** Only the **DAO (SQLite)** path is operational today. The **Sync Queue (Offline)** and **API Call (Online)** branches are remote-sync stubs — scaffolded but not wired up (PostgREST not configured). Nothing inserts into or reads the `sync_queue` table, and no sync-coordinator class exists in the codebase.

## Offline Sync Strategy

The intended sync flow (designed and partially scaffolded; remote steps are stubbed until PostgREST is configured):

1. **Create/Update Operation**
   - Save to local SQLite immediately (active today)
   - Add operation to the sync queue *(planned — currently a no-op)*
   - Return success to UI (active today)

2. **Background Sync** *(planned — currently a no-op)*
   - Monitor connectivity status (`ConnectivityService` is wired into `UserRepositoryImpl`, `SessionRepositoryImpl` and `BenefitRepositoryImpl`; `ContinuousTrackingRepositoryImpl` is local-only — no connectivity check, no sync strategy)
   - When online, process the sync queue
   - Handle conflicts based on entity rules

3. **Conflict Resolution** *(implemented in the sync strategies, exercised once remote sync is enabled)*
   - `SessionSyncStrategy` compares session status and `endTime`
   - `UserSyncStrategy` / `BenefitSyncStrategy` default to remote-wins
   - Mark as synced or queue for retry *(planned — `maxRetries` / `retryDelaySeconds` are declared per strategy but read by no code yet, there is no retry loop, and the `sync_queue.retry_count` column is unused)*

## Benefits of This Architecture

| Benefit | Description |
|---------|-------------|
| **Testability** | Each module can be tested in isolation |
| **Scalability** | New features added without affecting existing code |
| **Maintainability** | Clear boundaries make code easier to understand |
| **Offline Support** | Users can work without network connectivity |
| **Performance** | Local-first means instant UI responses |

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Database Schema | [DATABASE.md](../../database/DATABASE.md) | [DATABASE_OVERVIEW](../data/DATABASE_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |
| Seeding System | [SEED.md](../../lib/core/seed/SEED.md) | [SEED_OVERVIEW](../data/SEED_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
