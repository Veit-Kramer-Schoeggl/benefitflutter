---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [Activity Screen Overview](../../../../documentation/screens/ACTIVITY_SCREEN_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../../database/DATABASE.md) | [PROVIDER_GUIDE.md](../../PROVIDER_GUIDE.md) | [Session Feature](../../../features/session/)
---

# Activity Screen Implementation Plan

## Overview: Real-time Tracking with Timer

The Activity Screen is **the most complex screen** because it works with **real-time data**:
- ⏱️ **Timer** (updates every second)
- ▶️ **Start/Stop/Pause** buttons
- 📍 **GPS tracking** (optional, when available)
- 💾 **Session saving** on stop

---

## Architecture: Timer + GPS Provider

```
┌─────────────────────────────────────────────────────────────────┐
│              Activity Screen - Real-time Architecture           │
│                                                                 │
│  ┌──────────────┐                    ┌──────────────┐           │
│  │   SCREEN     │                    │   PROVIDER   │           │
│  │              │                    │              │           │
│  │ - Start Btn  │─── startSession() ─►│ _isTracking │           │
│  │ - Stop Btn   │─── stopSession() ──►│ _timer      │           │
│  │ - Pause Btn  │─── pauseSession() ─►│ _duration   │           │
│  │ - Timer      │                    │ _distance   │           │
│  │ - Distance   │                    │              │           │
│  └──────────────┘                    │ GPS Service  │           │
│         │                             └──────────────┘          │
│         │                                    │                   │
│    Consumer<T>()                      notifyListeners()         │
│    (every second!)                    (Timer Tick)              │
│         │                                    │                   │
│         ▼                                    ▼                   │
│  ┌──────────────┐                    ┌──────────────┐           │
│  │ Timer Widget │                    │  Repository  │           │
│  │ Distance     │◄───────────────────│ saveSession()│           │
│  │ Start/Stop   │                    │              │           │
│  └──────────────┘                    └──────────────┘           │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components Explained

### 1️⃣ **ActivityProvider** (Core Component)

**What's different from other providers?**
- **Timer** runs continuously (calls `notifyListeners()` every second)
- **GPS Stream** listens for position changes
- **State Management** for 3 states: Idle → Tracking → Paused

**File**: `lib/providers/activity_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

enum TrackingState { idle, tracking, paused }

class ActivityProvider extends ChangeNotifier {
  final SessionRepository _repository;
  ActivityProvider(this._repository);

  // ===== STATE =====
  TrackingState _state = TrackingState.idle;
  ActivityType _selectedActivity = ActivityType.walking;

  // Timer
  Timer? _timer;
  int _elapsedSeconds = 0;
  DateTime? _startTime;
  DateTime? _pauseTime;

  // GPS (later)
  double _distance = 0.0; // in meters

  // Session
  String? _currentSessionId;

  // ===== GETTERS =====
  TrackingState get state => _state;
  ActivityType get selectedActivity => _selectedActivity;
  int get elapsedSeconds => _elapsedSeconds;
  double get distance => _distance;
  bool get isTracking => _state == TrackingState.tracking;
  bool get isPaused => _state == TrackingState.paused;
  bool get isIdle => _state == TrackingState.idle;

  /// Formatted time (HH:MM:SS)
  String get formattedTime {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatted distance
  String get formattedDistance {
    if (_distance < 1000) {
      return '${_distance.toStringAsFixed(0)} m';
    }
    return '${(_distance / 1000).toStringAsFixed(2)} km';
  }

  // ===== METHODS =====

  /// Select activity type (before start)
  void selectActivity(ActivityType type) {
    if (_state == TrackingState.idle) {
      _selectedActivity = type;
      notifyListeners();
    }
  }

  /// Start session
  Future<void> startSession(String userId) async {
    if (_state != TrackingState.idle) return;

    _state = TrackingState.tracking;
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _distance = 0.0;

    // Create session in DB
    final session = Session(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      trackingMode: TrackingMode.manual,
      activityType: _selectedActivity,
      status: SessionStatus.active,
      startTime: _startTime!,
    );

    await _repository.createSession(session);
    _currentSessionId = session.id;

    // ⭐ Start timer (ticks every second)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners(); // 🔔 UI updates every second!
    });

    // TODO: Start GPS tracking
    // await _startGpsTracking();

    notifyListeners();
  }

  /// Pause session
  void pauseSession() {
    if (_state != TrackingState.tracking) return;

    _state = TrackingState.paused;
    _pauseTime = DateTime.now();
    _timer?.cancel();

    // TODO: Pause GPS tracking

    notifyListeners();
  }

  /// Resume session
  void resumeSession() {
    if (_state != TrackingState.paused) return;

    _state = TrackingState.tracking;

    // Restart timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });

    // TODO: Resume GPS tracking

    notifyListeners();
  }

  /// Stop and save session
  Future<void> stopSession() async {
    if (_state == TrackingState.idle) return;

    _timer?.cancel();
    _state = TrackingState.idle;

    // TODO: Stop GPS tracking

    // Update session in DB
    if (_currentSessionId != null) {
      final session = await _repository.getSessionById(_currentSessionId!);
      final updatedSession = session.copyWith(
        status: SessionStatus.completed,
        endTime: DateTime.now(),
        durationSeconds: _elapsedSeconds,
        distanceMeters: _distance,
      );

      await _repository.updateSession(updatedSession);
    }

    // Reset state
    _elapsedSeconds = 0;
    _distance = 0.0;
    _startTime = null;
    _currentSessionId = null;

    notifyListeners();
  }

  /// Clean up provider
  @override
  void dispose() {
    _timer?.cancel();
    // TODO: Cancel GPS stream
    super.dispose();
  }

  // ===== GPS METHODS (TODO) =====

  // Future<void> _startGpsTracking() async {
  //   // LocationService implementation
  //   // Stream listens for GPS updates
  //   // Calculates distance between points
  // }
}
```

**Key Concepts:**

**1. Timer.periodic()**
```dart
Timer.periodic(Duration(seconds: 1), (timer) {
  _elapsedSeconds++;
  notifyListeners(); // ⭐ UI update every second!
});
```
→ Runs continuously, must be cancelled in `dispose()`!

**2. TrackingState Enum**
```dart
enum TrackingState { idle, tracking, paused }
```
→ Clearer state management than multiple booleans

> **Status update:** `TrackingState` now lives in its own file
> `lib/core/enums/tracking_state.dart` (with a `displayName` getter:
> Ready/Tracking/Paused), not declared inside `activity_provider.dart` as shown
> in the sketch above. It is intentionally separate from the DB-persisted
> `SessionStatus` enum (`lib/core/enums/session_status.dart`).

**3. Create Session During Tracking**
```dart
// Start: Create session
await _repository.createSession(session);

// Stop: Update session
await _repository.updateSession(updatedSession);
```
→ Session exists in DB from start (even on app crash)

---

### 2️⃣ **ActivityScreen** (UI with Real-time Updates)

**File**: `lib/presentation/screens/activity/activity_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/activity_provider.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const String _userId = 'test-user-123';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
      ),
      body: Consumer<ActivityProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // ⭐ Activity selection (only when Idle)
              if (provider.isIdle) _buildActivitySelector(provider),

              const Spacer(),

              // ⭐ Timer display (large text)
              Text(
                provider.formattedTime,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
              ),

              const SizedBox(height: 16),

              // ⭐ Distance (when tracking)
              if (!provider.isIdle)
                Text(
                  provider.formattedDistance,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),

              const Spacer(),

              // ⭐ Control Buttons
              _buildControlButtons(context, provider),

              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  /// Activity selection (Walking, Running, Cycling)
  Widget _buildActivitySelector(ActivityProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _activityButton(
            context,
            provider,
            ActivityType.walking,
            Icons.directions_walk,
            'Walking',
          ),
          _activityButton(
            context,
            provider,
            ActivityType.running,
            Icons.directions_run,
            'Running',
          ),
          _activityButton(
            context,
            provider,
            ActivityType.cycling,
            Icons.directions_bike,
            'Cycling',
          ),
        ],
      ),
    );
  }

  Widget _activityButton(
    BuildContext context,
    ActivityProvider provider,
    ActivityType type,
    IconData icon,
    String label,
  ) {
    final isSelected = provider.selectedActivity == type;
    return Column(
      children: [
        IconButton(
          onPressed: () => provider.selectActivity(type),
          icon: Icon(icon, size: 48),
          style: IconButton.styleFrom(
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.grey[200],
            foregroundColor: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Control Buttons (Start/Pause/Stop)
  Widget _buildControlButtons(BuildContext context, ActivityProvider provider) {
    if (provider.isIdle) {
      // Start Button
      return FloatingActionButton.large(
        onPressed: () => provider.startSession(_userId),
        child: const Icon(Icons.play_arrow, size: 48),
      );
    }

    if (provider.isTracking) {
      // Pause + Stop Buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: 'pause',
            onPressed: () => provider.pauseSession(),
            child: const Icon(Icons.pause),
          ),
          const SizedBox(width: 24),
          FloatingActionButton(
            heroTag: 'stop',
            onPressed: () async {
              await provider.stopSession();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session saved!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.stop),
          ),
        ],
      );
    }

    // isPaused: Resume + Stop Buttons
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton(
          heroTag: 'resume',
          onPressed: () => provider.resumeSession(),
          child: const Icon(Icons.play_arrow),
        ),
        const SizedBox(width: 24),
        FloatingActionButton(
          heroTag: 'stop',
          onPressed: () async {
            await provider.stopSession();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Session saved!')),
              );
            }
          },
          backgroundColor: Colors.red,
          child: const Icon(Icons.stop),
        ),
      ],
    );
  }
}
```

**Important UI Concepts:**

**1. TabularFigures for Timer**
```dart
fontFeatures: [const FontFeature.tabularFigures()]
```
→ Numbers have equal width (no "wobbling" on update)

**2. Conditional Buttons Based on State**
```dart
if (provider.isIdle) return StartButton();
if (provider.isTracking) return PauseAndStopButtons();
if (provider.isPaused) return ResumeAndStopButtons();
```

**3. heroTag for Multiple FABs**
```dart
FloatingActionButton(heroTag: 'pause', ...)
FloatingActionButton(heroTag: 'stop', ...)
```
→ Each FAB needs a unique tag!

---

## GPS Tracking (✅ IMPLEMENTED)

> **Status update:** GPS tracking is now implemented. The actual implementation does
> **not** use a standalone `LocationService`; instead `ActivityProvider` drives a
> `SensorManager` (`lib/features/shared/sensors/sensor_manager.dart`) wrapping a
> `GpsSensor` (`lib/features/shared/sensors/gps_sensor.dart`), persists points via
> `GpsPointDao`, and computes distance with `DistanceCalculator`
> (`lib/features/session/utils/distance_calculator.dart`). GPS points are
> **batch-inserted**: qualifying points are buffered and flushed via
> `GpsPointDao.insertBatch` (batch size 10; also flushed on pause/stop/app-background)
> instead of one insert per point. Distance/UI read the in-memory point list, not the
> DB, so batching doesn't affect them. The `LocationService`
> sketch below is kept for historical/design context only — the file
> `lib/services/location/location_service.dart` does not exist (`lib/services/`
> does not exist at all).

### Create Location Service (original design sketch — superseded)

**Dependencies:**
```yaml
dependencies:
  geolocator: ^10.1.0
  permission_handler: ^11.0.1
```

**File**: `lib/services/location/location_service.dart`

```dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  Stream<Position>? _positionStream;

  /// Start GPS stream
  Stream<Position> startTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
    return _positionStream!;
  }

  /// Calculate distance between two points (Haversine formula)
  double calculateDistance(Position start, Position end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Check permissions
  Future<bool> hasPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
           permission == LocationPermission.always;
  }
}
```

### Integrate in Provider:

```dart
class ActivityProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  Future<void> _startGpsTracking() async {
    if (!await _locationService.hasPermission()) {
      return; // No permission
    }

    _positionSubscription = _locationService.startTracking().listen((position) {
      if (_lastPosition != null) {
        // Add distance to last position
        final distanceDelta = _locationService.calculateDistance(
          _lastPosition!,
          position,
        );
        _distance += distanceDelta;
        notifyListeners();
      }
      _lastPosition = position;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel(); // ⭐ Stop GPS stream
    super.dispose();
  }
}
```

---

## Register Provider

**File**: `lib/main.dart`

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => BenefitProvider(RepositoryConfig.getBenefitRepository()),
    ),
    ChangeNotifierProvider(
      create: (_) => ProgressProvider(RepositoryConfig.getSessionRepository()),
    ),
    ChangeNotifierProvider( // NEW
      create: (_) => ActivityProvider(RepositoryConfig.getSessionRepository()),
    ),
  ],
  child: const BeneFitApp(),
)
```

> **Status update:** In the current `lib/main.dart`, `ActivityProvider` is
> registered as a `ChangeNotifierProxyProvider<AuthProvider, ActivityProvider>`
> (so it receives the user id via `updateUserId(...)`), and is constructed with a
> `SensorManager` for GPS:
> ```dart
> ChangeNotifierProxyProvider<AuthProvider, ActivityProvider>(
>   create: (_) => ActivityProvider(
>     RepositoryConfig.getSessionRepository(),
>     sensorManager: sensorManager,
>   ),
>   update: (_, userProvider, activityProvider) =>
>       activityProvider!..updateUserId(userProvider.userId),
> )
> ```
> The other providers shown above (Benefit/Progress) are likewise
> `ChangeNotifierProxyProvider<AuthProvider, ...>` today, not plain
> `ChangeNotifierProvider`.

---

## Summary: Activity vs Other Screens

| Aspect | Activity Screen | Progress/Profile |
|--------|----------------|------------------|
| **Updates** | Every second (Timer) | On data load |
| **State** | 3 states (Idle/Tracking/Paused) | Loading/Success/Error |
| **Real-time** | Timer + GPS Stream | One-time |
| **Dispose** | Cancel Timer/Stream | Nothing |
| **Complexity** | High | Medium |

**Key Difference:** Activity Provider **runs continuously** while other providers only work on user actions!

---

## Checklist

> **Status update:** All three phases below are implemented in the current code.

### Phase 1: Timer Functionality
- [x] Create `lib/providers/activity_provider.dart`
- [x] Implement timer (start/pause/resume/stop)
- [x] Register provider in `main.dart`
- [x] `activity_screen.dart` with Consumer
- [x] UI: Timer display + Start/Stop buttons
- [x] Test: Timer runs, pauses, stops

### Phase 2: Session Storage
- [x] Create session on start
- [x] Update session on stop
- [x] Display session in Progress screen
- [x] Test: Session appears after stop

### Phase 3: GPS Tracking (Optional)
- [x] GPS via `SensorManager` / `GpsSensor` (no standalone `LocationService`)
- [x] Handle permissions
- [x] Integrate GPS stream in provider
- [x] Distance calculation (`DistanceCalculator`)
- [x] Test: Distance is tracked

---

## Common Errors

### ❌ Timer Doesn't Continue After Dispose
**Problem**: Timer stops on tab switch

**Solution**: Provider is global (in `main.dart`), timer continues! ✅

---

### ❌ "Multiple FloatingActionButtons"
**Problem**: Multiple FABs without heroTag

**Solution**:
```dart
FloatingActionButton(heroTag: 'unique-id', ...)
```

---

### ❌ Memory Leak
**Problem**: Timer/Stream not cancelled

**Solution**: In `dispose()`:
```dart
@override
void dispose() {
  _timer?.cancel();
  _positionSubscription?.cancel();
  super.dispose();
}
```

---

## References

- Progress Screen Plan: `lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md`
- Profile Screen Plan: `lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md`
- Provider Guide: `lib/presentation/PROVIDER_GUIDE.md`
