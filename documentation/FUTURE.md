# FUTURE.md — Roadmap: Target (Clean-Architecture) Directory Structure

> **Last updated:** 2026-08-28 (verified against `lib/` on branch `feat/phase-2-background-tracking`).
>
> **Status: aspirational — NOT built.** Nothing in the tree below exists as shown; it is a target
> layout, not a description of the code. The "Actual current top-level structure" note further down
> is the authoritative description of what is really on disk today (141 Dart files, ~30,700 lines).
>
> NOTE: For the prioritized engineering evolution plan (launch blockers, data integrity,
> backend/sync, scale & rollout readiness) see [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md)
> and the checklist in [ROADMAP.md](ROADMAP.md). This file only covers the proposed target
> directory layout.
>
> STATUS: This is a forward-looking PROPOSED layout, NOT the current code.
> The codebase today uses a feature-based architecture, not the layered
> `data/` / `domain/` / `usecases/` / `services/` split shown below.
>
> Actual current top-level structure under `lib/` is:
> `main.dart`, `core/` (config, constants, deep_link, enums, logging, network,
> router, seed, utils), `features/` (auth, benefit, security, session, shared,
> user, wearable_integration), `presentation/` (navigation, screens, shared),
> and `providers/`. There is no `lib/app.dart`, `lib/data/`, `lib/domain/`, or
> `lib/services/`; the root widget lives in `main.dart`. Routing now uses
> **go_router** (`MaterialApp.router`) with a single `GoRouter` defined in
> `lib/core/router/app_router.dart` (redirect-based auth-gate, `StatefulShellRoute`
> for the 5 tabs) — the older Navigator 1.0 named-route map in `main.dart` is gone,
> and there is no `core/config/routes.dart`.
>
> The tree below is the aspirational target and is intentionally left as-is.

```
lib/
├── main.dart                          # App entry point with Provider setup
├── app.dart                           # Root app widget with theme & navigation
│
├── core/                              # Core functionality (app-wide)
│   ├── constants/
│   │   ├── api_constants.dart         # API URLs, endpoints
│   │   ├── app_constants.dart         # App-wide constants
│   │   └── storage_keys.dart          # Local storage keys
│   ├── config/
│   │   ├── routes.dart                # Named routes
│   │   └── theme.dart                 # App theme configuration
│   ├── utils/
│   │   ├── date_utils.dart            # Date formatting helpers
│   │   ├── location_utils.dart        # Location calculations
│   │   └── validators.dart            # Input validation
│   └── errors/
│       ├── exceptions.dart            # Custom exceptions
│       └── failures.dart              # Failure types
│
├── data/                              # Data layer
│   ├── models/                        # Data models
│   │   ├── user.dart
│   │   ├── tracking_session.dart
│   │   ├── movement_data.dart
│   │   ├── benefit.dart
│   │   └── daily_stats.dart
│   ├── repositories/                  # Data access
│   │   ├── tracking_repository.dart
│   │   ├── user_repository.dart
│   │   ├── benefit_repository.dart
│   │   └── stats_repository.dart
│   ├── datasources/                   # Data sources
│   │   ├── local/
│   │   │   ├── local_database.dart    # SQLite database
│   │   │   ├── shared_prefs.dart      # SharedPreferences wrapper
│   │   │   └── dao/                   # Data Access Objects
│   │   │       ├── session_dao.dart
│   │   │       └── movement_dao.dart
│   │   └── remote/
│   │       ├── api_client.dart        # PostgREST client
│   │       └── endpoints/
│   │           ├── tracking_api.dart
│   │           ├── user_api.dart
│   │           └── benefit_api.dart
│   └── sync/
│       ├── sync_service.dart          # Data synchronization
│       └── sync_scheduler.dart        # Sync triggers
│
├── domain/                            # Business logic layer
│   ├── entities/                      # Business entities (pure Dart)
│   │   ├── session.dart
│   │   ├── location_point.dart
│   │   └── benefit.dart
│   ├── usecases/                      # Use cases (single responsibility)
│   │   ├── tracking/
│   │   │   ├── start_continuous_tracking.dart
│   │   │   ├── stop_continuous_tracking.dart
│   │   │   ├── start_active_session.dart
│   │   │   └── stop_active_session.dart
│   │   ├── benefits/
│   │   │   ├── get_user_benefits.dart
│   │   │   └── calculate_benefits.dart
│   │   └── stats/
│   │       ├── get_daily_stats.dart
│   │       └── calculate_savings.dart
│   └── repositories/                  # Repository interfaces
│       └── tracking_repository_interface.dart
│
├── providers/                         # State management (Provider pattern)
│   ├── benefit_provider.dart         # Benefit screen state
│   ├── progress_provider.dart        # Progress screen state
│   ├── profile_provider.dart         # Profile screen state
│   └── activity_provider.dart        # Activity screen state
│
├── presentation/                      # UI layer
│   ├── PROVIDER_GUIDE.md              # Team guide for Provider pattern
│   ├── screens/                       # Main screens (one per tab)
│   │   ├── home/                      # Tab 1: Start/Stop tracking
│   │   │   ├── home_screen.dart
│   │   │   └── widgets/
│   │   │       ├── tracking_button.dart
│   │   │       ├── status_card.dart
│   │   │       └── live_stats_widget.dart
│   │   │
│   │   ├── progress/                  # Tab 2: Sessions & benefits list
│   │   │   ├── progress_screen.dart
│   │   │   └── widgets/
│   │   │       ├── session_list_item.dart
│   │   │       ├── benefit_list_item.dart
│   │   │       ├── session_details_sheet.dart
│   │   │       └── filter_chip_bar.dart
│   │   │
│   │   ├── statistics/                # Tab 3: Stats & analytics
│   │   │   ├── statistics_screen.dart
│   │   │   └── widgets/
│   │   │       ├── savings_card.dart
│   │   │       ├── distance_chart.dart
│   │   │       ├── time_period_selector.dart
│   │   │       └── stats_summary.dart
│   │   │
│   │   ├── profile/                   # Tab 4: User profile
│   │   │   ├── profile_screen.dart
│   │   │   └── widgets/
│   │   │       ├── profile_header.dart
│   │   │       ├── verification_status.dart
│   │   │       ├── settings_section.dart
│   │   │       └── info_row.dart
│   │   │
│   │   └── community/                 # Tab 5: Social (placeholder)
│   │       ├── community_screen.dart
│   │       └── widgets/
│   │           └── coming_soon_placeholder.dart
│   │
│   ├── shared/                        # Shared widgets across screens
│   │   ├── widgets/
│   │   │   ├── custom_app_bar.dart
│   │   │   ├── loading_indicator.dart
│   │   │   ├── error_widget.dart
│   │   │   ├── empty_state.dart
│   │   │   └── bottom_nav_bar.dart
│   │   └── dialogs/
│   │       ├── confirmation_dialog.dart
│   │       └── info_dialog.dart
│   │
│   └── navigation/
│       └── main_navigation.dart       # Bottom nav controller
│
└── services/                          # Platform services
    ├── location/
    │   ├── location_service.dart      # GPS tracking
    │   └── background_location.dart   # Background tracking
    ├── notification/
    │   └── notification_service.dart  # Local notifications
    ├── permission/
    │   └── permission_service.dart    # Handle permissions
    └── storage/
        └── local_storage_service.dart # Local data management
```


