---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [Activity Screen Overview](../../../../documentation/screens/ACTIVITY_SCREEN_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../../database/DATABASE.md) | [PROVIDER_GUIDE.md](../../PROVIDER_GUIDE.md) | [Session Feature](../../../features/session/)
>
> **Last updated:** 2026-08-28 · branch `feat/phase-2-background-tracking` (background-tracking WP1–WP5 done, WP6 on-device smoke still open)
---

# Activity Screen Implementation Plan

## Files in this folder

| File | Status |
|------|--------|
| `activity_screen.dart` | **Live.** The tracking screen, routed at `/home/activity`. |
| `session_summary_screen.dart` | **Dead code — not routed, not referenced.** A 603-line stats/HR-zones summary built for a `Session`; `grep` finds only its own declaration and no `GoRoute` builds it (`lib/core/router/app_router.dart`). Either wire it up or delete it. |

The screen actually shown after a session is **`SessionDetailScreen`** (`lib/presentation/screens/session/session_detail_screen.dart`, route `/session/:id`), reached from the Progress screen; it draws the stored GPS points as a `flutter_map` polyline.

---

## Overview: Real-time Tracking with Timer

The Activity Screen is **the most complex screen** because it works with **real-time data**:
- ⏱️ **Timer** (repaints every second; the elapsed value itself is derived from timestamps)
- ▶️ **One multi-purpose button** (tap = start/pause/resume, long-press while paused = stop)
- 📍 **GPS tracking** via `SensorManager` / `GpsSensor` — non-fatal when unavailable: the session still runs, only distance/route are missing
- 📲 **Background recording** on Android through geolocator's foreground service (WP2/WP3)
- 💾 **Session saving** on stop (session + heart-rate summary in one transaction)

---

## Architecture: Timer + GPS Provider

```
┌─────────────────────────────────────────────────────────────────┐
│              Activity Screen - Real-time Architecture           │
│                                                                 │
│  ┌──────────────┐                    ┌──────────────────────┐   │
│  │    SCREEN    │                    │       PROVIDER       │   │
│  │              │                    │                      │   │
│  │ - One button │─── startSession() ►│ _trackingState       │   │
│  │   tap / LP   │─── pauseSession() ►│ _timer (repaint)     │   │
│  │ - Timer      │──── stopSession() ►│ _accumulatedActive   │   │
│  │ - Distance   │                    │ _segmentStart        │   │
│  │ - HR pill    │                    │ _currentDistance     │   │
│  └──────────────┘                    │ SensorManager (GPS)  │   │
│         ▲                            └──────────────────────┘   │
│         │                                       │               │
│   Consumer<T>()                        notifyListeners()        │
│   (1 Hz repaint)                        (timer tick + GPS)      │
│         │                                       ▼               │
│         │                            ┌──────────────────────┐   │
│         └────────────────────────────│ SessionRepository    │   │
│                                      │ GpsPointDao (batch)  │   │
│                                      └──────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components Explained

### 1️⃣ **ActivityProvider** (Core Component)

**What's different from other providers?**
- **Timer** runs continuously — but it only calls `notifyListeners()`; the elapsed value is derived from timestamps
- **GPS Stream** listens for position changes
- **State Management** for 3 states: Idle → Tracking → Paused

**File**: `lib/providers/activity_provider.dart`

```dart
// Abridged from lib/providers/activity_provider.dart (1045 lines).
// Names, signatures and semantics match the shipped code; logging, the
// heart-rate helpers and the continuous-session helpers are elided.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:benefitflutter/core/enums/tracking_state.dart'; // own file!
// ... activity_type / tracking_mode / session_status, SensorManager,
// GpsPointDao, DistanceCalculator, GpsTrackingConfig, BleDataSource ...

class ActivityProvider extends ChangeNotifier {
  final SessionRepository _sessionRepository;
  final SensorManager _sensorManager;
  final GpsPointDao _gpsPointDao;
  final BleDataSource _bleDataSource;
  final SessionBiometricDataDao _biometricDao;

  ActivityProvider(
    this._sessionRepository, {
    String? userId,
    SensorManager? sensorManager,
    GpsPointDao? gpsPointDao,
    BleDataSource? bleDataSource,
    SessionBiometricDataDao? biometricDao,
    DateTime Function()? now, // injectable clock seam for deterministic tests
  })  : _userId = userId,
        _now = now ?? DateTime.now,
        _sensorManager = sensorManager ?? SensorManager(),
        _gpsPointDao = gpsPointDao ?? GpsPointDao(),
        _bleDataSource = bleDataSource ?? BleDataSource(),
        _biometricDao = biometricDao ?? SessionBiometricDataDao();

  // ===== STATE =====
  TrackingState _trackingState = TrackingState.idle;
  ActivityType _selectedActivityType = ActivityType.running;
  Session? _currentSession;    // the live row, not just its id
  String? _userId;             // set by AuthProvider via ProxyProvider
  bool _wasContinuousActive = false;
  bool _isLoading = false;
  String? _error;

  // Duration: DERIVED from timestamps, never counted by the ticker
  Timer? _timer;
  Duration _accumulatedActive = Duration.zero; // completed tracking segments
  DateTime? _segmentStart;                     // UTC start of the open segment
  final DateTime Function() _now;

  // GPS
  StreamSubscription<GpsPoint>? _gpsSubscription;
  double _currentDistance = 0.0;
  final List<GpsPoint> _sessionGpsPoints = []; // in-memory: distance + UI
  final List<GpsPoint> _pendingGpsPoints = []; // buffered for the next DB batch
  static const int _gpsBatchSize = 5;
  static const Duration _maxBufferAge = Duration(seconds: 60);
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
  String? _gpsStartWarning;    // non-fatal GPS notice — never becomes _error

  // Heart rate
  String? _heartRateDeviceId;
  StreamSubscription<SensorDataPoint>? _heartRateSubscription;
  final List<int> _sessionHeartRates = [];

  // ===== GETTERS =====
  TrackingState get trackingState => _trackingState;
  double get currentDistance => _currentDistance;
  String? get gpsStartWarning => _gpsStartWarning;
  bool get gpsNeedsSettings =>
      _sensorManager.gpsSensor.status == SensorStatus.permanentlyDenied;

  /// Recomputed on every read, so a background-throttled UI timer never causes
  /// drift and paused time is excluded.
  int get _elapsedSeconds {
    var total = _accumulatedActive;
    final start = _segmentStart;
    if (start != null) total += _now().toUtc().difference(start);
    return total.inSeconds;
  }

  // ===== METHODS =====

  /// No userId parameter — the id arrives via updateUserId() from the
  /// AuthProvider ProxyProvider.
  Future<void> startSession({String? heartRateDeviceId}) async {
    if (_trackingState != TrackingState.idle) return;   // guard: idle only
    if (_userId == null) {                              // guard: logged in
      _error = 'Please log in to start tracking';
      notifyListeners();
      return;
    }

    _heartRateDeviceId = heartRateDeviceId;
    _isLoading = true;
    _error = null;
    _gpsStartWarning = null;
    notifyListeners();

    try {
      await _endActiveContinuousSessions(); // completes any active daily session

      final now = DateTime.now();
      final session = Session(
        id: const Uuid().v4(),
        userId: _userId!,
        trackingMode: TrackingMode.manual,
        activityType: _selectedActivityType,
        status: SessionStatus.active,
        startTime: now,
        trackingDate: now,
        createdAt: now,
      );
      _currentSession = await _sessionRepository.createSession(session);

      _accumulatedActive = Duration.zero;
      _segmentStart = _now().toUtc();  // open the first active segment
      _lastFlush = _now();
      _trackingState = TrackingState.tracking;

      _startTimer();
      await _startGpsTracking();       // sets _gpsStartWarning if GPS won't start
      if (_heartRateDeviceId != null) await _startHeartRateTracking();
    } catch (e) {
      _error = 'Failed to start session: $e';
      _trackingState = TrackingState.idle;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pauseSession() async {
    if (_trackingState != TrackingState.tracking || _currentSession == null) {
      return;
    }
    _stopTimer();
    _finalizeSegment();        // paused time does not count
    await _flushGpsBuffer();   // persist buffered points while paused
    // ... rewrite the session row with status paused ...
    _trackingState = TrackingState.paused;
    notifyListeners();         // NB: the GPS stream keeps running while paused
  }

  Future<void> resumeSession() async {
    if (_trackingState != TrackingState.paused || _currentSession == null) {
      return;
    }
    // ... rewrite the session row back to status active ...
    _trackingState = TrackingState.tracking;
    _segmentStart = _now().toUtc();  // open a new active segment
    _startTimer();
    notifyListeners();
  }

  Future<void> stopSession() async {
    if (_currentSession == null || _trackingState == TrackingState.idle) return;

    _isLoading = true;
    notifyListeners();
    try {
      _stopTimer();
      _finalizeSegment();
      await _stopGpsTracking();      // flushes the buffer, then stops the sensor
      await _stopHeartRateTracking();

      final hrStats = _calculateHeartRateStats();
      final completedSession = Session(
        id: _currentSession!.id,
        userId: _currentSession!.userId,
        trackingMode: _currentSession!.trackingMode,
        activityType: _currentSession!.activityType,
        status: SessionStatus.completed,
        startTime: _currentSession!.startTime,
        endTime: DateTime.now(),
        durationSeconds: _elapsedSeconds,
        distanceMeters: _currentDistance,
        trackingDate: _currentSession!.trackingDate,
        createdAt: _currentSession!.createdAt,
        avgHeartRate: hrStats['avgHeartRate'],
        maxHeartRate: hrStats['maxHeartRate'],
        minHeartRate: hrStats['minHeartRate'],
        hasWearableData: _sessionHeartRates.isNotEmpty,
        connectedDeviceIds:
            _heartRateDeviceId != null ? [_heartRateDeviceId!] : null,
      );

      // ⭐ One transaction: session + HR summary; sync runs after the commit.
      final summary = _sessionHeartRates.isNotEmpty
          ? _buildSessionSummary(completedSession)
          : null;
      await _sessionRepository.finalizeSession(completedSession,
          summary: summary);

      if (_wasContinuousActive) await _startContinuousSession();
      // ... reset every tracking field back to idle ...
    } catch (e) {
      _error = 'Failed to stop session: $e';
      // State is deliberately kept on failure — no false "stopped".
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Only allowed while idle.
  void selectActivityType(ActivityType type) {
    if (_trackingState != TrackingState.idle) return;
    _selectedActivityType = type;
    notifyListeners();
  }

  // ===== TIMER =====

  /// ⭐ The tick ONLY repaints — it does not count seconds.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Close the running segment into _accumulatedActive (on pause and stop).
  void _finalizeSegment() {
    final start = _segmentStart;
    if (start != null) {
      _accumulatedActive += _now().toUtc().difference(start);
      _segmentStart = null;
    }
  }

  // ===== GPS =====

  Future<void> _startGpsTracking() async {
    if (_currentSession == null) return;
    final results = await _sensorManager.startSession(
      sessionId: _currentSession!.id,
      activityType: _selectedActivityType,
      mode: _currentSession!.trackingMode,
    );
    if (results['gps'] == true) {
      _gpsSubscription = _sensorManager.gpsSensor.onDataStream.listen(
        _onGpsPoint,
        onError: (error) {/* logged, stream stays alive */},
      );
    } else {
      // Non-fatal: the session keeps running without distance/route.
      _gpsStartWarning = _gpsWarningForStatus(_sensorManager.gpsSensor.status);
      notifyListeners();
    }
  }

  /// Called from the app-lifecycle observer on resume (lib/main.dart).
  Future<void> retryGpsIfNeeded() async {
    if (!isTracking || _gpsSubscription != null || _gpsStartWarning == null) {
      return;
    }
    await _startGpsTracking();
    if (_gpsSubscription != null) {
      _gpsStartWarning = null;
      notifyListeners();
    }
  }

  Future<void> _onGpsPoint(GpsPoint point) async {
    if (_currentSession == null) return;       // note: also fires while paused
    if (!_shouldStoreGpsPoint(point)) return;  // >= 5 s OR >= 10 m (manual mode)

    _sessionGpsPoints.add(point);
    _pendingGpsPoints.add(point);
    if (_pendingGpsPoints.length >= _gpsBatchSize ||
        _now().difference(_lastFlush) >= _maxBufferAge) {
      await _flushGpsBuffer();                 // GpsPointDao.insertBatch
    }

    _currentDistance =
        DistanceCalculator.calculateTotalDistance(_sessionGpsPoints);
    // ... rewrite the session row with the new distance ...
    notifyListeners();
  }

  /// Race-safe (buffer swapped out before the await) and error-safe (a failed
  /// batch is re-queued for the next flush).
  Future<void> _flushGpsBuffer() async {
    if (_pendingGpsPoints.isEmpty) return;
    _lastFlush = _now();
    final batch = List<GpsPoint>.of(_pendingGpsPoints);
    _pendingGpsPoints.clear();
    try {
      await _gpsPointDao.insertBatch(batch);
    } catch (e) {
      _pendingGpsPoints.insertAll(0, batch);
    }
  }

  /// Called when the app goes to background (lib/main.dart).
  Future<void> flushPendingGps() => _flushGpsBuffer();

  @override
  void dispose() {
    _stopTimer();
    _gpsSubscription?.cancel();
    _heartRateSubscription?.cancel();
    _sensorManager.dispose();
    _bleDataSource.dispose();
    super.dispose();
  }
}
```

> **Status update (2026-08-28):** the sample above is an abridged extract of the
> **shipped** provider. Earlier revisions of this plan sketched a different API;
> the five differences that matter, in case you remember the old sketch:
>
> 1. **Constructor.** `ActivityProvider(SessionRepository, {String? userId,
>    SensorManager?, GpsPointDao?, BleDataSource?, SessionBiometricDataDao?,
>    DateTime Function()? now})`. The user id arrives via `updateUserId()` from
>    the `ChangeNotifierProxyProvider<AuthProvider, ActivityProvider>` in
>    `lib/main.dart`; `now` is an injectable clock seam for tests.
> 2. **`startSession()` takes no userId** — `Future<void> startSession({String?
>    heartRateDeviceId})`. `pauseSession` / `resumeSession` / `stopSession` are
>    all `async` too, and the session id is a `const Uuid().v4()`.
> 3. **Elapsed time is not counted by the ticker.** The 1 s `Timer.periodic`
>    only calls `notifyListeners()`; the value is derived on every read from
>    `_accumulatedActive` plus the wall-clock delta since `_segmentStart`, so a
>    background-throttled timer cannot cause drift and paused time is excluded
>    (`_finalizeSegment()` on pause and stop). — WP4, commit `457c253`.
> 4. **`stopSession()` does not read-modify-write** via `getSessionById` +
>    `copyWith`. It rebuilds the `Session`, computes avg/max/min heart rate and
>    persists session + `SessionSensorSummary` atomically through
>    `SessionRepository.finalizeSession(completed, summary: summary)`, then
>    restarts a continuous session if one was active.
> 5. **Naming**: the activity setter is `selectActivityType(ActivityType)`, the
>    state getter is `trackingState`, the fields are `_currentSession` /
>    `_currentDistance`.

**Key Concepts:**

**1. Timer.periodic() — repaint only, duration is derived**
```dart
// The tick does NOT increment a counter:
_timer = Timer.periodic(const Duration(seconds: 1), (timer) {
  notifyListeners(); // ⭐ repaint once per second
});

// The value shown comes from timestamps instead:
int get _elapsedSeconds {
  var total = _accumulatedActive;              // completed segments
  final start = _segmentStart;                 // null while paused/idle
  if (start != null) total += _now().toUtc().difference(start);
  return total.inSeconds;
}
```
→ Runs continuously, must be cancelled in `dispose()` — and because the value is
derived, a throttled background timer cannot make the clock drift.

**2. TrackingState Enum**
```dart
enum TrackingState { idle, tracking, paused }
```
→ Clearer state management than multiple booleans

> **Status update:** `TrackingState` lives in its own file
> `lib/core/enums/tracking_state.dart` (with a `displayName` getter:
> Ready/Tracking/Paused); it is *not* declared inside `activity_provider.dart`,
> as an earlier revision of this plan sketched. It is intentionally separate from
> the DB-persisted `SessionStatus` enum (`lib/core/enums/session_status.dart`).

**3. Create Session During Tracking**
```dart
// Start: create the row immediately (status active)
_currentSession = await _sessionRepository.createSession(session);

// Stop: one transaction for the completed session + its HR summary
await _sessionRepository.finalizeSession(completedSession, summary: summary);
```
→ The session exists in the DB from the first second (even on an app crash), and
the completion write is atomic — sync only runs after the commit.

---

### 2️⃣ **ActivityScreen** (UI with Real-time Updates)

**File**: `lib/presentation/screens/activity/activity_screen.dart` (590 lines)

The shipped screen is a branded tracking view, not a generic timer demo, so this
section describes the real widget tree instead of sketching one.

**Chrome.** `AppBar` with the centred bold title **"Activity"** on the brand green
`0xFF71B33A`. Its only action is a `Consumer<ConnectivityProvider>` signal icon
(`signal_cellular_alt` in white when online, `signal_cellular_connected_no_internet_0_bar`
in red when offline).

**Body.** A `Stack`, back to front:

1. `Image.asset('assets/images/backgrounds/activity/activity_map.png')` filling the screen
2. a `BackdropFilter` blur (σ 6) over a 25 % black scrim
3. an optional 30 % black loading overlay with a white `CircularProgressIndicator`, shown while `provider.isLoading`
4. the foreground `Column`: a scrollable area — `HeartRateDisplayCompact` pill → glowing "`<x.x>` KM" pill → "New running session!" pill → **optional orange GPS-warning banner** → the white card (map preview, slogan, button, status text, timer) — above a fixed green **"EARNED SO FAR"** bar bound to `BenefitProvider.totalSavings`

**There is no activity picker.** `initState` forces running on the first frame and
the copy is hard-coded to "START Running" / "New running session!":

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  final provider = context.read<ActivityProvider>();
  if (provider.selectedActivityType != ActivityType.running) {
    provider.selectActivityType(ActivityType.running);
  }
});
```

`ActivityType` has 12 values, but only `running` (manual sessions) and `walking`
(auto-created continuous sessions) are ever used.

**There are no FloatingActionButtons.** A single full-width `InkWell` +
`AnimatedContainer` (180 ms colour transition) carries every action:

```dart
InkWell(
  onTap: isLoading ? null : () => _handleTap(context, state),
  onLongPress: isLoading ? null : () => _handleLongPress(context, state),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: double.infinity,
    decoration: BoxDecoration(color: buttonColor, ...),
    child: Center(child: Text(buttonText, ...)),
  ),
)
```

| `TrackingState` | `_getButtonText` | `_getButtonColor` | Tap | Long-press |
|-----------------|------------------|-------------------|-----|------------|
| `idle` | "START Running" | `0xFF71B33A` green | `startSession()` | SnackBar "Long press only works while paused" |
| `tracking` | "Pause" | `0xFFB00020` red | `pauseSession()` | same SnackBar |
| `paused` | "Continue / Stop" | `0xFF444444` grey | `resumeSession()` | `stopSession()` + green "Session saved!" SnackBar |

Stopping while actively tracking is therefore impossible — the user must pause first.
`_getStatusText` fills the line under the button: "Ready to start recording" /
"Recording running" / "Recording paused".

**Start path.** No user id, no positional argument — the id reaches the provider
via `updateUserId()` from the `ChangeNotifierProxyProvider<AuthProvider,
ActivityProvider>` in `lib/main.dart`, and `startSession` only accepts an optional
named `heartRateDeviceId` (which this screen never passes, so the heart-rate pill
shows "--" with a tap-to-connect to `/device-connection`):

```dart
case TrackingState.idle:
  await provider.startSession();
  if (!context.mounted) return;
  _maybeShowGpsWarning(context, provider);
  break;
```

`_maybeShowGpsWarning` reads `provider.gpsStartWarning` and shows an orange
SnackBar for 6 s, adding a **Settings** `SnackBarAction` that calls
`openAppSettings()` when `provider.gpsNeedsSettings` (permission permanently
denied). The same text also renders as the persistent inline orange banner above
the card.

**Timer visibility.** `_isTimerVisible(state)` is true only for `tracking` and
`paused`; the timer is wrapped in `AnimatedOpacity` (0 → 1) plus `AnimatedScale`
(0.95 → 1.0), so in idle it is invisible.

**Error state.** `if (provider.hasError) return ErrorDisplayWidget(message:
provider.error!, onRetry: null);` replaces the **entire** body — see
[Common Errors](#common-errors) below.

**Important UI Concepts:**

**1. One button, three states**
```dart
onTap:       isLoading ? null : () => _handleTap(context, state),
onLongPress: isLoading ? null : () => _handleLongPress(context, state),
```
→ Both handlers are disabled while `provider.isLoading`, and the long-press is
rejected with a SnackBar unless the state is `paused`. No `FloatingActionButton`
is used anywhere on this screen, so the classic "multiple FABs need a `heroTag`"
problem does not arise here.

**2. Timer visibility is animated, not conditional**
```dart
AnimatedOpacity(opacity: timerVisible ? 1 : 0, ...)  // _isTimerVisible(state)
```
→ The timer stays in the layout and fades/scales in when tracking starts.

**3. TabularFigures for the timer — *not implemented***
```dart
// Current: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)
// Suggested: fontFeatures: [FontFeature.tabularFigures()]
```
→ **Status: open suggestion.** The timer has no `fontFeatures`, so the digits
shift slightly on every tick; tabular figures would give them equal width.

---

## GPS Tracking (✅ IMPLEMENTED)

> **Status update (2026-08-28):** GPS tracking is implemented. There is **no**
> standalone `LocationService` — `lib/services/` does not exist at all, and the
> superseded `LocationService` design sketch that used to sit here (with
> `geolocator: ^10.1.0` / `permission_handler: ^11.0.1` and a plain
> `const LocationSettings(...)`) has been removed: it described an API shape that
> no longer applies. The path today is:
>
> ```
> ActivityProvider._startGpsTracking()
>   → SensorManager.startSession(sessionId, activityType, mode)
>       → GpsSensor.requestPermissions()            // location
>       → GpsSensor.ensureNotificationPermission()  // Android 13+, best effort
>       → GpsSensor.startStreaming(sessionId, mode) // Geolocator position stream
>   → provider listens on SensorManager.gpsSensor.onDataStream
>   → GpsPointDao.insertBatch(...) + DistanceCalculator.calculateTotalDistance(...)
> ```
>
> See [SENSORS.md](../../../features/shared/sensors/SENSORS.md) for the sensor contract.

**Batching (WP5, commit `fd7dfc1`).** Qualifying points are buffered in
`_pendingGpsPoints` and flushed via `GpsPointDao.insertBatch` when the buffer
reaches `_gpsBatchSize = 5`, or when a point arrives more than
`_maxBufferAge = 60 s` after the last flush (checked on point arrival, because a
background timer would be throttled) — plus explicit flushes on pause, stop and
app-background (`flushPendingGps()`, called from the lifecycle observer in
`lib/main.dart`). The flush swaps the buffer out before awaiting (race-safe) and
re-queues a failed batch (error-safe). Distance and the UI read the in-memory
`_sessionGpsPoints` list, not the DB, so batching does not delay them. The only
loss window is a hard process kill that skips the lifecycle event, which can drop
at most the points buffered since the last flush.

**Thresholds** (`lib/core/config/gps_tracking_config.dart`, `GpsSensor`):

| Knob | Manual session | Continuous (daily) |
|------|----------------|--------------------|
| Store a point after | 5 s **or** 10 m | 300 s **or** 100 m |
| Stream distance filter | 5 m | 50 m |
| Quality filter (both modes) | accuracy ≤ 50 m **and** fix age ≤ 10 s | same |

**Foreground service (WP2) and permissions (WP3).**

- **Android** — `AndroidSettings(accuracy: high, distanceFilter: …,
  foregroundNotificationConfig: ForegroundNotificationConfig(
  notificationTitle: 'BeneFit', notificationText: 'Recording your activity session…',
  enableWakeLock: true, setOngoing: true))`. `SensorManager` calls
  `GpsSensor.ensureNotificationPermission()` immediately before starting the
  stream; it is best-effort (denying it only hides the notification).
- **iOS** — `AppleSettings(allowBackgroundLocationUpdates: true,
  pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true,
  activityType: fitness)`.
- **Anything else** (desktop / tests) — a plain `LocationSettings`. The branching
  lives in the `@visibleForTesting` `GpsSensor.buildLocationSettings()`.
- **Manifest / plist (WP1):** `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
  and `POST_NOTIFICATIONS` on Android (the geolocator service with
  `foregroundServiceType="location"` merges in); `UIBackgroundModes: location` on
  iOS. `ACCESS_BACKGROUND_LOCATION` is deliberately **not** requested — it is
  deferred to Phase B (continuous daily tracking).
- **Not covered:** surviving a hard process kill. A background isolate that
  resumes tracking is **planned (Phase B), not built**.
- **Open:** WP6, the on-device smoke of the background flow — see
  [DEVICE_SMOKE_CHECKLIST.md](../../../../documentation/DEVICE_SMOKE_CHECKLIST.md).

**Non-fatal failure handling.** If `SensorManager.startSession()` reports
`gps: false`, the session keeps running (timer + heart rate) and the provider sets
`_gpsStartWarning` instead of `_error`:

```dart
String _gpsWarningForStatus(SensorStatus status) {
  switch (status) {
    case SensorStatus.unavailable:
      return 'Location is turned off. Enable location to record your route.';
    case SensorStatus.permanentlyDenied:
      return 'Location permission is blocked. '
          'Enable it in Settings to record your route.';
    default:
      return 'Location permission is required to record your route.';
  }
}
```

`gpsNeedsSettings` (true for `permanentlyDenied`) drives the SnackBar's
**Settings** action, and `retryGpsIfNeeded()` re-attempts the stream once when the
app is resumed.

**Dependencies actually used** (`pubspec.yaml`): `geolocator: ^14.0.2`,
`permission_handler: ^12.0.1`.

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

> **Status update (2026-08-28):** Phases 1–3 are fully implemented. Phase 4 is the
> background-tracking work of the current branch: WP1–WP5 are in the code, WP6
> (on-device smoke) is still open.

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

### Phase 4: Background Tracking (branch `feat/phase-2-background-tracking`)
- [x] WP1: Android manifest / iOS plist entries for background location
- [x] WP2: foreground-service GPS settings in `GpsSensor.buildLocationSettings()`
- [x] WP3: permission flow (`POST_NOTIFICATIONS` + non-fatal GPS warnings)
- [x] WP4: session duration derived from timestamps
- [x] WP5: bounded GPS buffer loss (batch 5 + 60 s age flush)
- [ ] WP6: on-device smoke test — **open** ([DEVICE_SMOKE_CHECKLIST.md](../../../../documentation/DEVICE_SMOKE_CHECKLIST.md), [BACKGROUND_TRACKING_PLAN.md](../../../../documentation/sessions/BACKGROUND_TRACKING_PLAN.md))
- [ ] Phase B: background isolate so tracking survives a process kill — **not built**

---

## Common Errors

### ❌ Timer Doesn't Continue After Dispose
**Problem**: Timer stops on tab switch

**Solution**: Provider is global (in `main.dart`), timer continues! ✅

---

### ❌ A Fatal Error Hides the Whole Screen
**Problem**: when `provider.hasError` is true the body is replaced by
`ErrorDisplayWidget(message: provider.error!, onRetry: null)` — the button that
could clear the error disappears with it, and the provider has no public
`clearError()`. In practice the state only clears when the logged-in user changes.

**Status: known rough edge** (an in-screen retry/dismiss is not implemented).
Keep non-fatal problems out of `_error`: a GPS failure sets `_gpsStartWarning`
instead, precisely so the tracking UI stays on screen.

---

### ❌ Memory Leak
**Problem**: Timer/Streams not cancelled

**Solution**: the real `dispose()` tears down everything the provider owns:
```dart
@override
void dispose() {
  _stopTimer();
  _gpsSubscription?.cancel();
  _heartRateSubscription?.cancel();
  _sensorManager.dispose();
  _bleDataSource.dispose();
  super.dispose();
}
```

---

## References

- Progress Screen Plan: `lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md`
- Profile Screen Plan: `lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md`
- Provider Guide: `lib/presentation/PROVIDER_GUIDE.md`
- Sensor contract: `lib/features/shared/sensors/SENSORS.md`
- Background tracking (WP1–WP6): `documentation/sessions/BACKGROUND_TRACKING_PLAN.md`
- Device smoke checklist: `documentation/DEVICE_SMOKE_CHECKLIST.md`
