---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [ACTIVITY_SCREEN Overview](./ACTIVITY_SCREEN_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
>
> **Last verified against code:** 2026-08-28 (branch `feat/phase-2-background-tracking`)
---

# Progress Screen Overview

## Purpose

The Progress Screen shows the user's activity history and statistics. It combines completed workout sessions from the local database with manually entered activities (stored in `SharedPreferences`). It serves as the primary example for implementing the Provider pattern with loading states, error handling, list displays, and chart visualisations.

The screen is organised into two tabs (`STATISTICS` and `ACTIVITIES`) driven by a `TabBar` in the AppBar, and shows an "EARNED SO FAR" bar at the bottom that reads the total savings from `BenefitProvider`.

## Key Features

| Feature | Description |
|---------|-------------|
| **Two Tabs** | `STATISTICS` (charts & summary) and `ACTIVITIES` (history list) |
| **Statistics Charts** | Five hand-drawn charts (no charting package): weekly distance & duration, monthly distance & duration (current calendar year only), yearly distance (fixed 6-year window), plus three summary cards |
| **Activity List** | Activities grouped by date (Today / Yesterday / This Week / Older) |
| **Manual Entry** *(planned)* | Add, edit, and delete manual activities via a dialog — provider methods and dialog code exist but are not yet wired to a UI entry point |
| **Session Details** | Tapping any activity pushes `/session/<id>` via go_router. Works for recorded sessions; manual entries have no DB row and land on an error screen — see [Interactions](#interactions) |
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
| **No user** | `updateUserId(null)` (logout) | Both the combined list and the manual entries are cleared and listeners notified; each tab falls through to its own empty state |

> Note: Only the loading and error states are handled inside the `Consumer<ProgressProvider>`. The empty state is handled within each tab widget (`ActivitiesTab` / `StatisticsTab`), which renders its own empty message when `provider.activities` is empty.

> Note: The current implementation uses plain `CircularProgressIndicator` / `Text` widgets for the loading and error states rather than the shared `LoadingWidget` / `ErrorDisplayWidget`. The error state shows "Tap to retry" text but does not wire up a dedicated retry button.

> Note: Manual entries are cleared from memory on logout but are **never deleted from `SharedPreferences`**, so they reappear for the next user signing in on the same device. **Status: known gap.**

## User Interface

The screen is a `Scaffold` with a green AppBar titled "Progress" that carries a `TabBar` (`STATISTICS` / `ACTIVITIES`), a `TabBarView` body, and an "EARNED SO FAR" bar as the `bottomNavigationBar`.

### Activities tab

Activities are grouped under date section headers (`TODAY`, `YESTERDAY`, `THIS WEEK`, `OLDER`). Each list item (`ActivityListItem`) shows a generic activity icon, the activity type, the formatted date, the distance, and the duration. The activity type is rendered verbatim, so recorded sessions appear lower-case (`running`, `cycling`) — `ActivityType.displayName` exists but is not used here.

```
┌─────────────────────────────────────────────────┐
│  Progress         [ STATISTICS | ACTIVITIES ]    │
│                                                  │
│  TODAY                                            │
│  ┌───────────────────────────────────────────┐  │
│  │ [icon] running               5.20 km      │  │
│  │        18.02.2026, 08:30     00:32:15     │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  YESTERDAY                                        │
│  ┌───────────────────────────────────────────┐  │
│  │ [icon] cycling              15.80 km      │  │
│  │        17.02.2026, 17:45     00:45:30     │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ─────────────────────────────────────────────  │
│  EARNED SO FAR                          12.50 €  │
└─────────────────────────────────────────────────┘
```

### Statistics tab

Shows three summary cards followed by five hand-drawn charts, in this order: weekly distance (bar), weekly duration (line), monthly distance (bar), monthly duration (line), yearly distance (bar). There is no charting package — `CustomBarChart` stacks `Positioned` containers and `CustomLineChart` delegates to a `CustomPainter` (`LineChartPainter`).

**Summary cards.** "This Week" and "This Month" show total distance (`X.X km`) over total duration (`HH:MM:SS h`); "Total" inverts this, showing duration (`Xh Ym`) over `N sessions`, and is tinted dark grey rather than green. Only the Total card comes from the provider (`getTotalStats()`) — the week and month figures are computed inside `ProgressSummary` itself, where "this week" means Monday 00:00 of the current week and "this month" the 1st of the current month.

**Chart → provider mapping.**

| Chart | Provider method | Return shape |
|-------|-----------------|--------------|
| Weekly distance (bar) | `getDistancePerWeekday()` | `Map<int, double>` km, keys 1 = Mon … 7 = Sun |
| Weekly duration (line) | `getDurationPerWeekdayMinutes()` | `Map<int, double>` minutes, keys 1-7 |
| Monthly distance (bar) | `getDistancePerMonth()` | `Map<String, double>` km, keys `'YYYY-MM'` |
| Monthly duration (line) | `getDurationPerMonth()` | `Map<String, double>` minutes, keys `'YYYY-MM'` |
| Yearly distance (bar) | `getDistancePerYear()` | `Map<int, double>` km, keys 1-6 (chart index, not the year) |
| Total card | `getTotalStats()` | `Map<String, dynamic>` with `distanceKm`, `durationHours`, `durationSeconds`, `sessions` |

Entries with a null or non-positive distance / duration are skipped by the per-weekday and per-month aggregations; `getTotalStats()` counts every activity.

**Time windows.** The two monthly charts cover **only the current calendar year**: `StatisticsTab` builds a fixed 12-slot map keyed `'<currentYear>-MM'` and labels the months `Jan`–`Dec` via `DateFormat('MMM')`. Data from earlier years is aggregated by the provider but never displayed, and an all-zero year is replaced by the plain text "No distance recorded this year." / "No duration recorded this year." The yearly chart is a fixed **six-year** window (the current year and the five before it, zeros included), re-keyed to chart indices 1-6 with the year labels reconstructed from the map length, titled "Yearly Distance (km) - Last 6 Years". Because that map is never empty, the "No yearly distance data available." branch is unreachable in practice.

> ⚠️ The weekday axis labels are hard-coded **German** — `Mo, Di, Mi, Do, Fr, Sa, So` — in two independent places: the `labels` map passed to the weekly duration line chart, and the `defaultWeekdays` fallback inside `CustomBarChart` used by the weekly distance chart. Everything else on this screen is English and the month labels are locale-driven via `DateFormat('MMM')`. Both lists have to be changed together. **Status: known i18n gap.**

## Data Flow

`ProgressProvider.loadActivities()` is **not** called from the constructor — the constructor is deliberately async-free so the provider stays unit-testable. It runs when the user id changes (`updateUserId`, driven by the `ChangeNotifierProxyProvider` in `main.dart` and re-asserted from `ProgressScreen.initState`), when the Progress tab is opened (`MainNavigationScreen._onTabTapped`, index 1), and after a recorded activity is deleted. An opt-in `initialize()` helper also exists on the provider but currently has **no call site**. The load itself first awaits the manual entries from `SharedPreferences`, then fetches sessions from the `SessionRepository`, keeps only `completed` sessions, converts them to `ActivityEntry` objects (metres → km, seconds → `Duration`, `activityType.name`), combines them with the manual entries, and sorts newest-first.

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

> ⚠️ The error branch's fallback is currently **invisible**. On a repository failure `loadActivities` sets `_error` *and* rebuilds the combined list from the manual entries alone, but the screen checks `provider.error != null` before building the `TabBarView` and returns a bare error `Text`, so the fallback list is never rendered. The "Tap to retry" text is not attached to any gesture handler either; clearing the error needs a fresh `loadActivities()` from the tab bar or a user change. **Status: known gap.**

> If `loadActivities()` runs while no user is signed in, it loads the manual entries from `SharedPreferences`, then clears the combined list and returns early without querying the repository — no error is raised and the tabs simply show their empty states.

## Activity Information

Each `ActivityEntry` displayed in the list shows:
- **Activity Type:** A free-form string. Recorded sessions use the `ActivityType.name` (e.g. `running`); manual entries are stored as `'Manual Entry'`.
- **Date:** Formatted as `dd.MM.yyyy, HH:mm` and grouped under date headers (Today / Yesterday / This Week / Older).
- **Distance:** Always in kilometres with 2 decimals (e.g. `5.20 km`), or `--` when missing.
- **Duration:** Formatted as `HH:MM:SS`, or `--` when missing.

## Interactions

| Action | Result |
|--------|--------|
| **Tap recorded activity** | Opens `SessionDetailScreen` for that session |
| **Tap manual activity** | Also pushes `/session/<uuid>`, but manual entries live only in `SharedPreferences` and have no DB row, so `SessionDetailScreen` renders `Error: Exception: Session not found: …` — **a known gap** |
| **Add manual entry** *(not yet wired)* | Intended to open the manual-entry dialog (duration & distance required) |
| **Edit manual entry** *(not yet wired)* | Intended to re-open the dialog pre-filled with the entry's values |
| **Delete activity** *(not yet wired)* | Intended to remove the entry (and delete the session from the DB for recorded activities) |
| **Switch tab** | Toggles between the Statistics and Activities tabs |

> Note: Manual add/edit/delete are **not wired** — not reachable from the UI at all. Every list item routes its tap to `_openSessionDetails` → `SessionDetailScreen`, and there is no Add button or FAB that triggers `onAddManualTap`. The supporting pieces exist but are not connected: the provider exposes `addActivity` / `updateActivity` / `removeActivity`, and the screen still contains the manual-entry dialog (`_showManualEntrySimulatedDialog`) and an action-dialog handler (`_handleTapOrSwipeAction`), but the latter is dead code that is never invoked (it carries an explicit `// ignore: unused_element` marker).

> Note: Two callback seams for those missing entry points already exist. `ActivitiesTab.onAddManualTap` is a *required* parameter that the screen does supply, but `ActivitiesTab.build` never invokes it — there is no Add button or FAB. Separately, `ActivitiesTab.onLongPress` is optional and is already forwarded to every `ActivityListItem` in all four date sections and on to `InkWell.onLongPress`, but `ProgressScreen` never passes it, so long-press is inert. Passing `_handleTapOrSwipeAction` as `onLongPress` is the smallest change that would revive the edit/delete dialog.

> Note: There is no pull-to-refresh in the current implementation. Data is reloaded automatically when the Progress tab is opened and when the active user changes.

## Provider Pattern Example

The Progress Screen demonstrates:
1. State management with Provider (`ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>`)
2. Loading and error states via `Consumer<ProgressProvider>` (with empty and success states resolved inside each tab widget)
3. Combining a remote/DB source with a local `SharedPreferences` source
4. List building and hand-drawn chart rendering from provider-derived data (note that `ProgressSummary` derives its "This Week" / "This Month" figures itself and only asks the provider for the totals)

## Tests

`test/widget/screens/progress_screen_test.dart` (5 widget tests, driven through `MainNavigationScreen` via the shared `pumpApp` harness) covers:

- the Statistics empty state ("Perform activities to see statistics.")
- the Activities empty state ("No activities yet.")
- a seeded 30-day-old completed session appearing under the `OLDER` header as `running` / `5.00 km` / `00:30:00`, and its tap pushing `SessionDetailScreen`
- the three summary card titles plus the `Weekly Distance (km)` chart title
- the `EARNED SO FAR` bar rendering `12.50 €`

Axis labels are canvas-painted and are deliberately not asserted. Renaming any of these user-visible strings breaks the suite.

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](./ACTIVITY_SCREEN_OVERVIEW.md) |
| Profile Screen | [PROFILE_SCREEN_PLAN.md](../../lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) | [PROFILE_SCREEN_OVERVIEW](./PROFILE_SCREEN_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
