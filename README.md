# BeneFit Flutter App

> **Status:** 2026-08-28 · Branch `feat/phase-2-background-tracking` — Phase 2 background-tracking
> runtime: WP1–WP5 done, WP6 (on-device smoke) open. See [documentation/ROADMAP.md](documentation/ROADMAP.md).

A Flutter-based benefit tracking application that rewards users for active transportation and movement.

## Project Overview

BeneFit tracks user movement data and rewards them with benefits (e.g., discounts, cashback) for choosing active transportation methods over cars. The app is designed around two tracking modes:

- **Active Sessions** *(implemented)*: User-initiated workout sessions at high resolution (~5 s / 10 m storage thresholds, 5 m GPS stream filter). Recording keeps running while the app is backgrounded — Android foreground service / iOS background location updates.
- **Continuous Tracking** *(schema + config only — **not wired to the UI**)*: planned all-day background tracking at low resolution (~5 min / 100 m). `ContinuousTrackingRepository` exists but has no call sites, and the default config ships disabled. See [documentation/sessions/BACKGROUND_TRACKING_PLAN.md](documentation/sessions/BACKGROUND_TRACKING_PLAN.md) (Phase B).

## Quick Start

### Prerequisites
- Flutter SDK 3.44.1 (Dart 3.12+) — the version CI pins (`.github/workflows/ci.yml`); `pubspec.lock` resolves `flutter: ">=3.38.4"` / `dart: ">=3.12.0 <4.0.0"`
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

### Configuration

```bash
# Run against an explicit environment file
flutter run --dart-define-from-file=config/dev.json   # or config/staging.json, config/prod.example.json
```

`AppConfig` (`lib/core/config/app_config.dart`) reads `ENV`, `API_BASE_URL`, `CERT_PINNING`,
`SEED_ENABLED`, `HTTP_LOGGING`, `SENTRY_DSN` and `SENTRY_ENV`. Every value has a release-safe
`kDebugMode` fallback (pinning ON, seeding OFF, HTTP logging OFF in release builds), so a plain
`flutter run` works without the flag.

### Checks (the required CI gates)

```bash
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos lib
flutter test                       # 52 test files under test/
flutter build apk --debug
```

All four gates run on every push and pull request (`.github/workflows/ci.yml`). The end-to-end suite
(`integration_test/`, one happy-path test) runs on an Android emulator after merge to `main` via
`.github/workflows/e2e.yml` — deliberately not on PRs.

> **Current state (2026-08-28):** 823 tests pass, `dart analyze --fatal-infos lib` is clean and the
> debug APK builds — but the **format gate is red**: three files from the WP3/WP5 commits are
> unformatted (`lib/presentation/screens/activity/activity_screen.dart`,
> `lib/providers/activity_provider.dart`, `test/unit/providers/activity_provider_test.dart`).
> Run `dart format .` before the next push.

## App Structure

### 5 Main Tabs

Bottom navigation order (the app opens on the **Activity** tab by default):

1. **Community**: Static mock UI — challenges, events and community chips with hard-coded content; no backend (the banner headline reads "Coming Soon")
2. **Progress**: List of sessions and activity statistics
3. **Activity**: Start/stop tracking sessions (default tab)
4. **Benefit**: Total savings and earned benefits & rewards
5. **Profile**: User information and verification status

## Architecture Highlights

| Feature | Description |
|---------|-------------|
| **Offline-First** | All data stored locally in SQLite. **Sync is not implemented**: every sync strategy is a stub (`uploadToRemote` returns `true` without a network call, `downloadFromRemote` throws `UnimplementedError('PostgREST not yet configured')`, the `sync_queue` table is created but never written) — pending the backend decision, see [ROADMAP.md](documentation/ROADMAP.md) Phase 2 |
| **Feature Modules** | Seven self-contained modules under `lib/features/` (auth, benefit, security, session, shared, user, wearable_integration) |
| **Provider Pattern** | State management with ChangeNotifier (`AuthProvider` for identity/session, `ProfileProvider` for editable profile data) |
| **Declarative Routing** | go_router (`MaterialApp.router`) with a redirect-based auth gate and `StatefulShellRoute` tabs (`lib/core/router/app_router.dart`) |
| **Wearable Integration** | Health Connect, HealthKit, and BLE devices |
| **Background Tracking** | Active sessions keep recording when backgrounded — geolocator foreground service on Android, `UIBackgroundModes: location` on iOS (`lib/features/shared/sensors/gps_sensor.dart`) |
| **Crash Reporting** | Sentry, opt-in via `--dart-define=SENTRY_DSN=…`; with no DSN nothing is initialised and nothing is sent (no network — GDPR-safe for local/dev/CI builds), `lib/main.dart` |

## Documentation

**Full documentation index:** [documentation/README.md](documentation/README.md)

| Project status | Description |
|----------------|-------------|
| [Backlog.md](Backlog.md) | Every open item (100 entries, BL-001…BL-100), prioritised P0–P3 with effort and acceptance criteria |
| [Changelog.md](Changelog.md) | Release history reconstructed from git, newest first; 1.0.0 is the state the pma award submission was based on |

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
├── core/                        # Core utilities (config, deep_link, enums, logging, network, router, seed, utils)
├── features/                    # Feature-based modules (auth, benefit, security, session, shared, user, wearable_integration)
├── presentation/                # UI layer (navigation, screens, shared widgets)
└── providers/                   # State management (Provider / ChangeNotifier)

database/
├── DATABASE.md                  # Schema documentation
├── schema_actual.puml / .png    # Current schema (PlantUML source + render)
└── schema_planned.puml / .png   # Target schema (PlantUML source + render)

documentation/
├── README.md                    # Documentation index
├── architecture/                # Architecture overviews
├── data/                        # Database & seeding overviews
├── guides/                      # Developer guides
├── screens/                     # Screen overviews
├── sessions/                    # Session & tracking design/plan
├── wearables/                   # Wearable integration
├── widgets/                     # Widget overviews
├── ARCHITECTURE_REVIEW.md       # Design evaluation for large-scale rollout
├── ROADMAP.md                   # Phase 0–3 action checklist
├── DEVICE_SMOKE_CHECKLIST.md    # Manual on-device smoke tests
└── FUTURE.md                    # Proposed target directory layout
```

## Roadmap

The authoritative, dated checklist is [documentation/ROADMAP.md](documentation/ROADMAP.md) (German);
the phases below mirror its numbering.

### Phase 0: Blockers & Foundation (Complete)
- Release signing config; debug-gated test login
- PII/secret-free logging (`AppLogger` with redaction)
- Pinned dependencies, curated analyzer lints
- Global error handler + DSN-gated Sentry crash reporting
- CI required on every push/PR (format, analyze, test, debug APK)

### Phase 1: Correctness, Data Integrity & Decoupling (In progress)
- Local-first SQLite storage with a feature-module architecture
- Schema single-source-of-truth, transactions and migration tests
- Database seeding for development
- Wearable device integration
- `UserProvider` split into `AuthProvider` + `ProfileProvider`; typed `AppConfig`
- Navigator 1.0 → go_router with a redirect-based auth gate
- **Open:** widget/integration test layer for the critical flows

### Phase 2: Real Backend, Sync & Auth (In progress)
- Background tracking runtime for active sessions (Android foreground service / iOS `UIBackgroundModes`) — **WP1–WP5 done, WP6 (on-device smoke) open**
- Backend decision spike: PowerSync/Supabase vs. PostgREST — decision record pending (no backend is committed to yet)
- Working sync: `SyncManager` + `SyncQueueDao` (drain / backoff / dead-letter) — today the sync strategies are stubs
- Versioned, idempotent conflict resolution; benefits as an append-only ledger
- Real auth: `RealAuthService` / `ApiClient` / `AuthInterceptor` + SPKI pinning
- Sync observability + remote kill switch before go-live

### Phase 3: Modernisation, Scale & Rollout Readiness (Planned)
- i18n scaffolding (`flutter_localizations` + `l10n.yaml`)
- Build flavors (dev/staging/prod) + CD
- Theming single-source (tokens, dark mode) + accessibility baseline
- GPS retention (`deleteOlderThan` + VACUUM) + polyline simplification
- Feature consolidation (`presentation/` + `providers/` → `features/<x>/`)
- Switch Sentry on with an EU DSN (plumbing already in place)

### Ideas, not scheduled
`continuousDaily` all-day tracking (Phase B of the background-tracking plan), ML-based trip
detection, advanced analytics and a real social/community backend (the Community tab is a static
mock today). None of these has a dated slot in [documentation/ROADMAP.md](documentation/ROADMAP.md) yet.
