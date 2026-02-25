---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [PROVIDER_GUIDE_OVERVIEW.md](../../documentation/guides/PROVIDER_GUIDE_OVERVIEW.md) - High-level concepts
>
> **Related:** [FEATURES.md](../features/FEATURES.md) | Screen Plans in screens/*/
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

## Anatomy of the Benefit Implementation

We've fully implemented the Benefit tab as a reference. Here's how it works:

### **1. The Provider** (`lib/providers/benefit_provider.dart`)

**Purpose**: Manages ALL state for the Benefit screen

**Key Parts**:
```dart
class BenefitProvider extends ChangeNotifier {
  // State variables (private)
  bool _isLoading = false;
  List<Benefit> _benefits = [];

  // Getters (public - UI reads these)
  bool get isLoading => _isLoading;
  List<Benefit> get benefits => _benefits;

  // Methods (public - UI calls these)
  Future<void> fetchBenefits() async {
    _isLoading = true;
    notifyListeners(); // ← MAGIC! Tells UI to rebuild

    _benefits = await repository.getBenefits();
    _isLoading = false;
    notifyListeners(); // ← UI rebuilds again with new data
  }
}
```

**Important Concepts**:
- **Private variables** (`_isLoading`) = internal state
- **Getters** (`get isLoading`) = how UI reads state
- **Methods** (`fetchBenefits()`) = how UI changes state
- **`notifyListeners()`** = tells Flutter to rebuild widgets

### **2. The Screen** (`lib/presentation/screens/benefit/benefit_screen.dart`)

**Purpose**: Orchestrates the UI using the Provider

**Key Parts**:
```dart
class BenefitScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    // Fetch data when screen loads
    context.read<BenefitProvider>().fetchBenefits();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BenefitProvider>(
      builder: (context, provider, child) {
        // UI automatically rebuilds when provider changes
        if (provider.isLoading) return LoadingWidget();
        if (provider.hasError) return ErrorWidget();
        return BenefitList(benefits: provider.benefits);
      },
    );
  }
}
```

**Important Concepts**:
- **`Consumer<T>`** = Listens to provider, rebuilds when state changes
- **`context.read<T>()`** = Access provider to call methods (doesn't rebuild)
- **`provider.xxx`** = Read state from provider

### **3. Widgets** (`lib/presentation/screens/benefit/widgets/`)

**Purpose**: Reusable UI components

**Examples**:
- `TotalSavingsCard` - Shows total savings
- `BenefitCard` - Shows individual benefit
- `BenefitList` - List of all benefits

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

---

## Step-by-Step: Create Your Own Provider

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
  bool _isLoading = false;
  String? _error;
  List<Session> _sessions = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Session> get sessions => _sessions;
  bool get hasError => _error != null;
  bool get isEmpty => !_isLoading && _sessions.isEmpty;

  // Methods
  Future<void> fetchSessions(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await _repository.getAllSessions(userId: userId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load sessions: ${e.toString()}';
      _sessions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String userId) => fetchSessions(userId);
}
```

#### **Step 2: Register Provider in main.dart**

Add to providers list:
```dart
ChangeNotifierProvider(
  create: (_) => ProgressProvider(
    RepositoryConfig.getSessionRepository(),
  ),
),
```

#### **Step 3: Update ProgressScreen**

```dart
class ProgressScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressProvider>().fetchSessions('test-user-123');
    });
  }

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
              onRetry: () => provider.fetchSessions('test-user-123'),
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
            onRefresh: () => provider.refresh('test-user-123'),
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
// Loading → Error/Success pattern
if (_isLoading) return LoadingWidget();
if (_error != null) return ErrorWidget();
return SuccessWidget();
```

---

## Team Assignments

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
**Solution**: Use `const` widgets, check if you're calling `notifyListeners()` too often

---

## Questions?

**Study the Benefit implementation** - it's a complete, working example of everything you need!

**Key files to review**:
1. `lib/providers/benefit_provider.dart` - The provider
2. `lib/presentation/screens/benefit/benefit_screen.dart` - The screen
3. `lib/main.dart` - Provider registration

Good luck! 🚀
