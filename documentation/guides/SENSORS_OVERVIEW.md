---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [SENSORS.md](../../lib/features/shared/sensors/SENSORS.md) - Implementation details
>
> **Related:** [WEARABLE_INTEGRATION Overview](../wearables/WEARABLE_INTEGRATION_OVERVIEW.md) | [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [BACKGROUND_TRACKING_PLAN.md](../sessions/BACKGROUND_TRACKING_PLAN.md) (DE)
>
> **Last updated:** 2026-08-28 · Branch `feat/phase-2-background-tracking` (WP1–WP5 done, WP6 device smoke open)
---

# Sensor Architecture Overview

## Purpose

The sensor system provides a unified framework for accessing device sensors (GPS, accelerometer, heart rate) in the BeneFit app. It abstracts platform differences and provides a consistent interface for all sensor types.

## Key Concepts

### BaseSensor Pattern
All sensors extend a common base class that defines:
- Initialization and cleanup lifecycle
- Data streaming interface
- Error handling patterns
- Permission management

### Sensor Types

| Sensor | Data Provided | Use Case |
|--------|---------------|----------|
| **GPS** | Location, speed, altitude | Track movement and distance |
| **Accelerometer** | Motion data | Activity detection |
| **Heart Rate** | BPM, HRV | Fitness metrics |
| **Step Counter** | Step count | Walking/running stats |

> **Implementation status:** Within the shared sensor framework, only the **GPS** sensor (`GpsSensor`) is currently coordinated by `SensorManager`. A **heart rate** sensor (`HeartRateSensor`, BLE Heart Rate Service `0x180D`) is implemented separately in the `wearable_integration` module and is not coordinated by `SensorManager`. The accelerometer and step counter rows describe the intended scope of the framework; `SensorManager` contains commented-out hooks for these future sensors but does not yet manage them. **Neither the accelerometer nor the step counter is built:** nothing in `lib/` implements one and `pubspec.yaml` has no `sensors_plus` or `pedometer` dependency.

## Architecture

```
┌─────────────────────────────────────────┐
│            ActivityProvider             │
│      (session lifecycle + storage)      │
└──────┬───────────────────────┬──────────┘
       │                       │
       ▼                       ▼
┌─────────────────┐   ┌───────────────────┐
│  SensorManager  │   │   BleDataSource   │
│   (GPS only)    │   │ (wearable module) │
└────────┬────────┘   └─────────┬─────────┘
         │                      │
         ▼                      ▼
┌─────────────────┐   ┌───────────────────┐
│    GpsSensor    │   │  HeartRateSensor  │
│ BaseSensor<Gps  │   │  BaseSensor<int>  │
│     Point>      │   │                   │
└────────┬────────┘   └─────────┬─────────┘
         │                      │
         ▼                      ▼
┌─────────────────┐   ┌───────────────────┐
│ geolocator      │   │ BLE HR Service    │
│ (+ Android FGS) │   │ 0x180D / 0x2A37   │
└─────────────────┘   └───────────────────┘
```

> There is no `SessionManager` type in the codebase; `ActivityProvider` is the component that drives `SensorManager` and owns session state. `SensorManager` holds exactly one sensor (`BaseSensor<GpsPoint> _gpsSensor`); the heart-rate sensor hangs off `BleDataSource` in the `wearable_integration` module.

## Sensor Lifecycle

1. **Initialize**
   - Check hardware/service availability and current permission status
   - Set initial sensor status (permissions are requested later, on session start)
   - Do **not** open connections or request permissions here — `initialize()` is a pure capability probe run once at app start

2. **Start Streaming**
   - Begin data collection
   - Emit data through stream
   - Handle errors gracefully
   - On Android/iOS this is where the foreground service / background location mode is activated, via the platform-specific `LocationSettings`

3. **Process Data**
   - Filter and validate
   - Transform to app models
   - Store or display

4. **Stop & Cleanup**
   - Stop data collection
   - Release resources
   - Reset status to `available` — the sensor itself persists nothing; the consumer flushes buffered data *before* calling `stopStreaming()`

## GPS Sensor Specifics

The GPS sensor is the primary sensor for tracking:

| Feature | Description |
|---------|-------------|
| **High Accuracy** | Uses `LocationAccuracy.high` on every platform; points worse than 50 m accuracy are filtered out |
| **Distance Filter** | Mode-dependent: 5 m for `TrackingMode.manual` (`_manualDistanceFilter`), 50 m for `TrackingMode.continuousDaily` (`_continuousDistanceFilter`). Manual is the only mode that streams today, so 50 m is a Phase B seam |
| **Background Recording** | Android: `AndroidSettings` + `ForegroundNotificationConfig` (ongoing notification, `enableWakeLock`) runs the stream in a location foreground service. iOS: `AppleSettings` with `allowBackgroundLocationUpdates`, `pauseLocationUpdatesAutomatically: false`, `activityType: fitness`. Survives backgrounding and screen-off — **not** a process kill |
| **Platform Branching** | `GpsSensor.buildLocationSettings(platform:, mode:)` — pure and `@visibleForTesting`; falls back to plain `LocationSettings` on desktop/tests |
| **Quality Filtering** | Skips points that fail `meetsQualityRequirements()` — accuracy worse than 50 m, fix older than 10 s, or missing accuracy |
| **Stream-based** | Emits validated `GpsPoint` objects through a broadcast stream |

> **Persistence note:** The GPS *sensor* only validates and streams points. The consumer (`ActivityProvider`) does the storage: qualifying points are buffered and **batch-inserted** into the database via `GpsPointDao.insertBatch` (batch size 5, plus a 60 s max-buffer-age flush checked on point arrival, plus explicit flushes on pause, stop and app-background) rather than written one at a time. Distance and the UI read the in-memory point list, so batching does not delay them.

## Data Flow

```
Platform Sensor
      │
      ▼
 Raw Data Event
      │
      ▼
 Data Validation
      │
      ▼
 Model Conversion
      │
      ▼
 Stream Emission
      │
      ▼
 UI / Storage
```

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Wearable Integration | [WEARABLE_INTEGRATION.md](../../lib/features/wearable_integration/WEARABLE_INTEGRATION.md) | [WEARABLE_INTEGRATION_OVERVIEW](../wearables/WEARABLE_INTEGRATION_OVERVIEW.md) |
| Database Schema | [DATABASE.md](../../database/DATABASE.md) | [DATABASE_OVERVIEW](../data/DATABASE_OVERVIEW.md) |
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](../screens/ACTIVITY_SCREEN_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
