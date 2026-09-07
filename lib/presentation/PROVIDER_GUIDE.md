---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [PROVIDER_GUIDE_OVERVIEW.md](../../documentation/guides/PROVIDER_GUIDE_OVERVIEW.md) - High-level concepts
>
> **Related:** [FEATURES.md](../features/FEATURES.md) | Screen Plans in screens/*/
>
> **Stand:** 2026-08-28 — verified against `lib/providers/` (8 providers) and the `MultiProvider`
> in `lib/main.dart` (lines 151-199), branch `feat/phase-2-background-tracking`.
---

# Provider Pattern Guide for BeneFit Team

## What is Provider?

Provider is a **state management** solution for Flutter. Think of it as a smart container that:
1. Holds your data and logic (the "state")
2. Automatically updates the UI when state changes
3. Shares state across multiple screens

**Simple Analogy**: Provider is like a TV remote control. When you press a button (change state), the TV (UI) automatically updates. You don't need to manually tell the TV to change - it just knows!

---

## Why We Use Provider

✅ **Automatic UI Updates**: Change state → UI rebuilds automatically
✅ **Clean Separation**: Business logic separate from UI
✅ **Easy to Learn**: Simpler than BLoC or Redux
✅ **Industry Standard**: Used by thousands of Flutter apps
✅ **Scalable**: Works for small and large apps

---

## The 8 Providers

`lib/providers/` holds exactly **8 `ChangeNotifier` classes**, and all 8 are registered in the
`MultiProvider` in `lib/main.dart` (lines 151-199). There is no other state-management library in
the project (no Riverpod, no BLoC).

| Provider | File (`lib/providers/`) | Registration in `lib/main.dart` | Constructor dependencies |
|---|---|---|---|
| `AuthProvider` | `auth_provider.dart` | `ChangeNotifierProvider<AuthProvider>.value` — line 153. **Must be first.** | `repository`, `authService`, `tokenStorage` required; `rateLimiter` optional |
| `ProfileProvider` | `profile_provider.dart` | `ChangeNotifierProxyProvider<AuthProvider, …>` → `attachAuth(auth)` — lines 155-161 | `UserRepository` |
| `BenefitProvider` | `benefit_provider.dart` | Proxy → `updateUserId(auth.userId)` — lines 163-170 | `BenefitRepository` |
| `ProgressProvider` | `progress_provider.dart` | Proxy → `updateUserId(auth.userId)` — lines 172-179 | `SessionRepository` |
| `ConnectivityProvider` | `connectivity_provider.dart` | plain `ChangeNotifierProvider` — lines 181-183 | `ConnectivityService` |
| `ActivityProvider` | `activity_provider.dart` | Proxy → `updateUserId(auth.userId)` — lines 185-194 | `SessionRepository`; optional `userId`, `sensorManager`, `gpsPointDao`, `bleDataSource`, `biometricDao`, `now` |
| `HealthPlatformProvider` | `health_platform_provider.dart` | plain `ChangeNotifierProvider` — line 196 | optional `syncService` |
| `AppLockProvider` | `app_lock_provider.dart` | plain `ChangeNotifierProvider` — line 198 | optional `biometricService` |

**Repositories** come from the static factory `RepositoryConfig`
(`lib/core/config/repository_config.dart`), which returns the *interface* types
(`SessionRepository` / `UserRepository` / `BenefitRepository`) backed by the SQLite
implementations. Mock repositories have been removed.

> **`AuthProvider` is the one exception to `create:`.** It is constructed inside `bootstrap()`
> *before* `runApp` (`lib/main.dart:133-137`) and handed to `createAppRouter(authProvider)`
> (line 138) and `DeepLinkHandler(router:, authProvider:)` (lines 142-145), then registered with
> `ChangeNotifierProvider<AuthProvider>.value(...)` (line 153) — so the go_router redirect, the
> deep-link handler and the widget tree all observe **one** instance. Following Step 2 below with
> a `create:` for `AuthProvider` would produce a second, divergent instance. `bootstrap()` is
> public so integration tests can boot the real app without `main()`'s `runZonedGuarded`
> (`lib/main.dart:99-103`).

---

## App-Lifecycle Hooks (root widget → providers)

`_BeneFitAppState` in `lib/main.dart` is a `WidgetsBindingObserver`, so a few provider methods are
called by the app shell rather than by a screen. That is why `flushPendingGps()` and
`retryGpsIfNeeded()` are public on `ActivityProvider`.

| Lifecycle event | What `lib/main.dart` does |
|---|---|
| `paused` / `inactive` (lines 237-242) | `AppLockProvider.onAppPaused()`, then `_flushGpsOnBackground()` (line 254) → `ActivityProvider.flushPendingGps()` (`activity_provider.dart:820`) when `isTracking \|\| isPaused`, so buffered GPS points survive an OS kill |
| `resumed` (lines 244-246 → 261-279) | While a session runs: `ActivityProvider.retryGpsIfNeeded()` (`activity_provider.dart:777`), then `AppLockProvider.onAppResumed(isTrackingActive: ...)` so the biometric lock never fires mid-session |

**GPS buffer policy (WP5):** points are written in batches — flushed at 5 buffered points, or when
the buffer is older than 60 s (`_gpsBatchSize` / `_maxBufferAge`, `activity_provider.dart:71-72`),
plus on pause/stop/background. Only points buffered since the last flush can be lost on a hard
process kill that skips the `paused` event.

---

## Anatomy of the Benefit Implementation

We've fully implemented the Benefit tab as a reference. Here's how it works:

### **1. The Provider** (`lib/providers/benefit_provider.dart`)

**Purpose**: Manages ALL state for the Benefit screen

**Key Parts**:
```dart
class BenefitProvider extends ChangeNotifier {
  final BenefitRepository _repository;

  BenefitProvider(this._repository);

  // State variables (private)
  String? _currentUserId;              // pushed in by the ProxyProvider
  bool _isLoading = false;
  String? _error;
  List<UserBenefit> _userBenefits = [];
  List<Benefit> _benefits = [];
  double _totalSavings = 0.0;

  // Getters (public - UI reads these)
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => !_isLoading && _userBenefits.isEmpty;
  double get totalSavings => _totalSavings;

  /// Joins UserBenefit + Benefit metadata — THIS is what the UI consumes.
  /// `_benefits` itself is never exposed. (benefit_provider.dart:72-87)
  List<BenefitViewModel> get earnedBenefits { /* join by benefitId */ }

  // Methods (public - UI calls these)
  Future<void> fetchBenefits() async {
    if (_currentUserId == null) return;      // no user attached yet
    _isLoading = true;
    _error = null;
    notifyListeners();                       // ← MAGIC! Tells UI to rebuild

    try {
      // Three repository calls in parallel
      final results = await Future.wait([
        _repository.getUserBenefits(userId: _currentUserId!),
        _repository.getAllBenefits(),
        _repository.getTotalDiscountEarned(userId: _currentUserId!),
      ]);
      _userBenefits = results[0] as List<UserBenefit>;
      _benefits = results[1] as List<Benefit>;
      _totalSavings = results[2] as double;
      _error = null;
    } catch (e) {
      _error = 'Failed to load benefits: ${e.toString()}';
      _userBenefits = [];
      _benefits = [];
      _totalSavings = 0.0;
    } finally {
      _isLoading = false;
      notifyListeners();                     // ← UI rebuilds with new state
    }
  }

  /// Retry after an error — wired straight into ErrorDisplayWidget.onRetry
  Future<void> retry() => fetchBenefits();

  /// Called by the ChangeNotifierProxyProvider when the logged-in user changes:
  /// clears everything on logout, fetches on login. (benefit_provider.dart:193-211)
  void updateUserId(String? userId) { /* ... */ }
}
```

**Important Concepts**:
- **Private variables** (`_isLoading`) = internal state
- **Getters** (`get isLoading`) = how UI reads state
- **Methods** (`fetchBenefits()`) = how UI changes state
- **`notifyListeners()`** = tells Flutter to rebuild widgets
- **`updateUserId(...)`** = the seam the `ChangeNotifierProxyProvider` uses to push the
  current user in (`lib/main.dart:163-170`) — the provider never reads auth state itself

### **2. The Screen** (`lib/presentation/screens/benefit/benefit_screen.dart`)

**Purpose**: Orchestrates the UI using the Provider

**Key Parts**:
```dart
class _BenefitScreenState extends State<BenefitScreen> {
  // NOTE: there is deliberately NO fetch in initState. The first load is
  // triggered by BenefitProvider.updateUserId(...) from the
  // ChangeNotifierProxyProvider in lib/main.dart:163-170, as soon as
  // AuthProvider exposes a userId. (The screen's own post-frame callback is
  // empty — benefit_screen.dart:30-34. The only in-screen fetchBenefits()
  // call is the refresh after a debug database reseed, line 97.)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BeneFit')),
      body: Consumer<BenefitProvider>(
        builder: (context, provider, child) {
          // UI automatically rebuilds when provider changes.
          // 1. Loading
          if (provider.isLoading) {
            return const LoadingWidget(message: 'Loading your BeneFits...');
          }
          // 2. Error — retry wired to a provider method
          if (provider.hasError) {
            return ErrorDisplayWidget(
              message: provider.error!,
              onRetry: provider.retry,
            );
          }
          // 3. Empty
          if (provider.isEmpty) return const EmptyBenefitsWidget();
          // 4. Success
          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: BenefitList(benefits: provider.earnedBenefits),
          );
        },
      ),
    );
  }
}
```

**Important Concepts**:
- **`Consumer<T>`** = Listens to provider, rebuilds when state changes
- **`context.read<T>()`** = Access provider to call methods (doesn't rebuild)
- **`provider.xxx`** = Read state from provider
- **Shared state widgets** = `LoadingWidget`, `ErrorDisplayWidget` and `EmptyStateWidget` live in
  `lib/presentation/shared/widgets/`. Do **not** use Flutter's built-in `ErrorWidget` — it is the
  framework's red error box and requires a positional `Object exception` argument.
- **Four branches, not three** — `BenefitScreen` (benefit_screen.dart:160-178) is the reference
  implementation of the Loading / Error / Empty / Success contract.

### **3. Widgets** (`lib/presentation/screens/benefit/widgets/`)

**Purpose**: Reusable UI components

**The four widgets in this folder**:
- `TotalSavingsCard` - Shows total savings
- `BenefitCard` - Shows individual benefit
- `BenefitList` - List of earned benefits (takes `List<BenefitViewModel>`, not `List<Benefit>`)
- `EmptyBenefitsWidget` - Empty state shown when the user has earned nothing yet

**Pattern**: Small, focused, reusable

### **4. ViewModel** (`lib/features/benefit/domain/benefit_view_model.dart`)

**Purpose**: Combines data from multiple sources

**Example**:
```dart
class BenefitViewModel {
  final UserBenefit userBenefit;
  final Benefit benefit;

  String get title => benefit.title;
  String get formattedDate => // format logic here
}
```

**Why?**: Keeps formatting logic out of Provider and widgets

**Note**: ViewModels now live in the feature module's `domain/` folder for better organization

**Status: Benefit only.** `BenefitViewModel` is the *single* ViewModel class in all of `lib/`.
Progress, Activity and Profile bind domain models straight to widgets (e.g.
`ProgressProvider.activities` returns `List<ActivityEntry>`, `progress_provider.dart:64`, and
`ProgressProvider.getTotalStats()` formats inside the provider, line 362). Treat the ViewModel
layer as the *target* pattern, not as something the whole app already follows.

---

## Step-by-Step: Create Your Own Provider

> **Status note (kept for onboarding):** The `ProgressProvider`, `ActivityProvider`,
> and `BenefitProvider` below have since been implemented and now live in
> `lib/providers/`. Identity/auth state is served by **`AuthProvider`**
> (`lib/providers/auth_provider.dart`) and editable profile data by **`ProfileProvider`**
> (`lib/providers/profile_provider.dart`) — these replaced the former monolithic
> `UserProvider` in Phase 1 / Round 2. The snippets in this section are intentionally
> simplified teaching examples and differ from the shipped code. In particular, the
> providers that depend on the logged-in user (Progress, Activity, Benefit) are wired with
> `ChangeNotifierProxyProvider<AuthProvider, …>` in `lib/main.dart` (not a plain
> `ChangeNotifierProvider`) and receive the current user via an `updateUserId(...)`
> callback rather than taking a `userId` argument per method. In production the ProxyProvider is
> the only writer of `userId`, but `ActivityProvider` additionally accepts an optional `userId:`
> **constructor** argument as a test seam (`activity_provider.dart:98`).
> `ProfileProvider` itself is a
> `ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>` that pushes profile edits
> back into `AuthProvider` via `setCurrentUser(...)`. Study the real classes
> in `lib/providers/` alongside these examples.
>
> Method names differ too: the shipped `ProgressProvider` has **no** `fetchSessions()` /
> `refresh()` — it exposes `loadActivities()`, `initialize()` and
> `List<ActivityEntry> get activities` (`progress_provider.dart:39, 64, 117`) and works on
> `ActivityEntry` (manual entries + DB sessions combined), not on raw `Session` objects.

### **Checklist for Progress Tab** (Developer 2)

#### **Step 1: Create ProgressProvider**

**File**: `lib/providers/progress_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/domain/session.dart';

class ProgressProvider extends ChangeNotifier {
  final SessionRepository _repository;

  ProgressProvider(this._repository);

  // State variables
  String? _userId;                 // pushed in by the ProxyProvider
  bool _isLoading = false;
  String? _error;
  List<Session> _sessions = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Session> get sessions => _sessions;
  bool get hasError => _error != null;
  bool get isEmpty => !_isLoading && _sessions.isEmpty;

  /// Called by the ChangeNotifierProxyProvider when the logged-in user changes.
  void updateUserId(String? newUserId) {
    if (_userId == newUserId) return;
    _userId = newUserId;
    if (newUserId == null) {       // logout → clear state
      _sessions = [];
      notifyListeners();
      return;
    }
    fetchSessions();               // login → load
  }

  // Methods
  Future<void> fetchSessions() async {
    if (_userId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await _repository.getAllSessions(userId: _userId!);
      _error = null;
    } catch (e) {
      _error = 'Failed to load sessions: ${e.toString()}';
      _sessions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => fetchSessions();
}
```

> Do **no async work in the constructor** — the real `ProgressProvider` keeps it empty for exactly
> this reason (`progress_provider.dart:32-36`), which is what makes it unit-testable.

#### **Step 2: Register Provider in main.dart**

Add to the providers list. **User-scoped providers proxy off `AuthProvider`** — this is what
`lib/main.dart` actually does (lines 172-179):

```dart
ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>(
  create: (_) => ProgressProvider(RepositoryConfig.getSessionRepository()),
  update: (_, authProvider, progressProvider) {
    progressProvider?.updateUserId(authProvider.userId);
    return progressProvider!;
  },
),
```

Only providers with **no** user dependency use the plain form (`ConnectivityProvider`,
`HealthPlatformProvider`, `AppLockProvider`):

```dart
ChangeNotifierProvider(create: (_) => ConnectivityProvider(ConnectivityService())),
```

#### **Step 3: Update ProgressScreen**

```dart
class ProgressScreen extends StatefulWidget {
  // No fetch in initState: ProgressProvider.updateUserId(...) loads on login.
  // (Hardcoded user ids such as 'test-user-123' were removed from production
  //  code when UserProvider was split into AuthProvider + ProfileProvider.)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Consumer<ProgressProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingWidget(message: 'Loading sessions...');
          }

          if (provider.hasError) {
            return ErrorDisplayWidget(
              message: provider.error!,
              onRetry: provider.fetchSessions,
            );
          }

          if (provider.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.list_alt,
              title: 'No Sessions Yet',
              message: 'Start tracking to see your progress!',
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView.builder(
              itemCount: provider.sessions.length,
              itemBuilder: (context, index) {
                final session = provider.sessions[index];
                return ListTile(
                  title: Text(session.activityType.name),
                  subtitle: Text(session.formattedDistance),
                  trailing: Text(session.formattedDuration),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
```

#### **Step 4: Create Widgets**

Create folder: `lib/presentation/screens/progress/widgets/`

Create file: `session_card.dart`
```dart
class SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;

  // ... build card UI
}
```

---

### **Checklist for Profile Tab** (Developer 1)

Follow same pattern as Progress, but add:
- `bool _isEditMode` state
- `void toggleEditMode()` method
- `Future<void> updateUser(User user)` method

---

### **Checklist for Activity Tab** (Developer 3)

> **How the shipped `ActivityProvider` differs from this sketch:** it does **not** increment a
> counter per tick. The 1 s `Timer.periodic` only calls `notifyListeners()`
> (`activity_provider.dart:692-699`); elapsed time is *derived from timestamps* in the private
> `_elapsedSeconds` getter (`activity_provider.dart:125-130`), so a background-throttled timer
> cannot cause drift (WP4). The real API is `startSession()` / `pauseSession()` /
> `resumeSession()` / `stopSession()` over a `TrackingState` enum (idle / tracking / paused,
> `lib/core/enums/tracking_state.dart`) — not `startTracking()` / `stopTracking()`.

Different pattern (timer-based):
```dart
class ActivityProvider extends ChangeNotifier {
  bool _isTracking = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  bool get isTracking => _isTracking;
  int get elapsedSeconds => _elapsedSeconds;

  void startTracking() {
    _isTracking = true;
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners(); // Updates UI every second
    });
    notifyListeners();
  }

  void stopTracking() {
    _timer?.cancel();
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

---

## Common Patterns Reference

### Pattern 1: Reading State
```dart
// In Consumer builder
final isLoading = provider.isLoading;
final data = provider.data;
```

### Pattern 2: Calling Methods
```dart
// Use context.read<> when you DON'T need to rebuild
ElevatedButton(
  onPressed: () {
    context.read<MyProvider>().doSomething();
  },
)
```

### Pattern 3: Computed Properties
```dart
// In Provider
List<Session> get filteredSessions {
  return _sessions.where((s) => s.isActive).toList();
}
```

### Pattern 4: State Patterns
```dart
// Loading → Error → Empty → Success (the 4-state contract; see BenefitScreen)
if (provider.isLoading) return const LoadingWidget(message: 'Loading…');
if (provider.hasError) {
  return ErrorDisplayWidget(message: provider.error!, onRetry: provider.retry);
}
if (provider.isEmpty) {
  return const EmptyStateWidget(
    icon: Icons.inbox,
    title: 'Nothing here yet',
    message: 'Start tracking to see data.',
  );
}
return SuccessWidget();
```

`ErrorDisplayWidget`, `LoadingWidget` and `EmptyStateWidget` come from
`lib/presentation/shared/widgets/`. Flutter's own `ErrorWidget` is a different class (the red
error box) and takes a positional `Object exception` — do not use it here.

---

## Team Assignments

> **Status note (kept for onboarding):** These assignments are complete. The Progress
> and Activity tabs ship with `ProgressProvider` / `ActivityProvider` in
> `lib/providers/`. The Profile tab reads identity from **`AuthProvider`** and its
> editable data (profile fields, biometrics, preferences) from **`ProfileProvider`**
> (`lib/providers/profile_provider.dart`); authentication itself lives in `AuthProvider`
> (`lib/providers/auth_provider.dart`). These two replaced the former monolithic
> `UserProvider` in Phase 1 / Round 2. The exact "Files to Create" paths below were the
> original plan and do not all match the shipped layout (e.g. there is no
> `profile/widgets/` or `activity/widgets/` directory; Progress widgets live in
> `lib/presentation/screens/progress/widgets/` as `activities_tab.dart`,
> `statistics_tab.dart`, `activity_list_item.dart`, etc.).

### **Developer 1: Profile Tab** (Easiest)
**Task**: Create ProfileProvider + ProfileScreen

**Data**: Single User object
**Challenge**: Edit mode toggle, form validation
**Estimated Time**: 4-6 hours

**Files to Create**:
- `lib/providers/profile_provider.dart`
- `lib/presentation/screens/profile/widgets/profile_card.dart`
- Update `lib/presentation/screens/profile/profile_screen.dart`

---

### **Developer 2: Progress Tab** (Medium)
**Task**: Create ProgressProvider + ProgressScreen

**Data**: List of 20 Sessions
**Challenge**: List rendering, date grouping
**Estimated Time**: 6-8 hours

**Files to Create**:
- `lib/providers/progress_provider.dart`
- `lib/presentation/screens/progress/widgets/session_card.dart`
- Update `lib/presentation/screens/progress/progress_screen.dart`

---

### **Developer 3: Activity Tab** (Hardest)
**Task**: Create ActivityProvider + ActivityScreen

**Data**: Timer state (real-time updates)
**Challenge**: Timer management, periodic updates
**Estimated Time**: 8-10 hours

**Files to Create**:
- `lib/providers/activity_provider.dart`
- `lib/presentation/screens/activity/widgets/timer_display.dart`
- `lib/presentation/screens/activity/widgets/tracking_button.dart`
- Update `lib/presentation/screens/activity/activity_screen.dart`

---

## Testing a Provider (injection seams)

Every provider takes its collaborators through the constructor; optional parameters default to the
real implementation, so `lib/main.dart` stays terse while tests can pass fakes.

- `ActivityProvider(this._sessionRepository, {String? userId, SensorManager? sensorManager, GpsPointDao? gpsPointDao, BleDataSource? bleDataSource, SessionBiometricDataDao? biometricDao, DateTime Function()? now})` — `activity_provider.dart:96-109`. The `now` seam makes the timestamp-derived duration deterministic; `userId` sets identity without the ProxyProvider. Used as `ActivityProvider(mockRepo, userId: 'test-user-123')` in `test/unit/providers/activity_provider_test.dart:20`.
- `HealthPlatformProvider({HealthSyncService? syncService})` — `health_platform_provider.dart:10-11`; the test injects `HealthPlatformProvider(syncService: FakeHealthSyncService())`.
- `AppLockProvider({BiometricService? biometricService})` — `app_lock_provider.dart:14-15`.
- `AuthProvider({required repository, required authService, required tokenStorage, RateLimiterService? rateLimiter})` — `auth_provider.dart:24-32`.
- `ProfileProvider(this._repository)` plus `attachAuth(auth)` — `profile_provider.dart:19, 29-31`; test pattern: `ProfileProvider(repo)..attachAuth(authProvider)`.
- `ProgressProvider(this._sessionRepository)` does **no async work in the constructor** (`progress_provider.dart:32-36`); the first load comes from `updateUserId(...)` or the explicit `initialize()`.
- `ConnectivityProvider(this._connectivityService)` is the exception: its constructor calls `_initialize()` (`connectivity_provider.dart:28-30`), so a test must supply a fake service.

**Coverage status (2026-08-28):** unit suites exist in `test/unit/providers/` for activity, auth,
benefit, health_platform and profile. **`ProgressProvider`, `AppLockProvider` and
`ConnectivityProvider` have no unit tests yet** — an open gap, not an oversight in this doc.

---

## Tips & Best Practices

✅ **DO**:
- Keep providers focused (one screen = one provider)
- Use private variables (`_data`) with public getters
- Always call `notifyListeners()` after state changes
- Handle errors gracefully
- Use `const` constructors for widgets when possible

❌ **DON'T**:
- Put UI code in providers (keep it pure logic)
- Forget to call `notifyListeners()`
- Create providers for every tiny widget
- Use `context.watch<>()` in event handlers (use `context.read<>()` instead)

---

## Debugging Tips

**Problem**: UI doesn't update
**Solution**: Did you call `notifyListeners()`?

**Problem**: "ProviderNotFoundException"
**Solution**: Did you register the provider in `main.dart`?

**Problem**: Too many rebuilds
**Solution**: Use `const` widgets, check if you're calling `notifyListeners()` too often, and
narrow the rebuild scope. A `Consumer<T>` rebuilds its **whole** subtree — e.g. `ActivityProvider`
notifies once per second while a session runs (`activity_provider.dart:697`), rebuilding the
entire `Consumer<ActivityProvider>` in `activity_screen.dart:215`. `Selector<T, S>` /
`context.select` would rebuild only on a single derived value.
**Status: not used anywhere in `lib/` today** (0 `Selector`, 0 `context.select`, 0
`context.watch`; 16 `Consumer<T>` and 48 `context.read<T>()`).

---

## Questions?

**Study the Benefit implementation** - it's a complete, working example of everything you need!

**Key files to review**:
1. `lib/providers/benefit_provider.dart` - The provider
2. `lib/presentation/screens/benefit/benefit_screen.dart` - The screen
3. `lib/main.dart` - Provider registration

Good luck! 🚀
