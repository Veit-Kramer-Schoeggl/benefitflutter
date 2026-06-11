---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [ACTIVITY_SCREEN Overview](./ACTIVITY_SCREEN_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Progress Screen Overview

## Purpose

The Progress Screen shows the user's activity history and statistics. It combines completed workout sessions from the local database with manually entered activities (stored in `SharedPreferences`). It serves as the primary example for implementing the Provider pattern with loading states, error handling, list displays, and chart visualisations.

The screen is organised into two tabs (`STATISTICS` and `ACTIVITIES`) driven by a `TabBar` in the AppBar, and shows an "EARNED SO FAR" bar at the bottom that reads the total savings from `BenefitProvider`.

## Key Features

| Feature | Description |
|---------|-------------|
| **Two Tabs** | `STATISTICS` (charts & summary) and `ACTIVITIES` (history list) |
| **Statistics Charts** | Weekly / monthly / yearly distance and duration charts plus summary cards |
| **Activity List** | Activities grouped by date (Today / Yesterday / This Week / Older) |
| **Manual Entry** *(planned)* | Add, edit, and delete manual activities via a dialog — provider methods and dialog code exist but are not yet wired to a UI entry point |
| **Session Details** | Tapping any activity opens `SessionDetailScreen` |
| **Earned So Far Bar** | Bottom bar showing total savings from `BenefitProvider` |
| **Empty State** | Friendly message when no activities exist |

## Screen States

The Progress Screen handles the following states:

| State | Condition | UI Display |
|-------|-----------|------------|
| **Loading** | `provider.isLoading` is true | Centered `CircularProgressIndicator` |
| **Error** | `provider.error != null` | Centered `Text('Error: ...\nTap to retry')` |
| **Empty** | `provider.activities` is empty | Tab-specific empty message (handled inside each tab widget) |
| **Success** | Data loaded | `TabBarView` with statistics and activities |

> Note: Only the loading and error states are handled inside the `Consumer<ProgressProvider>`. The empty state is handled within each tab widget (`ActivitiesTab` / `StatisticsTab`), which renders its own empty message when `provider.activities` is empty.

> Note: The current implementation uses plain `CircularProgressIndicator` / `Text` widgets for the loading and error states rather than the shared `LoadingWidget` / `ErrorDisplayWidget`. The error state shows "Tap to retry" text but does not wire up a dedicated retry button.

## User Interface

The screen is a `Scaffold` with a green AppBar titled "Progress" that carries a `TabBar` (`STATISTICS` / `ACTIVITIES`), a `TabBarView` body, and an "EARNED SO FAR" bar as the `bottomNavigationBar`.

### Activities tab

Activities are grouped under date section headers (`TODAY`, `YESTERDAY`, `THIS WEEK`, `OLDER`). Each list item (`ActivityListItem`) shows a generic activity icon, the activity type, the formatted date, the distance, and the duration.

```
┌─────────────────────────────────────────────────┐
│  Progress         [ STATISTICS | ACTIVITIES ]    │
│                                                  │
│  TODAY                                            │
│  ┌───────────────────────────────────────────┐  │
│  │ [icon] Running               5.20 km      │  │
│  │        18.02.2026, 08:30     00:32:15     │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  YESTERDAY                                        │
│  ┌───────────────────────────────────────────┐  │
│  │ [icon] Cycling              15.80 km      │  │
│  │        17.02.2026, 17:45     00:45:30     │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ─────────────────────────────────────────────  │
│  EARNED SO FAR                          12.50 €  │
└─────────────────────────────────────────────────┘
```

### Statistics tab

Shows summary cards (This Week / This Month / Total) followed by charts: weekly distance (bar) and duration (line), monthly distance (bar) and duration (line), and yearly distance (bar). Charts are custom-drawn (`CustomBarChart` / `CustomLineChart`).

## Data Flow

`ProgressProvider.loadActivities()` is called from the provider constructor, when the user changes (`updateUserId`), and when the Progress tab is opened (`MainNavigationScreen._onTabTapped` reloads on entry). It first loads manual entries from `SharedPreferences`, then fetches sessions from the `SessionRepository`, keeps only `completed` sessions, converts them to `ActivityEntry` objects, combines them with the manual entries, and sorts newest-first.

```
loadActivities()
     │
     ▼
isLoading = true (notifyListeners)
     │
     ▼
Load manual entries (SharedPreferences)
     │
     ▼
getAllSessions(userId) from repository
     │
     ├── Success → keep COMPLETED sessions →
     │             combine with manual entries → sort → display
     │
     ├── Error → fall back to manual entries only + set error
     │
     └── Empty → activities list empty → empty state
```

## Activity Information

Each `ActivityEntry` displayed in the list shows:
- **Activity Type:** A free-form string. Recorded sessions use the `ActivityType.name` (e.g. `running`); manual entries are stored as `'Manual Entry'`.
- **Date:** Formatted as `dd.MM.yyyy, HH:mm` and grouped under date headers (Today / Yesterday / This Week / Older).
- **Distance:** Always in kilometres with 2 decimals (e.g. `5.20 km`), or `--` when missing.
- **Duration:** Formatted as `HH:MM:SS`, or `--` when missing.

## Interactions

| Action | Result |
|--------|--------|
| **Tap activity (manual or recorded)** | Opens `SessionDetailScreen` for that entry |
| **Add manual entry** *(not yet wired)* | Intended to open the manual-entry dialog (duration & distance required) |
| **Edit manual entry** *(not yet wired)* | Intended to re-open the dialog pre-filled with the entry's values |
| **Delete activity** *(not yet wired)* | Intended to remove the entry (and delete the session from the DB for recorded activities) |
| **Switch tab** | Toggles between the Statistics and Activities tabs |

> Note: Manual add/edit/delete are not currently reachable from the UI. Every list item routes its tap to `_openSessionDetails` → `SessionDetailScreen`, and there is no Add button or FAB that triggers `onAddManualTap`. The supporting pieces exist but are not connected: the provider exposes `addActivity` / `updateActivity` / `removeActivity`, and the screen still contains the manual-entry dialog (`_showManualEntrySimulatedDialog`) and an action-dialog handler (`_handleTapOrSwipeAction`), but the latter is dead code that is never invoked.

> Note: There is no pull-to-refresh in the current implementation. Data is reloaded automatically when the Progress tab is opened and when the active user changes.

## Provider Pattern Example

The Progress Screen demonstrates:
1. State management with Provider (`ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>`)
2. Loading and error states via `Consumer<ProgressProvider>` (with empty and success states resolved inside each tab widget)
3. Combining a remote/DB source with a local `SharedPreferences` source
4. List building and chart rendering from provider-derived data

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](./ACTIVITY_SCREEN_OVERVIEW.md) |
| Profile Screen | [PROFILE_SCREEN_PLAN.md](../../lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) | [PROFILE_SCREEN_OVERVIEW](./PROFILE_SCREEN_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
