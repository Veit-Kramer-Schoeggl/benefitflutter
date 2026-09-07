---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [SENSORS Overview](../guides/SENSORS_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
>
> **Last updated:** 2026-08-28 · branch `feat/phase-2-background-tracking` (background-tracking WP1–WP5 done, WP6 on-device smoke still open)
---

# Activity Screen Overview

## Purpose

The Activity Screen is the central hub for starting, pausing, and stopping workout sessions. It handles real-time tracking with timer and GPS, making it the most complex screen in the app.

## Key Features

| Feature | Description |
|---------|-------------|
| **Running Session** | Activity type is fixed to running (default `ActivityType.running`) |
| **Real-Time Timer** | Updates every second during session |
| **Start/Pause/Stop** | Tap to start/pause/resume; long-press while paused to stop |
| **Distance Tracking** | GPS-based distance calculation, displayed in km |
| **Background Recording** | Android foreground service keeps a session recording while the app is backgrounded (not across a process kill) |
| **Heart Rate Display** | Live BPM from a connected BLE monitor (optional) |
| **Earnings Bar** | Shows total savings earned so far (from `BenefitProvider`) |
| **Session Persistence** | Data saved to the database during the session |

## User Flow

```
┌─────────────────────────────────────────────────┐
│                 Activity Screen                  │
│                                                  │
│  ┌─────────────────────────────────────────┐    │
│  │            New running session!          │    │
│  │                0.0 KM                    │    │
│  └─────────────────────────────────────────┘    │
│                      │                          │
│                      ▼                          │
│  ┌─────────────────────────────────────────┐    │
│  │      00:00:00  (hidden while idle)      │    │
│  └─────────────────────────────────────────┘    │
│                      │                          │
│                      ▼                          │
│  ┌─────────────────────────────────────────┐    │
│  │           [START Running]               │    │
│  └─────────────────────────────────────────┘    │
│                                                  │
└─────────────────────────────────────────────────┘
```

The timer is only rendered while tracking or paused (`AnimatedOpacity` 0 → 1 plus `AnimatedScale`); in the idle state the card shows the distance pill, the status line "Ready to start recording" and the START button.

## Session States

A single multi-purpose button drives the session. Its label and action change with the state, and a long-press while paused stops and saves the session.

| State | Timer | Button (tap) | Long-press | GPS |
|-------|-------|--------------|------------|-----|
| **Idle** | Hidden | "START Running" → start | SnackBar: "Long press only works while paused" | Off |
| **Tracking** | Running | "Pause" → pause | SnackBar: "Long press only works while paused" | Active |
| **Paused** | Stopped | "Continue / Stop" → resume | Stop & save | Still streaming |

> Note: pausing only stops the timer. GPS keeps streaming while paused (`ActivityProvider.pauseSession()` never tells the sensor to stop), but distance is still accumulated from incoming points.

### Error Handling

A **fatal** error — no logged-in user (`"Please log in to start tracking"`) or a failed start/pause/resume/stop — sets `ActivityProvider.error`, and the **entire screen body is replaced** by the shared `ErrorDisplayWidget` ("Oops!"): timer, distance, GPS banner and the button all disappear.

**Status: known rough edge.** The widget is built with `onRetry: null`, so there is no retry button — and because the multi-purpose button is gone with it, nothing on this screen can call `startSession()` again. The provider has no public `clearError()`; in practice the state only clears when the logged-in user changes (login/logout resets the provider).

This is deliberately different from the **non-fatal** GPS warning below, which is kept in a separate field (`gpsStartWarning`) so it leaves the tracking UI intact.

## How It Works

### Starting a Session
1. Activity type is fixed to running (set on first load)
2. User taps the "START Running" button
3. Any active continuous (daily) sessions are completed first
4. A new manual session is created in the database immediately
5. Timer starts counting
6. GPS tracking begins (if available); heart rate tracking starts if a device was passed in

### During Tracking
- Timer updates every second
- Distance accumulates from GPS data and is shown in km
- Not every GPS fix becomes a point: the sensor discards fixes with an accuracy worse than **50 m** or a fix older than **10 s**, and a surviving fix is only stored once at least **5 seconds** or **10 meters** have passed since the previously stored point (manual mode; continuous mode uses 300 s / 100 m — all in `GpsTrackingConfig`). Distance is then recomputed over the stored points with the Haversine formula in `DistanceCalculator`, which is why it moves in steps rather than continuously
- GPS points are **batch-inserted**: qualifying points are buffered in memory and flushed to the database via `GpsPointDao.insertBatch` once **5** points are buffered (`ActivityProvider._gpsBatchSize`), or as soon as a point arrives more than **60 s** after the last flush (`_maxBufferAge`) — plus explicit flushes on pause, stop and app-background (`flushPendingGps()`). Distance and the UI read the in-memory point list, so batching doesn't delay the display. A failed batch is re-queued for the next flush; only the points buffered since the last flush can be lost on a hard process kill
- Live heart rate requires a connected BLE monitor. The Start button does not currently pass a `heartRateDeviceId` to `startSession()`, so `currentHeartRate` stays null and the heart-rate display shows "--" (with a tap-to-connect action) unless a monitor is connected
- Session data persists in the database (the session row is updated as distance changes; raw GPS points are batched as above)
- User can pause (tap) at any time; tapping again resumes

### GPS Permission & Location Warnings

Starting a session requests the location permission through `SensorManager` → `GpsSensor.requestPermissions()`. If location services are off or the permission is denied, **the session still starts** — timer and heart rate keep running, only distance and route are not recorded. The screen then shows an orange SnackBar (6 s) *and* a persistent inline orange banner with the reason:

| Situation (`SensorStatus`) | Message |
|----------------------------|---------|
| Location services off (`unavailable`) | "Location is turned off. Enable location to record your route." |
| Permission blocked (`permanentlyDenied`) | "Location permission is blocked. Enable it in Settings to record your route." |
| Denied / other | "Location permission is required to record your route." |
| Sensor threw while starting | "Could not start GPS. Distance and route will not be recorded." |

When the permission is permanently denied (`ActivityProvider.gpsNeedsSettings`), the SnackBar carries a **Settings** action that opens the system app settings. When the app is resumed, `ActivityProvider.retryGpsIfNeeded()` re-attempts GPS once and clears the warning if the user granted the permission in the meantime.

### Recording in the Background

**Status: works while the app is backgrounded, not across a process kill** (branch `feat/phase-2-background-tracking`, WP2/WP3).

- On **Android** the GPS stream runs inside geolocator's foreground service: an ongoing "BeneFit — Recording your activity session…" notification plus a wake lock keeps the session recording while the app is in the background
- On **Android 13+** the notification permission is requested right before that service starts (`GpsSensor.ensureNotificationPermission()`). It is best-effort: denying it only hides the notification, tracking continues
- On **iOS** background location updates are enabled (`allowBackgroundLocationUpdates`, the blue background indicator, `activityType: fitness`)
- The location stream uses a distance filter of **5 m** for manual sessions and **50 m** for continuous tracking
- Neither platform survives a hard process kill. Resuming a session from a background isolate is **planned (Phase B), not built**

### Stopping a Session
1. User long-presses the button while paused
2. Timer, GPS, and heart rate tracking stop (the GPS buffer is flushed before the stream is torn down)
3. Session is marked as completed and persisted **atomically together with the heart-rate summary** via `SessionRepository.finalizeSession()` (final duration, distance and avg/max/min HR)
4. If continuous tracking was active before, it is restarted
5. A "Session saved!" confirmation is shown and the session appears in the Progress screen

> If the stop fails, the state is deliberately kept (no false "stopped") and the error message is surfaced. A session is also auto-completed **without** a stop press when the logged-in user changes: on logout or account switch `ActivityProvider.updateUserId()` writes the session as completed (elapsed duration, distance, heart-rate stats) and resets all tracking state to idle.

## Data Stored

Each session records:
- Activity type
- Start and end times
- Total duration in seconds
- Total distance in meters
- GPS track points (for map display)
- Heart-rate statistics (avg/max/min) and connected device IDs, when a monitor is used

## Real-Time Architecture

Unlike other screens that load data once, the Activity Screen:
- Repaints the UI every second (timer tick) — the tick itself does **not** count seconds: the elapsed value is derived from timestamps (`_accumulatedActive` + time since the current segment started), so a throttled background timer cannot make the clock drift and paused time is excluded
- Processes GPS data stream continuously
- Manages three distinct states
- Requires proper cleanup on dispose

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Progress Screen | [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) | [PROGRESS_SCREEN_OVERVIEW](./PROGRESS_SCREEN_OVERVIEW.md) |
| Sensor System | [SENSORS.md](../../lib/features/shared/sensors/SENSORS.md) | [SENSORS_OVERVIEW](../guides/SENSORS_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
