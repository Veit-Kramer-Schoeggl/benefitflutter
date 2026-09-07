---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) - Implementation details with code examples
>
> **Related:** [FEATURES Overview](../architecture/FEATURES_OVERVIEW.md) | [Screen Overviews](../screens/)
>
> **Stand:** 2026-08-28 — 8 providers in `lib/providers/`, wired in `lib/main.dart:151-199`,
> branch `feat/phase-2-background-tracking`.
---

# Provider Pattern Overview

## What is the Provider Pattern?

Provider is a state management pattern for Flutter based on the ChangeNotifier pattern (similar to the Observer pattern). It enables automatic UI updates when data changes, making it easier to build reactive applications.

## The Newsletter Analogy

Think of Provider like a newsletter subscription:

| Concept | Analogy | What It Does |
|---------|---------|--------------|
| **Provider** | Newsletter publisher | Holds and manages data |
| **Consumer** | Subscriber | Listens for updates |
| **notifyListeners()** | Send newsletter | Notifies all subscribers |
| **Widget rebuild** | Read newsletter | UI updates automatically |

## Architecture Overview

```
                    ┌──────────────────┐
                    │   AuthProvider   │  single source of userId
                    │    (identity)    │
                    └────────┬─────────┘
                             │ ChangeNotifierProxyProvider
                             │ → updateUserId(auth.userId)
                             ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Screen    │────►│  Provider   │────►│ Repository  │
│    (UI)     │     │  (State)    │     │   (Data)    │
└─────────────┘     └─────────────┘     └─────────────┘
       │                  │
       │                  │
  Consumer<T>()    notifyListeners()
  (auto rebuild)   (notify widgets)
       │                  │
       ▼                  ▼
┌─────────────┐    ┌─────────────┐
│   Widgets   │◄───│  ViewModel  │
│ (reusable)  │    │ (join data) │   ← Benefit feature only, see below
└─────────────┘    └─────────────┘
```

## Cross-Provider Dependencies

The chain above is not flat: **`AuthProvider` is the single source of `userId`**
(`auth_provider.dart:77` — `String? get userId => _currentUser?.id;`). Four of the eight providers
are wired as `ChangeNotifierProxyProvider<AuthProvider, X>` in `lib/main.dart`
(lines 155, 163, 172, 185):

- **Benefit / Progress / Activity** receive `updateUserId(auth.userId)`. On login they load their
  own data (`benefit_provider.dart:211`, `progress_provider.dart:48-50`); on logout
  (`userId == null`) they clear it (`benefit_provider.dart:200-208`,
  `progress_provider.dart:51-55`). `ActivityProvider` additionally completes any running session
  before switching users (`activity_provider.dart:183-190`).
- **Profile** flows the other way: it receives `attachAuth(auth)` and, *after* a successful
  repository write, syncs identity back via `AuthProvider.setCurrentUser(...)`
  (`profile_provider.dart:57-82` → `auth_provider.dart:713`). The repository is the source of
  truth; the in-memory identity is updated second.

The remaining three — `ConnectivityProvider`, `HealthPlatformProvider`, `AppLockProvider` — have no
user dependency and use plain `ChangeNotifierProvider`.

`AuthProvider` itself is the one provider *not* built with `create:`: it is constructed in
`bootstrap()` before `runApp` and shared with the go_router redirect and the deep-link handler,
then registered with `.value` (`lib/main.dart:133-153`). The full inventory table lives in
[PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md).

## The 5 Components

### 1. Repository
- **What:** Data source (API, database)
- **Purpose:** Fetch and store data
- **Benefit:** Swappable via abstract interface + implementation (SQLite is the production implementation)

### 2. Provider
- **What:** State management + business logic
- **Purpose:** Hold state, call repository, notify UI
- **Benefit:** Central state management

### 3. ViewModel
- **What:** Data transformation layer
- **Purpose:** Combine and format data for UI
- **Benefit:** Clean separation of concerns
- **Status: Benefit feature only.** `BenefitViewModel`
  (`lib/features/benefit/domain/benefit_view_model.dart`) is the single ViewModel class in `lib/`.
  Progress, Activity and Profile bind domain models directly (e.g. `ProgressProvider.activities`
  returns `List<ActivityEntry>`, `progress_provider.dart:64`). Treat this layer as the target
  pattern, not as current app-wide practice.

### 4. Screen
- **What:** Main view orchestrator
- **Purpose:** Initialize provider, handle states
- **Benefit:** Clear UI structure

### 5. Widgets
- **What:** Reusable UI components
- **Purpose:** Display data, no business logic
- **Benefit:** Reusable and testable

## State Handling

Screens are *expected* to handle 4 states:

| State | When | UI Shows |
|-------|------|----------|
| **Loading** | Fetching data | Spinner/skeleton |
| **Error** | Request failed | Error message (+ retry where the provider exposes one, e.g. `BenefitProvider.retry`) |
| **Empty** | No data | Empty state message |
| **Success** | Data loaded | Content list/view |

**Status as of 2026-08-28: only `BenefitScreen` implements all four**
(`benefit_screen.dart:160-178`) — it is the reference implementation.
`ProgressScreen` covers Loading + Error only (`progress_screen.dart:437-448`); its error branch
renders a bare `Text('Error: …\nTap to retry')` with **no tap handler**, and it has no empty branch
even though `ProgressProvider.isEmpty` exists (`progress_provider.dart:65`). `ActivityScreen` has
an error branch that passes `onRetry: null` (`activity_screen.dart:218-219`) and no empty branch.

The shared widgets for these states live in `lib/presentation/shared/widgets/`:
`LoadingWidget({String? message})`,
`ErrorDisplayWidget({required String message, VoidCallback? onRetry})` and
`EmptyStateWidget({required title, required message, required icon, Widget? action})`.

## Key Methods

| Method | Purpose | Usage |
|--------|---------|-------|
| `context.read<T>()` | Get provider once | In event handlers (48 usages in `lib/`) |
| `context.watch<T>()` | Subscribe to changes | In build methods — **0 usages in `lib/` today** |
| `Consumer<T>` | Auto-rebuild widget | Wrap UI that needs updates (16 usages in `lib/`) |
| `Selector<T, S>` / `context.select` | Rebuild only when one derived value changes | Around widgets reading a single field of a frequently-notifying provider — **0 usages today; see Performance below** |
| `notifyListeners()` | Trigger UI update | After state changes |

## Benefits

| Benefit | Description |
|---------|-------------|
| **Automatic Updates** | No manual setState() calls |
| **Separation** | Business logic separate from UI |
| **Testability** | Providers take their collaborators through the constructor (optional parameters default to the real implementation), so tests inject fakes — see *Testing a Provider* in [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md). Unit suites exist for 5 of the 8 providers; `ProgressProvider`, `AppLockProvider` and `ConnectivityProvider` are **not covered yet**. |
| **Scalability** | Grows with app complexity |
| **Performance** | Rebuilds are scoped to each `Consumer<T>` subtree, **not** to individual fields. With 16 `Consumer<T>` and zero `Selector`/`context.select`, `ActivityProvider`'s 1 Hz tick (`activity_provider.dart:697`) rebuilds the whole tracking subtree once per second. Introducing `Selector` where a widget reads a single field is an open improvement. |

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Feature Modules | [FEATURES.md](../../lib/features/FEATURES.md) | [FEATURES_OVERVIEW](../architecture/FEATURES_OVERVIEW.md) |
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](../screens/ACTIVITY_SCREEN_OVERVIEW.md) |
| Progress Screen | [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) | [PROGRESS_SCREEN_OVERVIEW](../screens/PROGRESS_SCREEN_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
