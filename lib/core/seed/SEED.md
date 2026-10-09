---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [SEED_OVERVIEW.md](../../../documentation/data/SEED_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../database/DATABASE.md) | [FEATURES.md](../../features/FEATURES.md)
>
> **Last verified:** 2026-10-09 against `lib/core/seed/` on branch `feat/live-map-and-stats`
---

# Database Seeding for Development

## Overview

The BeneFit app automatically seeds the SQLite database with test data on first launch whenever the seed gate is on - debug builds by default, overridable at build time via the `SEED_ENABLED` dart-define (see [Build-time gate](#build-time-gate-seed_enabled)). This ensures all team members have the same baseline data for development and testing.

## How It Works

### Automatic Seeding Process

1. **App Launch** - When you run the app in debug mode
2. **Check Seed Gate** - Only runs if `SeedConfig.isEnabled` is true (`lib/main.dart:102`). That getter delegates to `AppConfig.seedEnabled` (`lib/core/config/app_config.dart:35-37`), which returns the `SEED_ENABLED` dart-define when one is supplied and otherwise falls back to `kDebugMode`. `config/dev.json` sets `SEED_ENABLED: true`; `config/staging.json` and `config/prod.example.json` set it to `false`
3. **Check Seed Flag** - Reads the SharedPreferences bool `database_seeded_v5` (`seed_config.dart:11`, read at `seed_service.dart:382`)
4. **Seed Database** - If not seeded, inserts test data: users and awarded benefits through their repositories, everything else straight through the DAOs (sessions and GPS points in batches):
   - **Users** → 2 test accounts (Test Developer + Sarah Runner)
   - **Benefits** → 4 reward templates (€5, €10, €20, €50)
   - **Sessions** → the hand-written last week (9 completed + 1 active) plus years of generated history since 2021 (`seed_history.dart`), about 1,400 in total, written in batches straight through `SessionDao.insertBatch`
   - **GPS points** → a route for every distance session of the last four weeks, about 3,000 points, via `GpsPointDao.insertBatch`
   - **UserBenefits** → 2 earned benefits (€5 and €10 rewards unlocked)
   - Plus biometrics, preferences, wearable devices, sensor data, summaries, and health platform data (see Test Data Included)
5. **Mark as Seeded** - Sets flag in SharedPreferences
6. **Continue Startup** - App launches normally with test data

### Key Features

- **Debug-Only by Default**: Gated by `SeedConfig.isEnabled`; with no `SEED_ENABLED` dart-define this is `kDebugMode`, so release builds do not seed (see [Production Safety](#production-safety))
- **One-Time**: Seeds once, then skips on subsequent launches
- **Non-Blocking**: App starts even if seeding fails
- **Uses Repositories & DAOs**: Users, sessions and awarded benefits go through repositories; other entities are inserted via their DAOs
- **Detailed Logging**: Console output shows seeding progress

## Test Data Included

### 2 Test Users (v3 - Extended)

**User 1 (test-user-123):**
- **Name**: Test Developer
- **Email**: test@gmail.com
- **Display Name**: Dev Tester (v3)
- **Gender**: male (v3)
- **Date of Birth**: 1990-05-15 (v3)
- **Timezone**: Europe/Vienna (v3)

**User 2 (test-user-321):**
- **Name**: Sarah Runner
- **Email**: test2@gmail.com
- **Display Name**: Sarah (v3)
- **Gender**: female (v3)
- **Date of Birth**: 1995-08-22 (v3)
- **Timezone**: Europe/Berlin (v3)

Both users share the default password `1234` (stored hashed via `PasswordUtils.hashPassword`).

### 4 Benefits (Reward Templates)
- €5 Discount - Complete 5 sessions
- €10 Discount - Run 10km total
- €20 Discount - Complete 20 sessions
- €50 Discount - Run 100km total

### Sessions (Activity History)

Two layers, so the Progress statistics (yearly, monthly and weekly charts,
totals, the activity-dose card, the Activities list) all have data:

- **Last week, hand-written** (`seed_data.dart`, `getSessions`), at plausible
  times of day, `session-1`..`session-5` and `session-u2-1`..`session-u2-4`.
  User 1 also has `session-active` (status active, for the Activity screen).
  Their ids are referenced by user benefits and sensor data, so they stay.
- **History, generated** (`seed_history.dart`, `SeedHistory.sessions`) from
  2021-01-01 up to eight days ago, plus one session early this morning per
  user (a run for user 2 at 06:45, a walk for user 1 at 07:15) when the seed
  runs at 08:30 or later. The TODAY group and the current week then have data
  even on a Monday; only a seed before 08:30 on a Monday leaves the week empty.

| | User 1 · Test Developer (Vienna) | User 2 · Sarah Runner (Berlin) |
|---|---|---|
| Story | walker in 2021, now a regular runner and cyclist | runs most days, long runs on Sundays, yoga, rides, hikes |
| Sessions | about 560 | about 840 |
| km per year | about 300 (2021) rising to 1,200 (2025) | about 1,200 (2021) rising to 2,000 (2025) |

The generator walks the calendar day by day with a fixed-seed `Random`, so a
past day always gets the same session; only the end of the window moves with
`now`. It adds seasons (quiet winters, little cycling in Dec-Feb), one or two
breaks a year, weekday preferences, morning or evening slots on weekdays and
late mornings on weekends, and a slowly improving pace. Volumes are kept inside
what the charts can render: every year from 2021 has distance (the yearly chart
spans six years), no year approaches the ~7,000 km at which the y-axis would
need a 5-digit label, and running stays between 7 and 25 km/h, the band that
`ActivityDose` scores as vigorous. `test/core/seed/seed_history_test.dart`
guards all of this.

### GPS Routes (last four weeks)
- Every completed distance session that started in the last 28 days gets a
  route, hand-written ones included (`SeedHistory.routesFor`)
- Closed loops starting at a park in the user's city (the city of their
  seeded preferences, mapped in `SeedHistory._cityFor`): Prater, Donauinsel and
  Schönbrunn in Vienna; Tiergarten, Tempelhofer Feld and Treptower Park in
  Berlin. Long rides loop through the wider city
- Resampled to about one point every 120 m (24-160 per route); the route length
  matches `distanceMeters` within a few percent and the timestamps span
  `durationSeconds`
- Altitude, accuracy (3-9 m) and speed per point; ids are `gps-<sessionId>-<n>`

### 2 User Benefits (Earned Rewards)
- User 1: €5 reward unlocked (on session-5)
- User 2: €10 reward unlocked (on session-u2-4)

These two rows are **not inserted verbatim**. They are awarded through `BenefitRepository.awardBenefit(userId:, benefitId:, sessionId:)` (`seed_service.dart:298`), and that implementation mints a fresh id and sets `earnedAt: DateTime.now()` (`lib/features/benefit/data/benefit_repository_impl.dart:60, 64`) - so the `ub-1` / `ub-2` ids and the back-dated `earnedAt` values in `seed_data.dart:249-263` never reach the database. The seed deliberately awards only these two: the Benefit tab's "Total Savings this week" card sums all earned rewards, and more of them would push that placeholder far beyond a week's worth. (The minted id comes from the current millisecond, so two awards within the same millisecond overwrite each other and only one survives; rare on a phone.) The same call also uploads to the remote or queues a sync entry depending on connectivity (`benefit_repository_impl.dart:70-82`), so a seed run can leave rows in `sync_queue`.

### 5 User Biometrics Records (v3)
- **User 1, Entry 1** (30 days ago): 175cm, 72.5kg
- **User 1, Entry 2** (15 days ago): 175cm, 71.8kg (weight loss progress)
- **User 1, Entry 3** (2 days ago): 175cm, 71.2kg (continued progress)
- **User 2, Entry 1** (20 days ago): 165cm, 58.5kg
- **User 2, Entry 2** (3 days ago): 165cm, 58.0kg

### 2 User Preferences Records (v3)
- **User 1**: Vienna, metric, celsius, kg, system theme, en, Europe/Vienna
- **User 2**: Berlin, metric, celsius, kg, dark theme, de, Europe/Berlin

### 4 Wearable Devices (v4)
- **User 1**: Polar H10 (BLE heart rate monitor), Health Connect (virtual), Garmin Forerunner 245 (smartwatch, disconnected)
- **User 2**: Apple Watch Series 8 (HealthKit smartwatch)

### Biometric Sensor Data (v4)
- 16 data points for session-1 (9 heart-rate readings + 7 HRV readings), all from device-polar-h10

### Motion Sensor Data (v4)
- 8 data points for session-1 (7 cadence readings + 1 total-steps reading)

### 2 Sensor Summaries (v4)
- Aggregated per-session sensor data for session-1 and session-4

### Health Platform Data (v4)
- User 1: 16 points (7 daily steps + 7 resting heart rate + 1 weight + 1 VO2 max)
- User 2: 12 points (5 daily steps + 5 resting heart rate + 1 weight + 1 VO2 max)

## Developer Workflow

### First Time Setup
```
1. Clone repository
2. flutter pub get
3. Run app
   → Database automatically seeds
   → See console logs for confirmation
4. Start developing with consistent test data
```

### Daily Development
```
- App launches → Sees seed flag → Skips seeding → Fast startup
```

### Need Fresh Data?

**Option 1: Change Seed Version**
```dart
// In seed_config.dart
static const String seedFlagKey = 'database_seeded_v6'; // Changed from v5
```
Restart app → Re-seeds with updated data

Re-seeding replaces both test users, and with foreign keys on that cascades away everything recorded under `test@gmail.com` / `test2@gmail.com` (sessions, routes, benefits). Other accounts keep their data.

**Option 2: Force Reseed**
```dart
// In seed_config.dart
static const bool forceReseed = true; // Changed from false
```
Restart app → Re-seeds, then set back to `false`

**Option 3: Clean Install**
```
Uninstall app → Reinstall → Fresh seed
```

### Debug Reseed System (Recommended)

The BeneFit app includes a built-in debug reseed system that allows developers to reset seed data with a single button click, without modifying any code files. This is the most developer-friendly approach for handling seed data during development.

#### How It Works

The debug reseed system consists of two components working together: a backend service method and a UI button that triggers it. When activated, the system deletes every row from all 16 app tables, clears the SharedPreferences seed flag, and then runs the standard seeding logic - so any data you created by hand is destroyed along with the old seed rows.

The UI button is intelligently hidden in production builds through debug mode detection, ensuring it's only visible during development. This provides a safe, convenient way to reset data without risk of accidental triggers in release builds.

#### Where to Find It

The reseed button is located at the bottom of the Benefits screen under a "Developer Tools" section. This section only appears when running the app in debug mode. The button is clearly labeled with an orange warning theme to indicate it's a developer tool. A second debug-only "Reset Test Data" button is also available on the Login screen (below the Create Account button), useful for reseeding before signing in. That Login-screen variant also clears the stored auth tokens before reseeding (`SecureTokenStorage.clearTokens()`, `lib/presentation/screens/auth/login_screen.dart:150`), so you are signed out and must log in again; its success snackbar reads `Database reset successfully! Please log in again.` (`login_screen.dart:173`).

#### Using the Reseed Feature

To reset seed data using the UI button, navigate to the Benefits screen in your app. If running in debug mode, scroll to the bottom where you'll find the Developer Tools section with an orange "Reset Seed Data" button.

When you tap the button, a confirmation dialog appears explaining what will happen: the seed flag will be cleared, the database will be repopulated with test data, and any existing data will be overridden. This action cannot be undone, so the confirmation step prevents accidental data loss.

After confirming, the app displays a loading indicator while the reseed operation runs. This takes about a second on a phone (debug build), and the UI provides feedback during the process. When complete, a success snackbar appears with the user, session and GPS point counts from `SeedData.getSeedSummary()` (`benefit_screen.dart:73`), and the Benefits screen refreshes automatically.

#### When to Use It

The debug reseed system is ideal for several development scenarios:

**Database Cleared But Flag Remains**: When you've cleared app data or reinstalled the app but the SharedPreferences flag persisted, preventing automatic seeding. The button provides a quick fix without modifying code.

**Testing with Fresh Data**: When you need to reset to a clean baseline for testing new features or debugging issues. The button gives you instant access to fresh seed data.

**QA and Demo Preparation**: When preparing for demonstrations or QA testing sessions that require consistent starting data. A single button click ensures everyone starts from the same baseline.

**After Data Corruption**: If development testing has corrupted or invalidated your seed data, the reseed button provides a quick recovery path.

#### Alternative Methods Still Available

While the debug reseed button is the recommended approach, the traditional methods remain available for specific use cases:

The **Version Bump Method** remains useful for team-wide reseeding when you want all developers to automatically get fresh data on their next app launch. This is done by incrementing the seed version number in the configuration.

The **Force Reseed Flag** is still available for programmatic control or automated testing scenarios where you need to control seeding behavior through configuration rather than UI interaction.

The **Clean Install** option remains the nuclear approach when you want to completely reset everything, including SharedPreferences and all other app state, not just the seed data.

#### Safety Features

The debug reseed system includes multiple layers of protection:

**Debug Mode Only**: The reseed buttons are compiled out of release builds - the Benefits screen section is wrapped in `if (kDebugMode)` (`lib/presentation/screens/benefit/benefit_screen.dart:228`) and the Login screen button in `if (kDebugMode && SeedConfig.isEnabled)` (`lib/presentation/screens/auth/login_screen.dart:578`); note the two gates are not identical. The underlying **code path is not removed**, however: `SeedService.clearAndReseed()` is compiled into every build and only refuses when `SeedConfig.isEnabled` is false (`seed_service.dart:153-156`), so a release build made with `SEED_ENABLED=true` could still reseed if some other caller invoked it.

**Confirmation Dialog**: Before executing, the system requires explicit user confirmation through a dialog explaining the consequences. This prevents accidental triggers from misclicks or UI exploration.

**Loading Feedback**: During the reseed operation, clear visual feedback shows the process is running, preventing users from thinking the app has frozen or attempting to trigger it multiple times.

**Error Handling**: If the reseed operation fails for any reason, the app displays a clear error message and continues running normally. Failed reseeds don't crash the app or leave it in a broken state.

**Automatic UI Refresh**: After successful reseeding, affected screens automatically refresh to show the new data, ensuring the UI stays in sync with the database state.

#### Technical Details

Under the hood, `SeedService.clearAndReseed()` (`lib/core/seed/seed_service.dart:145-175`) runs three steps in order: (1) `DatabaseHelper.clearAllTables()` truncates 16 tables in a single transaction - `sync_queue`, `user_benefits`, `activity_segments`, `session_biometric_data`, `session_motion_data`, `session_sensor_summary`, `health_platform_data`, `wearable_devices`, `gps_points`, `continuous_tracking_state`, `sessions`, `continuous_tracking_config`, `user_biometrics_reported`, `user_preferences`, `benefits`, `users` (`lib/features/shared/database/database_helper.dart:827-860`); (2) the SharedPreferences flag `database_seeded_v5` is removed (`seed_service.dart:161`); (3) `seedDatabase()` re-inserts the test data through the exact same validation and insertion paths as the initial seed, maintaining consistency.

The UI integration uses Flutter's standard material design patterns with snackbars for feedback, dialogs for confirmation, and proper state management to prevent race conditions. The implementation is designed to be maintainable and extensible for future debug tools.

All console logging from the reseed operation follows the same format as standard seeding, making it easy to verify what data was created and troubleshoot any issues through the debug console.

#### Troubleshooting the Reseed Feature

If the reseed button doesn't appear, verify you're running the app in debug mode and you're on the Benefits screen. The button only shows at the very bottom, so make sure to scroll down to see the Developer Tools section.

If the reseed operation fails, check the console output for detailed error messages. The logging will show exactly where the process failed and why, helping you identify whether it's a database issue, permission problem, or something else.

If the app shows "already seeded" after clicking the button, the operation may have succeeded but the success message didn't display. Check the Database Inspector to verify data exists, or look for the seed completion logs in the console.

## File Structure

```
lib/core/seed/
├── seed_config.dart    # Configuration flags and settings
├── seed_data.dart      # All test data definitions
├── seed_history.dart   # Generated multi-year history and GPS routes
├── seed_service.dart   # Orchestrates seeding process
└── SEED.md            # This documentation
```

## Updating Seed Data

To change the baseline test data for all developers:

1. Edit `lib/core/seed/seed_data.dart` (fixed rows and the last week) or
   `lib/core/seed/seed_history.dart` (the personas behind the generated history)
2. Modify the test data in the getter methods, and run
   `flutter test test/core/seed/` to check the history stays plausible
3. Increment seed version in `seed_config.dart`:
   ```dart
   static const String seedFlagKey = 'database_seeded_v6';
   ```
4. Commit and push changes
5. Team members will auto-reseed on next launch (losing what they recorded with the test accounts, see above)

After editing `seed_history.dart`, hot-restart rather than hot-reload before pressing **Reset Seed Data**: the generated history is memoised per day in static state, which a hot reload keeps.

## Configuration Options

### seed_config.dart

```dart
import 'package:benefitflutter/core/config/app_config.dart';

// Master switch - delegated to AppConfig: returns the SEED_ENABLED
// dart-define when supplied, otherwise falls back to kDebugMode.
static bool get isEnabled => AppConfig.seedEnabled;

// Version control for re-seeding
static const String seedFlagKey = 'database_seeded_v5';

// Feature toggles
static const bool seedUsers = true;
static const bool seedBenefits = true;
static const bool seedSessions = true;
static const bool seedUserBenefits = true;
static const bool seedGpsPoints = true;
static const bool seedUserBiometrics = true; // v3
static const bool seedUserPreferences = true; // v3
static const bool seedWearableDevices = true; // v4
static const bool seedBiometricSensorData = true; // v4
static const bool seedMotionSensorData = true; // v4
static const bool seedSensorSummaries = true; // v4
static const bool seedHealthPlatformData = true; // v4

// Logging
static const bool verboseLogging = true;

// Force re-seed (temporary use only)
static const bool forceReseed = false;
```

### Build-time gate (`SEED_ENABLED`)

`SeedConfig.isEnabled` delegates to `AppConfig.seedEnabled` (`lib/core/config/app_config.dart:35-37`):

```dart
static bool get seedEnabled => const bool.hasEnvironment('SEED_ENABLED')
    ? const bool.fromEnvironment('SEED_ENABLED')
    : kDebugMode;
```

| Config file | `SEED_ENABLED` | Typical use |
|-------------|----------------|-------------|
| `config/dev.json` | `true` | `flutter run --dart-define-from-file=config/dev.json` |
| `config/staging.json` | `false` | staging builds |
| `config/prod.example.json` | `false` | template for the gitignored `config/prod.json` |

```bash
# Debug run with seeding on
flutter run --dart-define-from-file=config/dev.json

# Release build with seeding pinned off
flutter build appbundle --dart-define-from-file=config/prod.json
```

With no flag supplied the value const-folds to `kDebugMode`, so release tree-shaking is preserved and a forgotten flag resolves to seeding **off**. Conversely, launching a *debug* build with `--dart-define-from-file=config/staging.json` or `config/prod.json` disables seeding - the most common reason for "no test data appeared".

## Console Output Example

A seeding run of a debug build on a Xiaomi Mi 11i (Android 14), 2026-10-09 at 21:53
(the same output appears on a cold start after a seed-version bump):

```
[SeedService] 🌱 Starting database seeding...
[SeedService] 👤 Seeding users...
[SeedService]   ✓ Created user: Test Developer (test@gmail.com)
[SeedService]   ✓ Created user: Sarah Runner (test2@gmail.com)
[SeedService] ⚙️ Seeding user preferences...
[SeedService]   ✓ Created preferences: Vienna, metric
[SeedService]   ✓ Created preferences: Berlin, metric
[SeedService] 📊 Seeding user biometrics...
[SeedService]   ✓ Created biometric: 175cm, 72.5kg
[SeedService]   ✓ Created biometric: 175cm, 71.8kg
[SeedService]   ✓ Created biometric: 175cm, 71.2kg
[SeedService]   ✓ Created biometric: 165cm, 58.5kg
[SeedService]   ✓ Created biometric: 165cm, 58.0kg
[SeedService] 🎁 Seeding benefits...
[SeedService]   ✓ Created benefit: 5 Euro Discount (€5.0)
[SeedService]   ✓ Created benefit: 10 Euro Discount (€10.0)
[SeedService]   ✓ Created benefit: 20 Euro Discount (€20.0)
[SeedService]   ✓ Created benefit: 50 Euro Discount (€50.0)
[SeedService] 🏃 Seeding sessions...
[SeedService]   ✓ test-user-123: 557 sessions, 4999 km
[SeedService]   ✓ test-user-321: 836 sessions, 9652 km
[SeedService] 📍 Seeding GPS points...
[SeedService]   ✓ 3090 GPS points on 36 routes
[SeedService] ⌚ Seeding wearable devices...
[SeedService]   ✓ Created device: Polar H10 (Heart Rate Monitor)
[SeedService]   ✓ Created device: Health Connect (Unknown Device)
[SeedService]   ✓ Created device: Garmin Forerunner 245 (Smartwatch)
[SeedService]   ✓ Created device: Apple Watch Series 8 (Smartwatch)
[SeedService] 💓 Seeding biometric sensor data...
[SeedService]   ✓ Created 16 biometric data points
[SeedService] 🏃 Seeding motion sensor data...
[SeedService]   ✓ Created 8 motion data points
[SeedService] 📊 Seeding sensor summaries...
[SeedService]   ✓ Created summary: Avg HR: 155.5 BPM, Steps: 5200
[SeedService]   ✓ Created summary: Avg HR: 148.0 BPM, Steps: 7800
[SeedService] 🏥 Seeding health platform data...
[SeedService]   ✓ Created 28 health platform data points
[SeedService] 🏆 Seeding user benefits...
[SeedService]   ✓ Awarded benefit: benefit-5-euro
[SeedService]   ✓ Awarded benefit: benefit-10-euro
[SeedService] ✅ Seeding completed in 1056ms
[SeedService] 📊 Seed Summary:
[SeedService]    Users: 2
[SeedService]    User Biometrics: 5
[SeedService]    User Preferences: 2
[SeedService]    Benefits: 4
[SeedService]    Sessions: 1393
[SeedService]    GPS Points: 3090
[SeedService]    Wearable Devices: 4
[SeedService]    Biometric Sensor Data: 16
[SeedService]    Motion Sensor Data: 8
[SeedService]    Sensor Summaries: 2
[SeedService]    Health Platform Data: 28
[SeedService]    User Benefits: 2
[SeedService]    Total Distance: 14651.6km
[SeedService]    Total Duration: 83165 minutes
```

## Troubleshooting

### Seeding Not Running?
- Check console for `[SeedService]` logs
- Verify running in debug mode (not release)
- Check the seed gate: `SeedConfig.isEnabled` → `AppConfig.seedEnabled`. In a debug build with no dart-define it is `true`; if you launched with `--dart-define-from-file=config/staging.json` or `config/prod.json` (both `SEED_ENABLED: false`), seeding is off even in debug. Look for the log line `[SeedService] ❌ Seeding disabled (not in debug mode)` (`seed_service.dart:64, 88`)
- If the log says `✅ Database already seeded`, the SharedPreferences key `database_seeded_v5` is already set - use the Reset Seed Data button, bump the key, or set `forceReseed = true`

### Need to Re-seed?
- Change `seedFlagKey` version number
- Or set `forceReseed = true` temporarily

### Seeding Failed?
- Check console error messages
- App will still launch (non-blocking)
- Verify repository implementations are working

## Production Safety

The seed service has multiple safeguards:

1. **Seed Gate Check** - `seedIfNeeded()` and `seedDatabase()` return early, and `clearAndReseed()` throws `Exception('Reseed is only available in debug mode')`, whenever `SeedConfig.isEnabled` is false (`lib/core/seed/seed_service.dart:63, 87, 153-156`). `isEnabled` equals `kDebugMode` **unless** a `SEED_ENABLED` dart-define overrides it (`lib/core/config/app_config.dart:35-37`)
2. **SharedPreferences Flag** - One-time execution
3. **Non-Blocking** - App launches even if seeding fails
4. **Debug-Gated UI** - The reseed Developer Tools UI is wrapped in `kDebugMode` checks, so it never appears in production builds

Release builds default to seeding **off**: `AppConfig.seedEnabled` falls back to `kDebugMode` when no flag is supplied, and the Developer Tools UI is compiled out by `kDebugMode`. Seeding is *not* structurally impossible in release, though - a build made with `--dart-define=SEED_ENABLED=true` will seed. Always build releases with `--dart-define-from-file=config/prod.json` (or `config/staging.json`), which pin `SEED_ENABLED: false`.
