---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [FEATURES.md](../../lib/features/FEATURES.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Feature Modules Architecture Overview

## What Are Feature Modules?

The BeneFit app uses a **feature-based modular architecture** where each domain area (Auth, User, Session, Benefit, Security, Wearable Integration) is self-contained in its own module under `lib/features/`. This design enables clean separation of concerns and makes the codebase maintainable as it grows.

## Key Design Principles

### 1. Local-First Architecture
All data is saved to the local SQLite database first. The repository layer is structured so that, once a remote API is available, data can be synced to the server when online. This local-first design ensures the app works seamlessly without network connectivity.

> **Implementation status:** Remote synchronization is not yet active. The sync strategies and repository implementations currently run in "Phase 1: SQLite only" mode — `uploadToRemote`/`downloadFromRemote`/`queueForSync`/`processQueue` are stubs (PostgREST not yet configured), so no data leaves the device. The conflict-resolution rules below are implemented and ready, but only exercised once remote sync is wired up.

### 2. Offline-Resilient
The app functions fully offline. Because all reads and writes go through the local SQLite database, no network is required for any feature. The architecture is prepared to queue pending operations for later synchronization once remote sync is enabled.

### 3. Feature-Isolated
Each feature module is self-contained with its own domain models, data access layer (DAO), repository (interface + implementation), and — where applicable — a sync strategy. The modules are:
- **auth** — authentication & token storage (`AuthService`, `TokenStorage`)
- **user** — user profiles, biometrics & preferences
- **session** — activity tracking (manual + continuous), GPS, activity segments
- **benefit** — rewards & benefits catalog, earned/redeemed user benefits
- **security** — biometric app lock, rate limiting, session timeout
- **wearable_integration** — Health Connect / HealthKit & BLE sensor data
- **shared** — cross-cutting utilities (`api`, `database`, `sensors`, `sync`, `utils`)

### 4. Custom Sync Strategies
The entities with bidirectional sync each define their own sync strategy and conflict-resolution rules, all extending `BaseSyncStrategy<T>` (`lib/features/shared/sync/base_sync_strategy.dart`). The default `resolveConflict` is "remote wins":
- **User data** (`UserSyncStrategy`): Server-authoritative (remote wins in conflicts).
- **Sessions** (`SessionSyncStrategy`): Status-aware. Active/paused sessions always keep the local copy (user is currently tracking); when both copies are completed the one with the later `endTime` wins; a completed remote beats a non-completed local; otherwise remote wins.
- **Benefits** (`BenefitSyncStrategy`): Server-authoritative (remote wins). `UserBenefit` records are treated as effectively immutable once created, so conflicts are expected to be rare.

## Module Structure

Each feature follows a consistent folder structure:

```
lib/features/
├── auth/                  # Authentication & token storage
├── user/                  # User management feature
├── session/               # Activity tracking feature
├── benefit/               # Rewards & benefits feature
├── security/              # Biometric lock, rate limiting, session timeout
├── wearable_integration/  # Health platform & BLE sensor integration
└── shared/                # Shared utilities (api, database, sensors, sync, utils)
```

A module typically contains a `domain/` folder (models, enums) and a `data/` folder (DAO, repository interface, repository implementation, sync strategy). Modules vary: `security` exposes `services/` and `data/`, and `wearable_integration` adds `daos/`, `sensors/`, `services/`, and `sources/`.

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

> **Note:** Only the **DAO (SQLite)** path is operational today. The **Sync Queue (Offline)** and **API Call (Online)** branches are Phase-2 stubs — they are scaffolded but not yet wired up (PostgREST not configured).

## Offline Sync Strategy

The intended sync flow (designed and partially scaffolded; remote steps are stubbed until PostgREST is configured):

1. **Create/Update Operation**
   - Save to local SQLite immediately (active today)
   - Add operation to the sync queue *(planned — currently a no-op)*
   - Return success to UI (active today)

2. **Background Sync** *(planned — currently a no-op)*
   - Monitor connectivity status (`ConnectivityService` is wired into the repository implementations)
   - When online, process the sync queue
   - Handle conflicts based on entity rules

3. **Conflict Resolution** *(implemented in the sync strategies, exercised once remote sync is enabled)*
   - `SessionSyncStrategy` compares session status and `endTime`
   - `UserSyncStrategy` / `BenefitSyncStrategy` default to remote-wins
   - Mark as synced or queue for retry (`maxRetries` / `retryDelaySeconds` per strategy)

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
