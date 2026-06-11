# BeneFit Documentation Index

Complete documentation for the BeneFit Flutter application.

## Documentation Format

Each topic has two documentation types:
- **TECHNICAL**: Implementation details, code examples, API references (located near code)
- **OVERVIEW**: High-level concepts, architecture summaries (located in this folder)

---

## Core Architecture

| Topic | Technical | Overview | Description |
|-------|-----------|----------|-------------|
| Feature Modules | [FEATURES.md](../lib/features/FEATURES.md) | [FEATURES_OVERVIEW.md](architecture/FEATURES_OVERVIEW.md) | Module architecture, sync strategies |
| Authentication | [AUTH.md](../AUTH.md) | [AUTH_OVERVIEW.md](architecture/AUTH_OVERVIEW.md) | Auth system, JWT, session management |
| Main Routing | [MAIN_AUTH.md](../lib/MAIN_AUTH.md) | [MAIN_AUTH_OVERVIEW.md](architecture/MAIN_AUTH_OVERVIEW.md) | App entry, go_router routing & redirect auth-gate, navigation |
| Security | [SECURITY.md](../lib/features/security/SECURITY.md) | _N/A_ | Rate limiting, app lock, hardening |

## Data Layer

| Topic | Technical | Overview | Description |
|-------|-----------|----------|-------------|
| Database Schema | [DATABASE.md](../database/DATABASE.md) | [DATABASE_OVERVIEW.md](data/DATABASE_OVERVIEW.md) | SQLite tables, migrations |
| Seeding System | [SEED.md](../lib/core/seed/SEED.md) | [SEED_OVERVIEW.md](data/SEED_OVERVIEW.md) | Test data population |

## Screen Implementation

| Topic | Technical | Overview | Description |
|-------|-----------|----------|-------------|
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW.md](screens/ACTIVITY_SCREEN_OVERVIEW.md) | Timer, GPS tracking |
| Profile Screen | [PROFILE_SCREEN_PLAN.md](../lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) | [PROFILE_SCREEN_OVERVIEW.md](screens/PROFILE_SCREEN_OVERVIEW.md) | User profile, edit mode |
| Progress Screen | [PROGRESS_SCREEN_PLAN.md](../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) | [PROGRESS_SCREEN_OVERVIEW.md](screens/PROGRESS_SCREEN_OVERVIEW.md) | Session history |

## Sessions & Tracking

| Topic | Design | Plan | Description |
|-------|--------|------|-------------|
| Session System | [SESSION_DESIGN.md](sessions/SESSION_DESIGN.md) | [SESSION_PLAN.md](sessions/SESSION_PLAN.md) | Tracking modes, sprint breakdown |

## Integration

| Topic | Technical | Overview | Description |
|-------|-----------|----------|-------------|
| Wearables | [WEARABLE_INTEGRATION.md](../lib/features/wearable_integration/WEARABLE_INTEGRATION.md) | [WEARABLE_INTEGRATION_OVERVIEW.md](wearables/WEARABLE_INTEGRATION_OVERVIEW.md) | Health Connect, BLE |
| Sensors | [SENSORS.md](../lib/features/shared/sensors/SENSORS.md) | [SENSORS_OVERVIEW.md](guides/SENSORS_OVERVIEW.md) | GPS, accelerometer |

## Development Guides

| Topic | Technical | Overview | Description |
|-------|-----------|----------|-------------|
| Provider Pattern | [PROVIDER_GUIDE.md](../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW.md](guides/PROVIDER_GUIDE_OVERVIEW.md) | State management |
| Auth Widgets | [WIDGETS.md](../lib/features/auth/widgets/WIDGETS.md) | [AUTH_WIDGETS_OVERVIEW.md](widgets/AUTH_WIDGETS_OVERVIEW.md) | Password fields, validation |
| Auth Provider | [AUTH_PROVIDER_PLAN.md](../lib/providers/AUTH_PROVIDER_PLAN.md) | [AUTH_OVERVIEW.md](architecture/AUTH_OVERVIEW.md) | AuthProvider implementation (identity/session); profile editing in ProfileProvider |

## Additional Documents

| Document | Type | Description |
|----------|------|-------------|
| [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md) | Review | Honest design evaluation for large-scale rollout + phased evolution plan |
| [ROADMAP.md](ROADMAP.md) | Plan | Actionable checklist derived from the architecture review |
| [FUTURE.md](FUTURE.md) | Overview | Future architecture plans (proposed target directory layout) |
| [DEVICE_SMOKE_CHECKLIST.md](DEVICE_SMOKE_CHECKLIST.md) | Checklist | Manual on-device smoke tests (rounds 2a/2b/3), done + pending |

---

## Quick Navigation

### New to the Project?
Start with the **OVERVIEW** documents for high-level understanding:
1. [FEATURES_OVERVIEW](architecture/FEATURES_OVERVIEW.md) - App architecture
2. [DATABASE_OVERVIEW](data/DATABASE_OVERVIEW.md) - Data storage
3. [PROVIDER_GUIDE_OVERVIEW](guides/PROVIDER_GUIDE_OVERVIEW.md) - State management

### Implementing a Feature?
Use the **TECHNICAL** documents for code examples:
1. [PROVIDER_GUIDE.md](../lib/presentation/PROVIDER_GUIDE.md) - Provider pattern
2. [FEATURES.md](../lib/features/FEATURES.md) - Module structure
3. Screen-specific plans in `lib/presentation/screens/*/`

### Need Database Info?
- Schema: [DATABASE.md](../database/DATABASE.md)
- Seeding: [SEED.md](../lib/core/seed/SEED.md)

---

## Folder Structure

```
documentation/
├── README.md                    # This index
├── architecture/                # Architecture overviews
│   ├── FEATURES_OVERVIEW.md
│   ├── AUTH_OVERVIEW.md
│   └── MAIN_AUTH_OVERVIEW.md
├── data/                        # Data layer overviews
│   ├── DATABASE_OVERVIEW.md
│   └── SEED_OVERVIEW.md
├── guides/                      # Developer guides
│   ├── PROVIDER_GUIDE_OVERVIEW.md
│   └── SENSORS_OVERVIEW.md
├── screens/                     # Screen overviews
│   ├── ACTIVITY_SCREEN_OVERVIEW.md
│   ├── PROFILE_SCREEN_OVERVIEW.md
│   └── PROGRESS_SCREEN_OVERVIEW.md
├── sessions/                    # Session & tracking design/plan
│   ├── SESSION_DESIGN.md
│   └── SESSION_PLAN.md
├── wearables/                   # Wearable integration
│   └── WEARABLE_INTEGRATION_OVERVIEW.md
├── widgets/                     # Widget overviews
│   └── AUTH_WIDGETS_OVERVIEW.md
└── FUTURE.md                    # Roadmap
```

---

[Back to Project README](../README.md)
