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
| **Activity Selection** | Choose walking, running, or cycling |
| **Real-Time Timer** | Updates every second during session |
| **Start/Pause/Stop** | Full session control |
| **Distance Tracking** | GPS-based distance calculation |
| **Session Persistence** | Data saved even on app crash |

## User Flow

```
┌─────────────────────────────────────────────────┐
│                 Activity Screen                  │
│                                                  │
│  ┌─────────────────────────────────────────┐    │
│  │         Select Activity Type            │    │
│  │    [Walk]    [Run]    [Cycle]          │    │
│  └─────────────────────────────────────────┘    │
│                      │                          │
│                      ▼                          │
│  ┌─────────────────────────────────────────┐    │
│  │              00:00:00                   │    │
│  │                0 m                      │    │
│  └─────────────────────────────────────────┘    │
│                      │                          │
│                      ▼                          │
│  ┌─────────────────────────────────────────┐    │
│  │              [START]                    │    │
│  └─────────────────────────────────────────┘    │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Session States

| State | Timer | Buttons Available | GPS |
|-------|-------|-------------------|-----|
| **Idle** | Stopped | Start | Off |
| **Tracking** | Running | Pause, Stop | Active |
| **Paused** | Stopped | Resume, Stop | Paused |

## How It Works

### Starting a Session
1. User selects activity type (walking, running, cycling)
2. User taps Start button
3. Session is created in database immediately
4. Timer starts counting
5. GPS tracking begins (if available)

### During Tracking
- Timer updates every second
- Distance accumulates from GPS data
- Session data persists in database
- User can pause or stop at any time

### Stopping a Session
1. User taps Stop button
2. Timer and GPS stop
3. Session is marked as completed
4. Final duration and distance saved
5. Session appears in Progress screen

## Data Stored

Each session records:
- Activity type
- Start and end times
- Total duration in seconds
- Total distance in meters
- GPS track points (for map display)

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
