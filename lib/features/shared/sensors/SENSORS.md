---
> **Documentation Type:** TECHNICAL (Implementation Details)
>
> **Overview Version:** [SENSORS_OVERVIEW.md](../../../../documentation/guides/SENSORS_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../../database/DATABASE.md) | [WEARABLE_INTEGRATION.md](../../wearable_integration/WEARABLE_INTEGRATION.md) | [BACKGROUND_TRACKING_PLAN.md](../../../../documentation/sessions/BACKGROUND_TRACKING_PLAN.md) (DE)
>
> **Last updated:** 2026-08-28 · Branch `feat/phase-2-background-tracking` (WP1–WP5 done, WP6 device smoke open)
---

# Sensor Architecture Documentation

## Overview

The sensor system provides a modular, extensible architecture for managing various hardware sensors used in activity tracking. The design prioritizes flexibility, testability, and ease of integration, allowing new sensor types to be added without modifying existing sensor implementations (registering one with `SensorManager` is a small, localized change — see Extensibility).

## Architecture Components

### BaseSensor (Abstract Interface)

The foundation of the sensor system is an abstract base class that defines a common contract for all sensor implementations. This interface ensures consistency across different sensor types while allowing each sensor to implement its specific data collection logic.

**Key Responsibilities:**
- Define standard lifecycle methods that all sensors must implement
- Provide streaming interfaces for real-time sensor data delivery
- Expose sensor status information (availability, permissions, errors)
- Enable uniform interaction patterns regardless of sensor type

**Generic Type Parameter:**
The base sensor uses a generic type parameter to specify the data structure each sensor produces. For example, GPS sensors emit location points, while accelerometer sensors might emit step count data. This type safety ensures compile-time verification of data handling.

**Status Tracking:**
Every sensor maintains and broadcasts its current status, allowing the UI and business logic to react to permission changes, hardware availability, or error conditions. Status changes are delivered via a stream for reactive programming patterns.

**Data Streaming:**
Sensors deliver data through streams rather than callbacks, enabling reactive composition, backpressure handling, and clean integration with Flutter's state management patterns.

### SensorStatus (Enumeration)

The sensor status enumeration defines all possible states a sensor can be in throughout its lifecycle. These states inform the application about what actions can be taken and what UI should be displayed.

**Status States:**
- **Available**: Sensor hardware exists and permissions are granted - ready to stream data
- **Unavailable**: Device doesn't have the required hardware or system services are disabled
- **Denied**: User denied permission but can be requested again
- **Permanently Denied**: User permanently denied permission - requires system settings navigation
- **Active**: Sensor is currently streaming data
- **Error**: Sensor encountered an unrecoverable error

**Extension Helpers:**
The status enum includes helper methods to simplify common checks, such as whether permissions can be requested, whether the sensor is ready for use, or whether the user needs to visit system settings.

### SensorException (Error Handling)

A specialized exception type for sensor-specific errors that provides structured error information including the failing sensor's identity and the type of failure that occurred.

**Exception Types:**
- **Permission Denied**: User refused permission request
- **Unavailable**: Hardware or services not available
- **Initialization Failed**: Sensor couldn't be set up
- **Streaming Failed**: Data stream couldn't start or encountered errors

This structured approach enables specific error handling and user-friendly error messages tailored to each failure mode.

### GpsSensor (Concrete Implementation)

The GPS sensor is the first concrete sensor implementation, providing location tracking capabilities using the device's GPS hardware.

**Initialization Process:**
When the GPS sensor initializes, it checks whether location services are enabled on the device and whether the app has location permissions. Based on these checks, it sets its initial status appropriately. The sensor can transition from denied to available if the user grants permissions later.

**Permission Handling:**
The GPS sensor manages the complete permission flow, from initial requests to handling permanent denials. If location services are disabled, it provides appropriate error information. The permission checking logic distinguishes between temporary denials (can retry) and permanent denials (requires settings).

Beyond location, the sensor requests the Android 13+ notification permission via `ensureNotificationPermission()` so the foreground-service tracking notification is actually visible. It is best-effort by design: a no-op on non-Android platforms, reported as already granted on Android < 13, and it swallows any error — it never throws and never blocks a session, because the foreground service starts regardless of whether its notification can be shown. `SensorManager._startGpsSensor` calls it after location has been granted and immediately before `startStreaming`.

**Streaming Configuration:**
When streaming starts, the GPS sensor does not use one flat settings object. It calls the pure, `@visibleForTesting` factory `GpsSensor.buildLocationSettings(platform:, mode:)`, which branches on the target platform. On **Android** it returns `AndroidSettings` carrying a `ForegroundNotificationConfig` (title "BeneFit", text "Recording your activity session…", `enableWakeLock: true`, `setOngoing: true`), which makes geolocator host the position stream inside a `location`-typed foreground service. On **iOS** it returns `AppleSettings` with `allowBackgroundLocationUpdates: true`, `pauseLocationUpdatesAutomatically: false` (so CoreLocation never auto-pauses a stationary user), `showBackgroundLocationIndicator: true` and `activityType: ActivityType.fitness`. On every other platform (desktop, unit tests) it returns a plain `LocationSettings`. All three branches use `LocationAccuracy.high`.

**Background Behaviour (Foreground Service):**
Because of those settings, an active session keeps recording while the app is backgrounded or the screen is off. On Android the OS will not freeze the location stream while it is hosted by the foreground service; the notification is non-dismissible (`setOngoing: true`) and the wake lock keeps CPU and GPS alive with the screen off. On iOS the `location` background mode plus `allowBackgroundLocationUpdates` does the equivalent. The boundary is explicit: this covers backgrounding and screen-off only — an active session does **not** survive a hard OS process kill, which would need a background isolate. **Status: deferred to Phase B.** No `timeLimit` is set on the position stream; it runs for the whole session and is torn down by `stopStreaming()`.

**Distance Filtering:**
The sensor applies a minimum distance threshold between location updates to reduce redundant data points when stationary. This conserves battery and storage while maintaining tracking quality during movement. The threshold is mode-dependent: 5 m for `TrackingMode.manual` (`_manualDistanceFilter`) and 50 m for `TrackingMode.continuousDaily` (`_continuousDistanceFilter`), the latter trading fidelity for battery. Manual sessions are the only ones that currently stream, so the 50 m branch is a Phase B seam. Note that this sensor-level filter is distinct from the *storage* thresholds applied later by `ActivityProvider` (5 s / 10 m, see Threshold Logic).

**Quality Filtering:**
Each GPS point is evaluated for quality before being emitted on the data stream. Low-accuracy points or points with suspicious characteristics are silently discarded, ensuring downstream consumers receive only reliable location data.

**Position Conversion:**
The sensor translates platform-specific location objects into the application's domain GPS point model, including all relevant metadata like accuracy, altitude, speed, and timestamp.

**Error Resilience:**
Streaming errors don't crash the sensor - instead, they're logged and the sensor status is updated to reflect the error state. This allows the application to continue functioning and potentially retry later.

### HeartRateSensor (Implemented, outside SensorManager)

A second concrete implementation already exists: `HeartRateSensor extends BaseSensor<int>` in `lib/features/wearable_integration/data/sensors/heart_rate_sensor.dart`. It connects to BLE monitors using the standard Heart Rate Service (`0x180D`) and Heart Rate Measurement characteristic (`0x2A37`), and follows the same initialize / permission / stream / dispose lifecycle as GPS — `initialize()` only probes `FlutterBluePlus.isSupported` and the Bluetooth adapter state; the actual connection is made later by `connectToDevice`.

It lives in the `wearable_integration` module and is created and pooled by `BleDataSource`, **not** by `SensorManager` — the manager still coordinates GPS only. `ActivityProvider` subscribes to heart-rate data independently of the sensor manager when a session supplies a `heartRateDeviceId`. Consolidating it into `SensorManager` is a possible future step; **status today: implemented, but not wired into the sensor manager.**

### SensorManager (Coordinator)

The sensor manager acts as a central coordinator for all sensors in the application. It provides a unified interface for sensor operations and manages the lifecycle of all sensor instances.

**Initialization:**
On application startup, the sensor manager initializes all available sensors. This early initialization allows sensors to check hardware availability and permission status before they're needed, enabling proactive UI updates.

**Status Aggregation:**
The manager maintains a map of all sensor statuses, subscribing to status change streams from each sensor. This centralized status tracking enables dashboard views showing all sensor states at once.

**Session Coordination:**
When an activity tracking session starts, the sensor manager coordinates starting all relevant sensors. It handles permission requests, waits for sensor readiness, and reports which sensors successfully started. This coordination ensures sensors start in the correct order and dependencies are satisfied.

`startSession` also takes a `TrackingMode mode` (default `TrackingMode.manual`), forwarded by `ActivityProvider` as the current session's tracking mode. It is deliberately **not** part of `BaseSensor.startStreaming`, because `BaseSensor` is shared with `HeartRateSensor` and with test mocks; instead `_startGpsSensor` narrows with `if (gps is GpsSensor)` and passes the mode only to the concrete type, falling back to the base signature otherwise. `GpsSensor.startStreaming` therefore adds an optional named `mode` parameter, which is a legal override of the base signature. For the same reason the `gpsSensor` getter is typed `BaseSensor<GpsPoint>`, so any other GPS-specific API needs the same narrowing.

**Sensor Access:**
The manager provides direct access to individual sensor instances when specific sensor operations are needed. For example, accessing the GPS sensor's data stream to subscribe to location updates.

**Graceful Degradation:**
If a sensor fails to start, the session can continue with reduced functionality rather than failing entirely. The manager tracks which sensors are active and communicates this to the application.

**Cleanup:**
The manager ensures all sensors are properly disposed of when no longer needed, preventing resource leaks and conserving battery life.

**Extensibility:**
New sensors can be added to the manager by instantiating them, initializing them during the manager's initialization phase, and including them in session start/stop coordination. Adding a sensor is a localized but real change to `SensorManager`: a new field plus one line each in `initialize()`, `startSession()`, `stopSession()`, `requestAllPermissions()`, `checkAllPermissions()` and `dispose()` — commented-out hooks already mark every spot. What the design guarantees is that *existing* sensors are never touched.

## Integration with Activity Tracking

### ActivityProvider Integration

The activity provider integrates with the sensor system to track GPS data during manual activity sessions.

**Dependency Injection:**
The activity provider accepts an optional sensor manager instance, defaulting to creating its own if not provided. This design enables testing with mock sensors while keeping production code simple.

**Session Lifecycle:**
When a session starts, the provider requests the sensor manager to start all sensors for that session. It subscribes to the GPS data stream to receive location points in real-time. When the session stops, it unsubscribes and requests sensor shutdown.

**Distance Tracking:**
Each GPS point received is evaluated against storage thresholds to determine if it should be saved. Points meeting the criteria are added to an in-memory list (used for distance recalculation) and buffered for persistence. The in-memory list of session points enables efficient distance recalculation as new points arrive.

**Batched Persistence:**
Database writes are batched rather than per-point. Qualifying points are appended to a pending buffer (`_pendingGpsPoints`) and flushed to the database in a single batch via `GpsPointDao.insertBatch` once the buffer reaches the batch size (`_gpsBatchSize = 5`), and also on pause, stop, and app-background (`flushPendingGps()`). Distance and the UI read the in-memory point list, not the database, so batching the writes does not affect them. The flush is race-safe (the buffer is swapped out before the await) and error-safe (a failed batch is re-queued for the next flush). The buffer is additionally flushed once it has been sitting unwritten for longer than `_maxBufferAge` (60 s); this is checked on point arrival rather than by a periodic timer, because the OS throttles timers in the background. The only loss window is therefore a hard OS process-kill that skips the lifecycle `paused`/background event, and it is bounded twice over: at most 4 points (`< _gpsBatchSize`) and at most 60 s of buffering.

**Threshold Logic:**
GPS points are stored based on time elapsed since the last point or distance traveled since the last point. This hybrid approach ensures smooth tracking during steady movement while avoiding excessive storage during stationary periods. The first point of a session is always stored; afterwards `GpsTrackingConfig.shouldStorePoint` ORs a 5 s time threshold with a 10 m distance threshold. Note that the call hardcodes `isContinuousMode: false` — the continuous-mode thresholds exist in the config but are unreachable today, because only manual sessions stream.

**Real-time Updates:**
As GPS points are received and distance is recalculated, the provider notifies listeners so the UI updates immediately. Users see their distance increase in real-time as they move.

**Error Handling:**
If GPS fails to start or permissions are denied, the session continues with distance tracking disabled rather than preventing the entire session. Users can still track time-based metrics even without GPS. The failure is surfaced through a dedicated `gpsStartWarning` channel rather than the fatal `error` state, so the tracking screen keeps rendering instead of being replaced by an error view. The message is chosen per sensor status — location services off ("Location is turned off…"), permission permanently blocked ("Location permission is blocked. Enable it in Settings…"), or a generic permission prompt. On app resume, `retryGpsIfNeeded()` re-attempts the start, but only while a session is tracking, no GPS subscription exists and a warning is pending; that triple guard prevents a double subscription. A successful retry clears the warning.

**State Cleanup:**
When sessions end or are cancelled, all GPS tracking state is reset including subscriptions, cached points, and distance calculations. This prevents data from one session affecting another.

### Main Application Initialization

The sensor manager is initialized during application startup, before the provider tree is constructed. This ensures sensors are ready when the first screen renders and permission statuses can be displayed immediately.

The initialized sensor manager is passed to the activity provider as a dependency, establishing the connection between sensor infrastructure and business logic.

### UI Updates

The activity screen displays real-time distance by reading the current distance from the provider and converting meters to kilometers. The reactive provider pattern ensures the display updates automatically as new GPS points arrive.

## Platform Configuration

Background GPS only works because of native declarations that live outside `lib/`.

**Android** (`android/app/src/main/AndroidManifest.xml`) declares `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS` (the Android 13+ runtime permission for the tracking notification) and `WAKE_LOCK` (paired with `enableWakeLock`). The service element itself is contributed by the `geolocator_android` plugin (`GeolocatorLocationService`, `foregroundServiceType="location"`) and arrives via manifest merge — the app only contributes the permissions.

`ACCESS_BACKGROUND_LOCATION` is **deliberately** commented out and deferred to Phase B. Active sessions start the location foreground service while the app is in the foreground, so the while-in-use permission is sufficient, and requesting background location would trigger Google Play's background-location review. Re-add it only when `continuousDaily` (background-*started*) tracking is implemented.

**iOS** (`ios/Runner/Info.plist`) declares `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` and `UIBackgroundModes: [location]`, which CoreLocation requires to deliver updates while the app is backgrounded.

## Quality Assurance

### Quality Filtering

GPS points are filtered at the sensor level based on accuracy thresholds defined in the GPS tracking configuration. This centralized filtering ensures all consumers receive high-quality data without implementing their own filtering logic.

The filtering examines accuracy (horizontal error margin), age (time since point was captured), and other quality indicators. Points failing quality checks are discarded before reaching the data stream.

### Storage Optimization

The hybrid time-distance threshold prevents storing excessive points during stationary periods while ensuring sufficient point density during movement. This balances storage requirements with route reconstruction quality.

Points stored in the database can be retrieved to reconstruct activity routes, calculate detailed statistics, or export for external analysis.

## Testing Strategy

### Mock Sensors

Mock sensor implementations can be created for testing by extending the base sensor interface. Mock sensors control when data is emitted, what status changes occur, and whether errors are simulated.

These mocks enable comprehensive testing of the activity provider and sensor manager without requiring real hardware or permissions.

### Unit Testing

Unit tests focus on stable public methods unlikely to change during development. Streaming itself is still not exercised end-to-end (that needs real hardware), but the *configuration* of streaming is: `GpsSensor.buildLocationSettings` is a pure `@visibleForTesting` static mapping (platform, `TrackingMode`) to `LocationSettings`, and `test/unit/features/shared/sensors/gps_location_settings_test.dart` covers all four branches — Android foreground service + 5 m, Android `continuousDaily` + 50 m, iOS background flags, and the plain-settings fallback — without invoking Geolocator. `test/unit/features/shared/sensors/sensor_manager_test.dart` covers manager initialization, permission checking and status tracking against `MockGpsSensor`.

### Manual Device Testing

Real device testing validates GPS accuracy, permission request flows, distance calculations, and different activity types. This testing cannot be automated due to the need for actual movement and hardware interaction.

## Future Extensibility

### Accelerometer / Step Counter Sensor

**Status: not built.** Nothing in `lib/` implements an accelerometer or step counter, and `pubspec.yaml` carries no `sensors_plus` or `pedometer` dependency. The only traces are aspirational: the `ACTIVITY_RECOGNITION` permission reserved "for future accelerometer" in the Android manifest, the pedometer trust multipliers in `lib/core/config/tracking_config.dart`, and the commented-out hooks in `SensorManager`.

A future accelerometer sensor would implement the same base sensor interface, providing step count and movement pattern data. The sensor manager would initialize it alongside GPS, and the activity provider could subscribe to its data stream.

No modifications to existing sensor code would be required - only the addition of the new sensor class and registration with the manager.

### Privacy Controls

Future privacy features could include user-configurable location precision, privacy zones where tracking is automatically paused, and data retention policies. These features would integrate with the existing sensor architecture through configuration objects and policy checks.

## Key Design Principles

### Separation of Concerns

Sensors handle only hardware interaction and data acquisition. Business logic like session management and metric calculation lives in providers. UI code focuses on display and user interaction. This separation enables independent evolution of each layer.

### Reactive Programming

Stream-based data flow enables reactive composition throughout the application. UI components react to data changes automatically through provider notifications. This eliminates manual refresh logic and ensures consistency.

### Testability

Optional dependency injection, mock implementations, and clear interfaces enable comprehensive testing at every layer. Production code remains simple while test code gains full control.

### Progressive Enhancement

If a sensor is unavailable, the application continues with reduced functionality rather than failing entirely. Users with devices lacking GPS can still track time-based metrics. This graceful degradation maximizes usability across device capabilities.

### Resource Efficiency

Sensors stream only when sessions are active, conserving battery during idle periods. Quality filtering and storage thresholds minimize database operations. Proper disposal prevents resource leaks.

## Summary

The modular sensor architecture provides a robust foundation for multi-sensor activity tracking. GPS serves as the first implementation, demonstrating patterns already reused by `HeartRateSensor` (in the `wearable_integration` module) and available for future accelerometer/step sensors. The design prioritizes flexibility, testability, and user experience while maintaining clear separation between hardware interaction, business logic, and presentation layers.
