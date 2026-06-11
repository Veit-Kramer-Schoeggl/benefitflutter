---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [SENSORS Overview](../guides/SENSORS_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
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
│  │              00:00:00                   │    │
│  └─────────────────────────────────────────┘    │
│                      │                          │
│                      ▼                          │
│  ┌─────────────────────────────────────────┐    │
│  │           [START Running]               │    │
│  └─────────────────────────────────────────┘    │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Session States

A single multi-purpose button drives the session. Its label and action change with the state, and a long-press while paused stops and saves the session.

| State | Timer | Button (tap) | Long-press | GPS |
|-------|-------|--------------|------------|-----|
| **Idle** | Stopped | "START Running" → start | (no effect) | Off |
| **Tracking** | Running | "Pause" → pause | (no effect) | Active |
| **Paused** | Stopped | "Continue / Stop" → resume | Stop & save | Still streaming |

> Note: pausing only stops the timer. GPS keeps streaming while paused (`ActivityProvider.pauseSession()` never tells the sensor to stop), but distance is still accumulated from incoming points.

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
- Live heart rate requires a connected BLE monitor. The Start button does not currently pass a `heartRateDeviceId` to `startSession()`, so `currentHeartRate` stays null and the heart-rate display shows "--" (with a tap-to-connect action) unless a monitor is connected
- Session data persists in the database
- User can pause (tap) at any time; tapping again resumes

### Stopping a Session
1. User long-presses the button while paused
2. Timer, GPS, and heart rate tracking stop
3. Session is marked as completed (final duration, distance, and heart-rate stats saved)
4. If continuous tracking was active before, it is restarted
5. A "Session saved!" confirmation is shown and the session appears in the Progress screen

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
- Updates UI every second (timer tick)
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
