---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [ACTIVITY_SCREEN Overview](./ACTIVITY_SCREEN_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
>
> **Last verified against code:** 2026-10-09 (branch `feat/live-map-and-stats`)
---

# Progress Screen Overview

## Purpose

The Progress Screen shows the user's activity history and statistics. It combines completed workout sessions from the local database with manually entered activities (stored in `SharedPreferences`). It serves as the primary example for implementing the Provider pattern with loading states, error handling, list displays, and chart visualisations.

The screen is organised into two tabs (`STATISTICS` and `ACTIVITIES`) driven by a `TabBar` in the AppBar.

## Key Features

| Feature | Description |
|---------|-------------|
| **Two Tabs** | `STATISTICS` (summary, activity dose & charts) and `ACTIVITIES` (history list) |
| **Statistics Charts** | Five hand-drawn charts (no charting package): weekly distance & duration (current calendar week only), monthly distance & duration (current calendar year only), yearly distance (fixed 6-year window), plus three summary cards |
| **Activity Dose** | `ActivityDoseCard`: this week's MET-hours as a share of the WHO recommendation, plus the preliminary "independent years" model estimate — see [Statistics tab](#statistics-tab) |
| **Activity List** | Activities grouped by date (Today / Yesterday / This Week / Older) |
| **Manual Entry** *(planned)* | Add, edit, and delete manual activities via a dialog — provider methods and dialog code exist but are not yet wired to a UI entry point |
| **Session Details** | Tapping any activity pushes `/session/<id>` via go_router. Works for recorded sessions; manual entries have no DB row and land on an error screen — see [Interactions](#interactions) |
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

The screen is a `Scaffold` with a green AppBar titled "Progress" that carries a `TabBar` (`STATISTICS` / `ACTIVITIES`) and a `TabBarView` body.

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
└─────────────────────────────────────────────────┘
```

### Statistics tab

Top to bottom: the three summary cards (`ProgressSummary`), then the **`ActivityDoseCard`**, then five hand-drawn charts in this order: weekly distance (bar), weekly duration (line), monthly distance (bar), monthly duration (line), yearly distance (bar). There is no charting package — `CustomBarChart` stacks `Positioned` containers and `CustomLineChart` delegates to a `CustomPainter` (`LineChartPainter`).

**Summary cards.** "This Week" and "This Month" show total distance (`X.X km`) over total duration (`HH:MM:SS h`); "Total" inverts this, showing duration (`Xh Ym`) over `N sessions`, and is tinted dark grey rather than green. The Total card comes from the provider (`getTotalStats()`); "This Week" sums the activities for which `provider.isInCurrentWeek(startTime)` is true (the shared week window, see *Time windows*); only the month figure is still computed inside `ProgressSummary` itself, from the 1st of the current month.

**Activity dose card** (`widgets/activity_dose_card.dart`, header "ACTIVITY THIS WEEK"). Shows this week's activity dose in MET-hours (`getMetHoursThisWeek()`) as a percentage of the WHO recommendation — 150 min of moderate activity at 4.5 MET = **11.25 MET-hours** — with a progress bar and the line "`X.X` of 11.25 MET-hours · `Xh Ym` recorded". Below the recommendation the percentage never rounds up to "100 %". The "INDEPENDENT YEARS · MODEL" part turns the dose into a sentence in **independent months** (years without permanent Austrian long-term care allowance) from the thesis model table for start age 40, always with its band: the women or men row by profile gender, otherwise both. The dose is capped at 22.5 MET-hours (twice the recommendation, noted in the sentence), and below 2 MET-hours no number is shown. The info button opens a dialog with the definitions, the counting rules and the limits (population averages from observational studies, not a personal forecast; all figures preliminary). The MET values and the model table live in the pure-Dart helper `ActivityDose` (`lib/features/session/utils/activity_dose.dart`):

| Activity | MET |
|----------|-----|
| Walking, hiking | 4.0 |
| Cycling | 6.8 (0 above 40 km/h) |
| Swimming, strength, yoga, dancing, martial arts, team sports | 4.5 (moderate) |
| Running, trail running, other types, `'Manual Entry'` | by average speed: below 2 km/h → 0, 2 to < 7 km/h → 4.0 (walking), 7–25 km/h → 9.0 (running, an assumption: 2 × moderate), above 25 km/h → 0; no distance → 4.0 |

The speed rule exists because the app records every session as `running`; its thresholds are app-level assumptions, not thesis values.

**Chart → provider mapping.**

| Chart | Provider method | Return shape |
|-------|-----------------|--------------|
| Weekly distance (bar) | `getDistancePerWeekday()` | `Map<int, double>` km, keys 1 = Mon … 7 = Sun |
| Weekly duration (line) | `getDurationPerWeekdayMinutes()` | `Map<int, double>` minutes, keys 1-7 |
| Monthly distance (bar) | `getDistancePerMonth()` | `Map<String, double>` km, keys `'YYYY-MM'` |
| Monthly duration (line) | `getDurationPerMonth()` | `Map<String, double>` minutes, keys `'YYYY-MM'` |
| Yearly distance (bar) | `getDistancePerYear()` | `Map<int, double>` km, keys 1-6 (chart index, not the year) |
| Total card | `getTotalStats()` | `Map<String, dynamic>` with `distanceKm`, `durationHours`, `durationSeconds`, `sessions` |
| Activity dose card | `getMetHoursThisWeek()` — sums `ActivityDose.metHoursForEntry` over this week's activities; the "recorded" time is the sum of `getDurationPerWeekdayMinutes()` | `double` MET-hours |
| Week window ("This Week" card, dose card, weekly charts) | `isInCurrentWeek(DateTime)` | `bool` |
| Dose model (helper, no provider state) | `ActivityDose.metForEntry` / `metHoursForEntry` / `estimateGainMonths(metHours, ModelSex)` / `modelSexForGender` | MET, MET-hours, `GainEstimate?` (`months`, `low`, `high`, `capped`; `null` below 2 MET-hours) |

Entries with a null or non-positive distance / duration are skipped by the per-weekday and per-month aggregations; `getTotalStats()` counts every activity.

**Time windows.** One shared **calendar-week** window, `ProgressProvider.isInCurrentWeek`, runs from Monday 00:00 local time up to (not including) the next Monday. It drives the two weekly charts, `getMetHoursThisWeek()` and the "This Week" summary card, so they always agree on the week. Before the activity-dose work the weekly charts summed every activity ever recorded per weekday. An empty week keeps both weekly chart titles and shows "No activity recorded this week yet." under each instead of an all-zero chart. The two monthly charts cover **only the current calendar year**: `StatisticsTab` builds a fixed 12-slot map keyed `'<currentYear>-MM'` and labels the months `Jan`–`Dec` via `DateFormat('MMM')`. Data from earlier years is aggregated by the provider but never displayed, and an all-zero year is replaced by the plain text "No distance recorded this year." / "No duration recorded this year." The yearly chart is a fixed **six-year** window (the current year and the five before it, zeros included), re-keyed to chart indices 1-6 with the year labels reconstructed from the map length, titled "Yearly Distance (km) - Last 6 Years". Because that map is never empty, the "No yearly distance data available." branch is unreachable in practice.

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
4. List building and hand-drawn chart rendering from provider-derived data (note that `ProgressSummary` still derives its "This Month" figure itself; for "This Week" it uses the provider's `isInCurrentWeek`, and the totals come from `getTotalStats()`)

## Tests

| File | Level | Covers |
|------|-------|--------|
| `test/features/session/utils/activity_dose_test.dart` | Unit (pure Dart) | `ActivityDose`: the speed rule (running, walking, stationary/GPS drift, vehicle, no distance), the fixed MET values per type (walking/hiking, cycling incl. the 40 km/h cut-off, moderate sports), MET-hours = MET × active hours, and `estimateGainMonths` — no number below 2 MET-hours, the women/men rows at the support points, linear interpolation, rounding to whole months, the cap at 22.5 MET-hours — plus `modelSexForGender` |
| `test/unit/providers/progress_provider_test.dart` | Unit | The weekly statistics of `ProgressProvider`: `getMetHoursThisWeek` (this week only, manual entries included), `getDistancePerWeekday` / `getDurationPerWeekdayMinutes` counting only this week, the week boundary (Monday 00:00 inclusive, next Monday exclusive, also via `isInCurrentWeek`), and an empty week |
| `test/widget/screens/progress_screen_test.dart` | Widget, driven through `MainNavigationScreen` via the shared `pumpApp` harness | The Statistics and Activities empty states ("Perform activities to see statistics." / "No activities yet."); a seeded 30-day-old session under `OLDER` as `running` / `5.00 km` / `00:30:00` whose tap pushes `SessionDetailScreen`; the three summary card titles plus the `Weekly Distance (km)` chart title; the dose card — share of the recommendation and both model rows, never "100 %" below the recommendation, the profile-gender row, no model number below 2 MET-hours, the cap at twice the recommendation, the info dialog; both weekly chart titles with "No activity recorded this week yet." in an empty week |

Axis labels are canvas-painted and are deliberately not asserted. Renaming any of the asserted user-visible strings breaks the suite.

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](./ACTIVITY_SCREEN_OVERVIEW.md) |
| Profile Screen | [PROFILE_SCREEN_PLAN.md](../../lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) | [PROFILE_SCREEN_OVERVIEW](./PROFILE_SCREEN_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
