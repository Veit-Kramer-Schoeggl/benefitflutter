---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [SEED_OVERVIEW.md](../../../documentation/data/SEED_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../database/DATABASE.md) | [FEATURES.md](../../features/FEATURES.md)
---

# Database Seeding for Development

## Overview

The BeneFit app automatically seeds the SQLite database with test data on first launch in debug mode. This ensures all team members have the same baseline data for development and testing.

## How It Works

### Automatic Seeding Process

1. **App Launch** - When you run the app in debug mode
2. **Check Debug Mode** - Only runs if `kDebugMode` is true (production safe)
3. **Check Seed Flag** - Looks in SharedPreferences: "has been seeded?"
4. **Seed Database** - If not seeded, inserts test data via repositories and DAOs:
   - **Users** → 2 test accounts (Test Developer + Sarah Runner)
   - **Benefits** → 4 reward templates (€5, €10, €20, €50)
   - **Sessions** → 10 activity sessions (9 completed + 1 active)
   - **UserBenefits** → 2 earned benefits (€5 and €10 rewards unlocked)
   - Plus GPS points, biometrics, preferences, wearable devices, sensor data, summaries, and health platform data (see Test Data Included)
5. **Mark as Seeded** - Sets flag in SharedPreferences
6. **Continue Startup** - App launches normally with test data

### Key Features

- **Debug-Only**: Never runs in production builds
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
- **Date of Birth**: 1990-05-15 (35 years old) (v3)
- **Timezone**: Europe/Vienna (v3)

**User 2 (test-user-321):**
- **Name**: Sarah Runner
- **Email**: test2@gmail.com
- **Display Name**: Sarah (v3)
- **Gender**: female (v3)
- **Date of Birth**: 1995-08-22 (30 years old) (v3)
- **Timezone**: Europe/Berlin (v3)

Both users share the default password `1234` (stored hashed via `PasswordUtils.hashPassword`).

### 4 Benefits (Reward Templates)
- €5 Discount - Complete 5 sessions
- €10 Discount - Run 10km total
- €20 Discount - Complete 20 sessions
- €50 Discount - Run 100km total

### 10 Sessions (Activity History)
- User 1: 5 completed sessions (running, walking, cycling) + 1 active session
- User 2: 4 completed sessions (yoga, running, walking, cycling)
- Dates: Last 7 days with realistic distances and durations, relative to `DateTime.now()`
- 1 active session (for testing Activity screen)

### 8 GPS Points (Tracking Data)
- GPS tracking points for session-1 (5km run)
- Realistic route through Berlin with timestamps
- Includes altitude, accuracy, and speed data
- Points spaced throughout 30-minute run

### 2 User Benefits (Earned Rewards)
- User 1: €5 reward unlocked (on session-5)
- User 2: €10 reward unlocked (on session-u2-4)

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
static const String seedFlagKey = 'database_seeded_v5'; // Changed from v4
```
Restart app → Re-seeds with updated data

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

The debug reseed system consists of two components working together: a backend service method and a UI button that triggers it. When activated, the system clears the SharedPreferences seed flag and forces a fresh database seeding operation, completely repopulating all test data.

The UI button is intelligently hidden in production builds through debug mode detection, ensuring it's only visible during development. This provides a safe, convenient way to reset data without risk of accidental triggers in release builds.

#### Where to Find It

The reseed button is located at the bottom of the Benefits screen under a "Developer Tools" section. This section only appears when running the app in debug mode. The button is clearly labeled with an orange warning theme to indicate it's a developer tool. A second debug-only "Reset Test Data" button is also available on the Login screen (below the Create Account button), useful for reseeding before signing in.

#### Using the Reseed Feature

To reset seed data using the UI button, navigate to the Benefits screen in your app. If running in debug mode, scroll to the bottom where you'll find the Developer Tools section with an orange "Reset Seed Data" button.

When you tap the button, a confirmation dialog appears explaining what will happen: the seed flag will be cleared, the database will be repopulated with test data, and any existing data will be overridden. This action cannot be undone, so the confirmation step prevents accidental data loss.

After confirming, the app displays a loading indicator while the reseed operation runs. This typically takes less than a second, but the UI provides feedback during the process. When complete, a success message appears showing what data was seeded, and the Benefits screen automatically refreshes to display the new data.

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

**Debug Mode Only**: The reseed button only appears when running in debug builds. Production builds have no access to this functionality through either UI or code paths.

**Confirmation Dialog**: Before executing, the system requires explicit user confirmation through a dialog explaining the consequences. This prevents accidental triggers from misclicks or UI exploration.

**Loading Feedback**: During the reseed operation, clear visual feedback shows the process is running, preventing users from thinking the app has frozen or attempting to trigger it multiple times.

**Error Handling**: If the reseed operation fails for any reason, the app displays a clear error message and continues running normally. Failed reseeds don't crash the app or leave it in a broken state.

**Automatic UI Refresh**: After successful reseeding, affected screens automatically refresh to show the new data, ensuring the UI stays in sync with the database state.

#### Technical Details

Under the hood, the debug reseed system uses a dedicated service method that first removes the SharedPreferences seed flag, then calls the standard database seeding logic. This ensures reseeding follows the exact same validation and data insertion paths as the initial seed, maintaining consistency.

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
├── seed_service.dart   # Orchestrates seeding process
└── SEED.md            # This documentation
```

## Updating Seed Data

To change the baseline test data for all developers:

1. Edit `lib/core/seed/seed_data.dart`
2. Modify the test data in the getter methods
3. Increment seed version in `seed_config.dart`:
   ```dart
   static const String seedFlagKey = 'database_seeded_v5';
   ```
4. Commit and push changes
5. Team members will auto-reseed on next launch

## Configuration Options

### seed_config.dart

```dart
// Master switch - debug mode only
static bool get isEnabled => kDebugMode;

// Version control for re-seeding
static const String seedFlagKey = 'database_seeded_v4';

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

## Console Output Example

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
[SeedService]   ✓ Created session: running - 5.0km (completed)
[SeedService]   ✓ Created session: walking - 4.0km (completed)
[SeedService]   ✓ Created session: cycling - 15.0km (completed)
[SeedService]   ✓ Created session: running - 7.5km (completed)
[SeedService]   ✓ Created session: walking - 3.0km (completed)
[SeedService]   ✓ Created session: running - N/A (active)
[SeedService]   ✓ Created session: yoga - N/A (completed)
[SeedService]   ✓ Created session: running - 6.0km (completed)
[SeedService]   ✓ Created session: walking - 2.5km (completed)
[SeedService]   ✓ Created session: cycling - 35.0km (completed)
[SeedService] 📍 Seeding GPS points...
[SeedService]   ✓ Created GPS point: 52.5200, 13.4050
[SeedService]   ... (8 points total)
[SeedService] ⌚ Seeding wearable devices...
[SeedService]   ✓ Created device: Polar H10 (...)
[SeedService]   ... (4 devices total)
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
[SeedService] ✅ Seeding completed in 245ms
[SeedService] 📊 Seed Summary:
[SeedService]    Users: 2
[SeedService]    User Biometrics: 5
[SeedService]    User Preferences: 2
[SeedService]    Benefits: 4
[SeedService]    Sessions: 10
[SeedService]    GPS Points: 8
[SeedService]    Wearable Devices: 4
[SeedService]    Biometric Sensor Data: 16
[SeedService]    Motion Sensor Data: 8
[SeedService]    Sensor Summaries: 2
[SeedService]    Health Platform Data: 28
[SeedService]    User Benefits: 2
[SeedService]    Total Distance: 78.0km
[SeedService]    Total Duration: 475 minutes
```

## Troubleshooting

### Seeding Not Running?
- Check console for `[SeedService]` logs
- Verify running in debug mode (not release)
- Check `seed_config.dart` - `isEnabled` should be `true`

### Need to Re-seed?
- Change `seedFlagKey` version number
- Or set `forceReseed = true` temporarily

### Seeding Failed?
- Check console error messages
- App will still launch (non-blocking)
- Verify repository implementations are working

## Production Safety

The seed service has multiple safeguards:

1. **kDebugMode Check** - Only runs in debug builds (`clearAndReseed()` even throws if called outside debug mode)
2. **SharedPreferences Flag** - One-time execution
3. **Non-Blocking** - App launches even if seeding fails
4. **Debug-Gated UI** - The reseed Developer Tools UI is wrapped in `kDebugMode` checks, so it never appears in production builds

Production builds automatically exclude debug code, making it impossible for seeding to run in release mode.
