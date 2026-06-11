# BeneFit Flutter App

A Flutter-based benefit tracking application that rewards users for active transportation and movement.

## Project Overview

BeneFit tracks user movement data and rewards them with benefits (e.g., discounts, cashback) for choosing active transportation methods over cars. The app supports two tracking modes:

- **Continuous Tracking**: Long-running background tracking (days/weeks/months) at low resolution (~10 min intervals)
- **Active Sessions**: User-initiated workout sessions at high resolution (~seconds intervals)

## Quick Start

### Prerequisites
- Flutter SDK 3.38.4+ (Dart 3.10+) — required by current dependencies
- Git for version control
- IDE: VS Code or Android Studio

### Getting Started

```bash
# Clone repository
git clone [repository-url]

# Install dependencies
flutter pub get

# Run app (automatically seeds database in debug mode)
flutter run

# Run tests
flutter test
```

## App Structure

### 5 Main Tabs

Bottom navigation order (the app opens on the **Activity** tab by default):

1. **Community**: Social features (Coming Soon placeholder)
2. **Progress**: List of sessions and activity statistics
3. **Activity**: Start/stop tracking sessions (default tab)
4. **Benefit**: Total savings and earned benefits & rewards
5. **Profile**: User information and verification status

## Architecture Highlights

| Feature | Description |
|---------|-------------|
| **Offline-First** | All data stored locally in SQLite, syncs when online |
| **Feature Modules** | User, Session, Benefit each self-contained |
| **Provider Pattern** | State management with ChangeNotifier (`AuthProvider` for identity/session, `ProfileProvider` for editable profile data) |
| **Declarative Routing** | go_router (`MaterialApp.router`) with a redirect-based auth gate and `StatefulShellRoute` tabs (`lib/core/router/app_router.dart`) |
| **Wearable Integration** | Health Connect, HealthKit, and BLE devices |

## Documentation

**Full documentation index:** [documentation/README.md](documentation/README.md)

### Quick Reference

| Category | Technical Docs | Overviews |
|----------|---------------|-----------|
| **Architecture** | [FEATURES.md](lib/features/FEATURES.md) | [Overview](documentation/architecture/FEATURES_OVERVIEW.md) |
| **Database** | [DATABASE.md](database/DATABASE.md) | [Overview](documentation/data/DATABASE_OVERVIEW.md) |
| **Authentication** | [AUTH.md](AUTH.md) | [Overview](documentation/architecture/AUTH_OVERVIEW.md) |
| **Provider Pattern** | [PROVIDER_GUIDE.md](lib/presentation/PROVIDER_GUIDE.md) | [Overview](documentation/guides/PROVIDER_GUIDE_OVERVIEW.md) |
| **Wearables** | [WEARABLE_INTEGRATION.md](lib/features/wearable_integration/WEARABLE_INTEGRATION.md) | [Overview](documentation/wearables/WEARABLE_INTEGRATION_OVERVIEW.md) |
| **Sensors** | [SENSORS.md](lib/features/shared/sensors/SENSORS.md) | [Overview](documentation/guides/SENSORS_OVERVIEW.md) |

### Screen Documentation

| Screen | Technical | Overview |
|--------|-----------|----------|
| Activity | [ACTIVITY_SCREEN_PLAN.md](lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [Overview](documentation/screens/ACTIVITY_SCREEN_OVERVIEW.md) |
| Progress | [PROGRESS_SCREEN_PLAN.md](lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) | [Overview](documentation/screens/PROGRESS_SCREEN_OVERVIEW.md) |
| Profile | [PROFILE_SCREEN_PLAN.md](lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) | [Overview](documentation/screens/PROFILE_SCREEN_OVERVIEW.md) |

## Folder Structure

```
lib/
├── main.dart                    # App entry point (MaterialApp.router + provider setup)
├── core/                        # Core utilities (config, constants, enums, logging, network, router, seed, utils, deep_link)
├── features/                    # Feature-based modules (auth, benefit, security, session, shared, user, wearable_integration)
├── presentation/                # UI layer (navigation, screens, shared widgets)
└── providers/                   # State management (Provider / ChangeNotifier)

database/
└── DATABASE.md                  # Schema documentation

documentation/
├── README.md                    # Documentation index
├── architecture/                # Architecture overviews
├── data/                        # Database & seeding overviews
├── guides/                      # Developer guides
├── screens/                     # Screen overviews
├── sessions/                    # Session & tracking overviews
├── wearables/                   # Wearable integration
└── widgets/                     # Widget overviews
```

## Roadmap

### Phase 1: SQLite Foundation (Complete)
- Local-first data storage
- Feature module architecture
- Offline-capable app
- Database seeding for development
- Wearable device integration

### Phase 2: Backend Integration (Planned)
- PostgreSQL database setup
- PostgREST API layer
- Sync queue processing
- Real-time conflict resolution

### Phase 3: Advanced Features (Future)
- Background location tracking
- ML-based trip detection
- Advanced analytics
- Social features
