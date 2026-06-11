---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [Progress Screen Overview](../../../../documentation/screens/PROGRESS_SCREEN_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../../database/DATABASE.md) | [PROVIDER_GUIDE.md](../../PROVIDER_GUIDE.md) | [Session Feature](../../../features/session/)
---

# Progress Screen Implementation Plan

> **Implementation status (current code differs from this plan).** The Progress
> screen has shipped, but the final implementation evolved beyond the simple
> single-list design sketched in the phases below. Key differences in the
> shipped code (`progress_screen.dart` + `widgets/` + `progress_provider.dart`):
> - The provider stores its data as `List<ActivityEntry>` (a lightweight
>   `SharedPreferences`-backed model), **not** `List<Session>`. Completed DB
>   `Session`s are converted to `ActivityEntry` and merged with manually entered
>   activities.
> - The provider exposes `loadActivities()` / `updateUserId()` (no
>   `fetchSessions` / `refresh` / `isRefreshing`); user id is injected via
>   `ChangeNotifierProxyProvider` rather than a hard-coded `test-user-123`.
> - The provider adds manual-entry CRUD (`addActivity` / `updateActivity` /
>   `removeActivity`) and statistics aggregations
>   (`getDistancePerWeekday`, `getDurationPerWeekdayMinutes`,
>   `getDistancePerMonth`, `getDurationPerMonth`, `getDistancePerYear`,
>   `getTotalStats`).
> - The screen is a two-tab UI (`STATISTICS` / `ACTIVITIES`) built from
>   `StatisticsTab`, `ActivitiesTab`, `ActivityListItem`, `CustomBarChart` /
>   `CustomLineChart` (`custom_charts.dart`) and `ProgressSummary`, plus a
>   manual-entry dialog and an "EARNED SO FAR" bottom bar (no `RefreshIndicator`).
> - Tapping an activity opens `SessionDetailScreen`; manual entries open an
>   edit/delete dialog.
>
> The phase-by-phase walkthrough below is retained as the original learning-oriented
> plan and as a Provider-pattern reference.

## Overview: Provider Pattern in BeneFit

### What is the Provider Pattern?

**Provider** is a state management pattern for Flutter based on the **ChangeNotifier** pattern (similar to Observer Pattern). It enables automatic UI updates when data changes.

**Simple Analogy**: Like a newsletter subscription
- **Provider** = Newsletter publisher (has the data)
- **Consumer** = Subscriber (automatically notified)
- **notifyListeners()** = "Send newsletter" → all subscribers receive update
- **Widget rebuilds automatically** = Subscriber reads new newsletter

---

## Architecture Overview: How Everything Works Together

```
┌───────────────────────────────────────────────────────────────┐
│                    BeneFit App Architecture                    │
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │   SCREEN     │───►│   PROVIDER   │───►│  REPOSITORY  │     │
│  │     (UI)     │    │ (State Logic)│    │    (Data)    │     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
│         │                    │                                │
│         │                    │                                │
│    Consumer<T>()      notifyListeners()                       │
│    (auto rebuild)     (notify widgets)                        │
│         │                    │                                │
│         ▼                    ▼                                │
│  ┌──────────────┐    ┌──────────────┐                         │
│  │   WIDGETS    │◄───│  VIEW MODEL  │                         │
│  │  (reusable)  │    │ (join data)  │                         │
│  └──────────────┘    └──────────────┘                         │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

## The 5 Components Explained (Using Benefit Example)

### 1️⃣ **Repository** (`lib/features/<feature>/data/`)
**What**: Data source (later API, now mock data)
**Example**: `BenefitRepositoryImpl`
**Task**: Provide data

```dart
class BenefitRepositoryImpl implements BenefitRepository {
  Future<List<Benefit>> getAllBenefits() async {
    return _benefits; // Return mock data
  }
}
```

**Why do we need this?**
→ Separation of data source and logic. Later we can replace mock with real API without changing other parts.

---

### 2️⃣ **Provider** (`lib/providers/`)
**What**: State management + business logic
**Example**: `BenefitProvider`
**Task**:
- Hold state (`_isLoading`, `_benefits`)
- Call repository
- Notify UI via `notifyListeners()`

```dart
class BenefitProvider extends ChangeNotifier {
  bool _isLoading = false;
  List<UserBenefit> _userBenefits = [];

  // Getters for UI
  bool get isLoading => _isLoading;
  List<BenefitViewModel> get earnedBenefits => /* join data */;

  Future<void> fetchBenefits() async {
    _isLoading = true;
    notifyListeners(); // 🔔 UI shows Loading

    _userBenefits = await _repository.getUserBenefits(userId: _currentUserId!);

    _isLoading = false;
    notifyListeners(); // 🔔 UI shows Data
  }
}
```

**Why do we need this?**
→ Central place for state + logic. UI doesn't need to worry about data fetching.

---

### 3️⃣ **ViewModel** (`lib/features/<feature>/domain/`)
**What**: Connects and transforms data for the UI
**Example**: `BenefitViewModel`
**Task**: Merge multiple data sources + formatting

```dart
class BenefitViewModel {
  final UserBenefit userBenefit; // When earned?
  final Benefit benefit;         // What is the benefit?

  // Convenient getters for UI
  String get title => benefit.title;
  String get formattedAmount => benefit.formattedDiscount;
  String get formattedDate => /* format userBenefit.earnedAt */;
}
```

**Why do we need this?**
→ `UserBenefit` and `Benefit` are separate in the backend. ViewModel unites them for the UI. Formatting logic stays out of UI and Provider.

**In Provider:**
```dart
List<BenefitViewModel> get earnedBenefits {
  return _userBenefits.map((userBenefit) {
    final benefit = _benefits.firstWhere((b) => b.id == userBenefit.benefitId);
    return BenefitViewModel(userBenefit: userBenefit, benefit: benefit);
  }).toList();
}
```

---

### 4️⃣ **Screen** (`lib/presentation/screens/`)
**What**: Main view, orchestrates UI
**Example**: `BenefitScreen`
**Task**:
- Initialize provider (`fetchBenefits()`)
- Use Consumer (reacts to `notifyListeners()`)
- Render 4 states: Loading, Error, Empty, Success

```dart
class BenefitScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BenefitProvider>().fetchBenefits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<BenefitProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return LoadingWidget();
          if (provider.hasError) return ErrorWidget();
          if (provider.isEmpty) return EmptyWidget();
          return BenefitList(benefits: provider.earnedBenefits);
        },
      ),
    );
  }
}
```

**Important Concepts:**
- **`context.read<T>()`** = Call provider WITHOUT rebuild (for buttons/events)
- **`Consumer<T>`** = Automatic rebuild on `notifyListeners()`

---

### 5️⃣ **Widgets** (`lib/presentation/screens/.../widgets/`)
**What**: Reusable UI components
**Example**: `BenefitCard`, `BenefitList`
**Task**: Display individual elements (dumb components, no logic)

```dart
class BenefitCard extends StatelessWidget {
  final BenefitViewModel benefitVM;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(benefitVM.title),
        subtitle: Text(benefitVM.description),
        trailing: Text(benefitVM.formattedAmount),
      ),
    );
  }
}
```

**Why do we need this?**
→ Screen becomes clearer. Widgets are reusable and testable.

---

## Step-by-Step: Implementing Progress Screen

### Phase 1: Create Provider

**File**: `lib/providers/progress_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/domain/session.dart';

class ProgressProvider extends ChangeNotifier {
  final SessionRepository _repository;
  ProgressProvider(this._repository);

  // State
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  List<Session> _sessions = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  List<Session> get sessions => _sessions;
  bool get hasError => _error != null;
  bool get isEmpty => !_isLoading && _sessions.isEmpty;

  // Computed properties
  int get totalSessions => _sessions.length;
  double get totalDistance => _sessions.fold(0.0, (sum, s) => sum + (s.distanceMeters ?? 0));
  int get totalDuration => _sessions.fold(0, (sum, s) => sum + (s.durationSeconds ?? 0));

  // Methods
  Future<void> fetchSessions(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await _repository.getAllSessions(userId: userId);
      _sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      _error = null;
    } catch (e) {
      _error = 'Error loading: $e';
      _sessions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String userId) async {
    _isRefreshing = true;
    notifyListeners();

    try {
      _sessions = await _repository.getAllSessions(userId: userId);
      _sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
```

---

### Phase 2: Register Provider

**File**: `lib/main.dart`

> **Status (implemented):** `ProgressProvider` is registered as a
> `ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>` so it receives
> the current `userId` from `AuthProvider` and reloads activities when the user
> changes. (The simpler `ChangeNotifierProvider` originally planned below was
> superseded by the proxy approach.)

```dart
MultiProvider(
  providers: [
    // ... AuthProvider must be registered first ...
    ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>(
      create: (_) => ProgressProvider(
        RepositoryConfig.getSessionRepository(),
      ),
      update: (_, userProvider, progressProvider) {
        progressProvider?.updateUserId(userProvider.userId);
        return progressProvider!;
      },
    ),
  ],
  child: const BeneFitApp(),
)
```

---

### Phase 3: Update Screen

**File**: `lib/presentation/screens/progress/progress_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/progress_provider.dart';
import 'package:benefitflutter/presentation/shared/widgets/loading_widget.dart';
import 'package:benefitflutter/presentation/shared/widgets/error_display_widget.dart';
import 'package:benefitflutter/presentation/shared/widgets/empty_state_widget.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const String _userId = 'test-user-123';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressProvider>().fetchSessions(_userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Consumer<ProgressProvider>(
        builder: (context, provider, child) {
          // 1. Loading State
          if (provider.isLoading) {
            return const LoadingWidget(message: 'Loading sessions...');
          }

          // 2. Error State
          if (provider.hasError) {
            return ErrorDisplayWidget(
              message: provider.error!,
              onRetry: () => provider.fetchSessions(_userId),
            );
          }

          // 3. Empty State
          if (provider.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.directions_run,
              title: 'No sessions yet',
              message: 'Start your first workout!',
            );
          }

          // 4. Success State
          return RefreshIndicator(
            onRefresh: () => provider.refresh(_userId),
            child: ListView.builder(
              itemCount: provider.sessions.length,
              itemBuilder: (context, index) {
                final session = provider.sessions[index];
                return ListTile(
                  leading: Icon(_getActivityIcon(session.activityType)),
                  title: Text(_getActivityName(session.activityType)),
                  subtitle: Text(_formatDate(session.startTime)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(session.formattedDistance),
                      Text(session.formattedDuration),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.walking: return Icons.directions_walk;
      case ActivityType.running: return Icons.directions_run;
      case ActivityType.cycling: return Icons.directions_bike;
      default: return Icons.help_outline;
    }
  }

  String _getActivityName(ActivityType type) {
    switch (type) {
      case ActivityType.walking: return 'Walking';
      case ActivityType.running: return 'Running';
      case ActivityType.cycling: return 'Cycling';
      default: return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) return 'Today';
    if (sessionDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}.${date.month}.${date.year}';
  }
}
```

---

### Phase 4: Add Interactivity

#### 🎯 Clickable Sessions

Sessions should be clickable to show details later. For now we show a Toast/SnackBar.

**Important Concepts:**

1. **`onTap` Callback** - Passed up from ListTile
2. **SnackBar** - Temporary message at bottom
3. **`context.read<T>()`** - Access provider without rebuild (in event handlers)

---

#### Updated Screen Implementation with Interactivity:

```dart
// 4. Success State with clickable sessions
return RefreshIndicator(
  onRefresh: () => provider.refresh(_userId),
  child: ListView.builder(
    itemCount: provider.sessions.length,
    itemBuilder: (context, index) {
      final session = provider.sessions[index];
      return ListTile(
        leading: Icon(_getActivityIcon(session.activityType)),
        title: Text(_getActivityName(session.activityType)),
        subtitle: Text(_formatDate(session.startTime)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(session.formattedDistance),
            Text(session.formattedDuration),
          ],
        ),
        // ⭐ Add onTap handler
        onTap: () => _onSessionTapped(context, session),
      );
    },
  ),
);

// ⭐ Method for session tap
void _onSessionTapped(BuildContext context, Session session) {
  // For now: Show SnackBar (later: Navigate to detail screen)
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${_getActivityName(session.activityType)}: ${session.formattedDistance} • ${session.formattedDuration}',
      ),
      duration: const Duration(seconds: 2),
      action: SnackBarAction(
        label: 'Details',
        onPressed: () {
          // TODO: Navigate to session detail screen
          debugPrint('Navigate to session ${session.id}');
        },
      ),
    ),
  );
}
```

---

#### Alternative: Session Card Widget (extracted)

**File**: `lib/presentation/screens/progress/widgets/session_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';

/// Reusable Session Card with tap handling
class SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;

  const SessionCard({
    super.key,
    required this.session,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(  // ⭐ InkWell for ripple effect
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Activity Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getActivityColor(session.activityType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getActivityIcon(session.activityType),
                  color: _getActivityColor(session.activityType),
                ),
              ),
              const SizedBox(width: 16),

              // Session Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getActivityName(session.activityType),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(session.startTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),

              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    session.formattedDistance,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.formattedDuration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.walking:
        return Icons.directions_walk;
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.cycling:
        return Icons.directions_bike;
      default:
        return Icons.help_outline;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.walking:
        return Colors.green;
      case ActivityType.running:
        return Colors.orange;
      case ActivityType.cycling:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getActivityName(ActivityType type) {
    switch (type) {
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.running:
        return 'Running';
      case ActivityType.cycling:
        return 'Cycling';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(date.year, date.month, date.day);

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (sessionDate == today) {
      return 'Today, $time';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}, $time';
    }
  }
}
```

**Usage in Screen:**
```dart
ListView.builder(
  itemCount: provider.sessions.length,
  itemBuilder: (context, index) {
    final session = provider.sessions[index];
    return SessionCard(
      session: session,
      onTap: () => _onSessionTapped(context, session),
    );
  },
)
```

---

#### Interaction Concepts Explained

**1️⃣ InkWell vs GestureDetector**

```dart
// ✅ InkWell = Material ripple effect (better for Material Design)
InkWell(
  onTap: () => doSomething(),
  borderRadius: BorderRadius.circular(12), // Ripple follows border
  child: Container(...),
)

// ⚠️ GestureDetector = No visual feedback
GestureDetector(
  onTap: () => doSomething(),
  child: Container(...),
)
```

**2️⃣ SnackBar vs Toast**

```dart
// SnackBar (Material Design standard)
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Session tapped!'),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () { /* action */ },
    ),
  ),
);

// For longer duration
duration: const Duration(seconds: 3),
```

**3️⃣ Callback Pattern**

```dart
// Widget defines callback
class SessionCard extends StatelessWidget {
  final VoidCallback? onTap;  // Nullable = optional

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,  // Passed from Screen
      child: ...,
    );
  }
}

// Screen passes handler
SessionCard(
  session: session,
  onTap: () => _onSessionTapped(context, session),
)
```

**Why like this?**
→ Widget stays "dumb" (no logic), Screen orchestrates the behavior

---

#### Future Extension: Navigation to Detail Screen

> **Status update (go_router):** Navigation is now declarative via go_router, not
> `Navigator.push`/`MaterialPageRoute`. The shipped `progress_screen.dart` taps
> route through `_openSessionDetails(context, entry)` which calls
> `context.push('/session/${entry.sessionId}')` (route defined in
> `lib/core/router/app_router.dart`). The `Navigator.push` sketch below is the
> original plan, kept for historical context.

```dart
void _onSessionTapped(BuildContext context, Session session) {
  // Later: Navigate to SessionDetailScreen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SessionDetailScreen(sessionId: session.id),
    ),
  );
}
```

---

## Summary: Why This Architecture?

| Component | Responsibility | Advantage |
|-----------|---------------|-----------|
| **Repository** | Provide data | Interchangeable (Mock → API) |
| **Provider** | State + Logic | Central management, automatic updates |
| **ViewModel** | Combine data | UI gets ready-to-use data |
| **Screen** | Orchestrate UI | Clear, only presentation |
| **Widgets** | Small UI parts | Reusable, testable |

**Provider Pattern = Automatic UI updates without manual setState() calls!**

---

## Checklist

- [ ] Create `lib/providers/progress_provider.dart`
- [ ] Register provider in `main.dart`
- [ ] Update `progress_screen.dart` with Consumer
- [ ] Implement 4 states (Loading, Error, Empty, Success)
- [ ] Optional: Extract widgets (`session_card.dart`)
- [ ] Test: Start app, open Progress tab

---

## References

**For reference:**
- Benefit Screen: `lib/presentation/screens/benefit/benefit_screen.dart`
- Benefit Provider: `lib/providers/benefit_provider.dart`
- Provider Guide: `lib/presentation/PROVIDER_GUIDE.md`
