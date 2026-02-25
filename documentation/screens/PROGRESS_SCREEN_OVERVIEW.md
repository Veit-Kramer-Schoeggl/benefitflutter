---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [ACTIVITY_SCREEN Overview](./ACTIVITY_SCREEN_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Progress Screen Overview

## Purpose

The Progress Screen displays a history of completed workout sessions. It serves as the primary example for implementing the Provider pattern with loading states, error handling, and list displays.

## Key Features

| Feature | Description |
|---------|-------------|
| **Session List** | Scrollable list of past workouts |
| **Activity Icons** | Visual indicators for activity type |
| **Pull to Refresh** | Update session list |
| **Session Details** | Duration, distance, date |
| **Empty State** | Friendly message when no sessions |

## Screen States

The Progress Screen handles four states:

| State | Condition | UI Display |
|-------|-----------|------------|
| **Loading** | Fetching data | Spinner with message |
| **Error** | Request failed | Error message + retry button |
| **Empty** | No sessions | Empty state illustration |
| **Success** | Data loaded | Session list |

## User Interface

```
┌─────────────────────────────────────────────────┐
│                   Progress                       │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │ 🏃 Running                     Today     │  │
│  │                              5.2 km      │  │
│  │                              32:15       │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │ 🚴 Cycling                   Yesterday   │  │
│  │                              15.8 km     │  │
│  │                              45:30       │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │ 🚶 Walking                    Feb 18     │  │
│  │                              2.1 km      │  │
│  │                              25:00       │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Data Flow

```
Screen loads
     │
     ▼
Provider fetches sessions
     │
     ▼
Loading state shown
     │
     ▼
Data received from repository
     │
     ├── Success → Display session list
     │
     ├── Error → Show error with retry
     │
     └── Empty → Show empty state
```

## Session Information

Each session card displays:
- **Activity Type:** Walking, Running, or Cycling
- **Date:** Today, Yesterday, or specific date
- **Distance:** In meters or kilometers
- **Duration:** Formatted as HH:MM:SS

## Interactions

| Action | Result |
|--------|--------|
| **Pull down** | Refresh session list |
| **Tap session** | Show session details (future) |
| **Tap retry** | Retry failed request |

## Provider Pattern Example

The Progress Screen demonstrates:
1. State management with Provider
2. Loading, error, and success states
3. Pull-to-refresh implementation
4. List building with Consumer

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](./ACTIVITY_SCREEN_OVERVIEW.md) |
| Profile Screen | [PROFILE_SCREEN_PLAN.md](../../lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) | [PROFILE_SCREEN_OVERVIEW](./PROFILE_SCREEN_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
