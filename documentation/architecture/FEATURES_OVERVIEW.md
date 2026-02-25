---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [FEATURES.md](../../lib/features/FEATURES.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Feature Modules Architecture Overview

## What Are Feature Modules?

The BeneFit app uses a **feature-based modular architecture** where each domain entity (User, Session, Benefit) is self-contained in its own module. This design enables clean separation of concerns and makes the codebase maintainable as it grows.

## Key Design Principles

### 1. Local-First Architecture
All data is saved to local SQLite database first, then synced to the server when online. This ensures the app works seamlessly without network connectivity.

### 2. Offline-Resilient
The app functions fully offline. When connectivity is restored, pending operations are automatically synchronized to the server.

### 3. Feature-Isolated
Each feature module (User, Session, Benefit) is self-contained with its own:
- Domain models
- Data access layer (DAO)
- Repository implementation
- Sync strategy

### 4. Custom Sync Strategies
Each entity has its own sync strategy and conflict resolution rules based on business requirements:
- **User data**: Server-authoritative (server wins in conflicts)
- **Sessions**: Client-authoritative (local changes preserved)
- **Benefits**: Server-authoritative (rewards verified server-side)

## Module Structure

Each feature follows a consistent folder structure:

```
lib/features/
├── user/           # User management feature
├── session/        # Activity tracking feature
├── benefit/        # Rewards & benefits feature
└── shared/         # Shared utilities
```

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

## Offline Sync Strategy

1. **Create/Update Operation**
   - Save to local SQLite immediately
   - Add operation to sync queue
   - Return success to UI

2. **Background Sync**
   - Monitor connectivity status
   - When online, process sync queue
   - Handle conflicts based on entity rules

3. **Conflict Resolution**
   - Compare timestamps
   - Apply entity-specific merge rules
   - Mark as synced or flag for review

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
