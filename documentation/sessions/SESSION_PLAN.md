---
> **Documentation Type:** IMPLEMENTATION PLAN (Sprint Breakdown)
>
> **Design Document:** [SESSION_DESIGN.md](./SESSION_DESIGN.md) - Full design details
>
> **Related:** [DATABASE.md](../../database/DATABASE.md) | [AUTH.md](../../AUTH.md)
>
> **Phase-2 Fahrplan:** [BACKGROUND_TRACKING_PLAN.md](./BACKGROUND_TRACKING_PLAN.md) — WP1–WP5 implement most of Sprint 4 and the notification part of Sprint 7 using geolocator's built-in foreground service (no own `foreground_service.dart`).
>
> **Last updated:** 2026-08-28 · code state = commit `fd7dfc1` (WP5) on `feat/phase-2-background-tracking`, 823 tests green
---

# Session & Tracking System - Implementation Plan

## Overview

This plan breaks down the Session & Tracking System design into implementable sprints with clear dependencies.

**Total Estimated Effort:** 12-16 weeks (depending on team size and parallel work)

**Prerequisites:** Manual session tracking (Phase 1) is already implemented.

---

## Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SPRINT DEPENDENCIES                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Sprint 1: Configuration ──────────┐                                    │
│                                    │                                    │
│  Sprint 2: Database Schema ────────┼──► Sprint 5: Continuous Core       │
│                                    │           │                        │
│  Sprint 3: Sensor Infrastructure ──┘           │                        │
│                                                │                        │
│  Sprint 4: Permissions & Background ───────────┼──► Sprint 7: BG Polish │
│                                                │                        │
│                                                ▼                        │
│                                    Sprint 6: Manual-Continuous          │
│                                                │                        │
│                                                ▼                        │
│                                    Sprint 9: Session Timeout            │
│                                                                          │
│  Sprint 8: Cross-Validation (can run in parallel after Sprint 3)       │
│                                                                          │
│  Future: Server Validation, Auto-Detection (after real-world data)     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Not in the graph above:** *Sprint 10 (Scoring Integration)* was added on 2026-08-28 — it depends on
Sprints 3 and 8 and is the sprint that finally makes the Sprint-1 scoring config do something. And
Sprint 4 shipped out of band as WP1–WP3 of
[BACKGROUND_TRACKING_PLAN.md](./BACKGROUND_TRACKING_PLAN.md); Sprint 7's notification came with WP2.

---

## Sprint 1: Configuration Foundation ✅

**Effort:** 3-4 days | **Priority:** High | **Dependencies:** None | **Status:** COMPLETE

Create centralized configuration files for all tunable parameters.

### Tasks

1. **Create TrackingConfig** ✅
   - File: `lib/core/config/tracking_config.dart`
   - Sensor trust multipliers
   - Anti-gaming filters (speed limits)
   - GPS intervals for manual/continuous
   - Activity type multipliers

2. **Create DeviceProfiles** ✅
   - File: `lib/core/config/device_profiles.dart`
   - Device override map (initially empty)
   - `getDeviceMultiplier()` method

3. **Create HrDeviceProfiles** ✅
   - File: `lib/core/config/hr_device_profiles.dart`
   - `HrDeviceType` enum
   - Chest strap pattern matching
   - `identifyDevice()` method
   - `getTrustMultiplier()` method

4. **Create StepValidationConfig** ✅
   - File: `lib/core/config/step_validation_config.dart`
   - Step length multipliers by activity
   - Gender/age adjustment factors
   - Z-score thresholds

### Deliverables

- [x] `lib/core/config/tracking_config.dart`
- [x] `lib/core/config/device_profiles.dart`
- [x] `lib/core/config/hr_device_profiles.dart`
- [x] `lib/core/config/step_validation_config.dart`
- [x] Unit tests for all config classes (116 tests passing)

### Success Criteria

- ✅ All configuration values accessible from single location
- ✅ Easy to modify values without code changes
- ✅ Unit tests verify default values

---

## Sprint 2: Database Schema ✅

**Effort:** 2-3 days | **Priority:** High | **Dependencies:** None | **Status:** COMPLETE

Add database tables for continuous tracking.

### Tasks

1. **Create Migration v11** ✅
   - Add `continuous_tracking_config` table
   - Add `continuous_tracking_state` table
   - Add `activity_segments` table (for future use)

2. **Create Domain Models** ✅
   - `ContinuousTrackingConfig` model
   - `ContinuousTrackingState` model
   - `ActivitySegment` model (with `DetectionSource` enum)

3. **Create DAOs** ✅
   - `ContinuousTrackingConfigDao`
   - `ContinuousTrackingStateDao`
   - `ActivitySegmentDao`

4. **Create Repository** ✅
   - `ContinuousTrackingRepository` (interface)
   - `ContinuousTrackingRepositoryImpl` (implementation)
   - CRUD operations for config, state, and segments
   - State transition methods

5. **Update schema diagrams** ✅
   - Add new tables to `schema_actual.puml`
   - Update `schema_planned.puml` to mark as implemented
   - Update relationships and version number

### Deliverables

- [x] Database migration v11 (`database_helper.dart`)
- [x] `lib/features/session/domain/continuous_tracking_config.dart`
- [x] `lib/features/session/domain/continuous_tracking_state.dart`
- [x] `lib/features/session/domain/activity_segment.dart`
- [x] `lib/features/session/data/continuous_tracking_config_dao.dart`
- [x] `lib/features/session/data/continuous_tracking_state_dao.dart`
- [x] `lib/features/session/data/activity_segment_dao.dart`
- [x] `lib/features/session/data/continuous_tracking_repository.dart`
- [x] `lib/features/session/data/continuous_tracking_repository_impl.dart`
- [x] Updated `database/schema_actual.puml` (version 11, 16 tables) — *note: the DB has since advanced to **v12** (`DatabaseHelper.dbVersion = 12`, database_helper.dart:36) while `schema_actual.puml` still says "Database Version 11"; the 16-table count is unchanged*
- [x] Updated `database/schema_planned.puml`
- [x] Unit tests for domain models (67 tests passing)

### Success Criteria

- ✅ Migration runs without errors
- ✅ Can create/read/update continuous tracking config
- ✅ Can query and update current tracking state
- ✅ Can manage activity segments for sessions

---

## Sprint 3: Sensor & Trust Infrastructure

**Effort:** 5-7 days | **Priority:** High | **Dependencies:** Sprint 1

Implement sensor detection and trust scoring.

> **Status: nothing built.** `sensor_capability_service.dart`, `trust_multiplier_service.dart`,
> `pedometer_sensor.dart` and `scoring_service.dart` are all absent from `lib/`, and no pedometer
> package is in `pubspec.yaml`. The Sprint-1 config classes this sprint would consume exist but have
> no production caller — see Sprint 10.

### Tasks

1. **Sensor Capability Detection**
   - File: `lib/features/shared/sensors/sensor_capability_service.dart`
   - Detect available sensors (GPS, pedometer, barometer, etc.)
   - Query sensor availability at runtime
   - Cache results

2. **Trust Multiplier Service**
   - File: `lib/features/session/services/trust_multiplier_service.dart`
   - Calculate trust based on available sensors
   - Apply device profile overrides
   - Apply HR device type multiplier

3. **Pedometer Integration**
   - Use OS-level step counter (Android/iOS)
   - File: `lib/features/shared/sensors/pedometer_sensor.dart`
   - Extend `BaseSensor<StepData>` pattern
   - Permission handling

4. **Scoring Service**
   - File: `lib/features/session/services/scoring_service.dart`
   - Calculate points using formula:
     `points = distance × sensor_trust × device × activity`

### Deliverables

- [ ] `lib/features/shared/sensors/sensor_capability_service.dart`
- [ ] `lib/features/session/services/trust_multiplier_service.dart`
- [ ] `lib/features/shared/sensors/pedometer_sensor.dart`
- [ ] `lib/features/session/services/scoring_service.dart`
- [ ] Unit tests for all services
- [ ] Integration test for scoring calculation

### Success Criteria

- Can detect which sensors are available
- Trust multiplier correctly calculated
- Pedometer provides step count
- Scoring formula produces expected results

---

## Sprint 4: Permissions & Background Infrastructure ✅ (Phase A)

**Effort:** 4-5 days | **Priority:** High | **Dependencies:** None | **Status:** delivered as WP1–WP3 of [BACKGROUND_TRACKING_PLAN.md](./BACKGROUND_TRACKING_PLAN.md), 2026-06-13

Set up permissions and Android foreground service foundation.

> The implementation deviates deliberately from the sketch below: geolocator's **built-in**
> foreground service is used, so there is no own service class and no app-side notification channel.

### Tasks

1. **Permission Service Enhancement** ✅ (without a permission service)
   - **Status: no central permission service exists — and none is planned for Phase A.** The path
     `lib/services/permission/permission_service.dart` in earlier revisions of this plan has never
     existed (`find lib -iname "*permission*"` returns nothing). Permission handling lives in
     `lib/features/shared/sensors/gps_sensor.dart` (location: :89-129, notification: :138-157) and in
     the UI (`activity_screen.dart:146-163`, `openAppSettings`). Introduce a central service only if a
     third permission domain appears.
   - ⬜ Location "Always" permission flow — **deferred to Phase B** (`ACCESS_BACKGROUND_LOCATION` is
     commented out at AndroidManifest.xml:17-22; only `Permission.location` / while-in-use is requested)
   - ⬜ Activity Recognition permission — declared (AndroidManifest.xml:25) but **no consumer**, no
     pedometer code
   - ✅ Bluetooth permissions (for wearables) — AndroidManifest.xml:31-37
   - ✅ Notification permission (Android 13+) — `GpsSensor.ensureNotificationPermission()`
     (gps_sensor.dart:138-157), best-effort, called from sensor_manager.dart:184
   - ⬜ Rationale dialogs — still open
   - ✅ Settings deep-link for denied permissions — `openAppSettings()` (activity_screen.dart:154-160)

2. **Android Foreground Service Setup** ✅ (via plugin)
   - **No own service or channel:** `geolocator_android` 5.0.2 declares `GeolocatorLocationService`
     with `foregroundServiceType="location"` in its plugin manifest; a second declaration would be a
     merge conflict.
   - The app contributes only the permissions: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`,
     `POST_NOTIFICATIONS`, `WAKE_LOCK` (AndroidManifest.xml:10-15).
   - Basic notification ships with WP2 (gps_sensor.dart:236-242); plugin default channel
     ("Background Location").

3. **iOS Background Modes** ✅
   - ✅ `Info.plist` configured for background location — `UIBackgroundModes: [location]`
     (Info.plist:56-59); usage strings sharpened for the workout/route purpose (:49-52)
   - ⬜ Background fetch capability — **not needed for Phase A** (the location stream is started in the
     foreground and kept alive by the FGS)

### Deliverables

- [x] Permission handling in `GpsSensor` — no separate service (decision 2026-06-13)
- [~] ~~`lib/core/services/foreground_service.dart` (skeleton)~~ — **dropped by decision**; geolocator's built-in FGS is used instead (BACKGROUND_TRACKING_PLAN.md §5)
- [x] Android notification channel — plugin default ("Background Location"), no app-side channel
- [x] Updated `AndroidManifest.xml` (AndroidManifest.xml:10-22)
- [x] Updated `Info.plist` (Info.plist:49-59)
- [x] Permission request UI components — SnackBar + persistent warning banner + Settings action (activity_screen.dart:146-163, :361-386)
- [ ] Integration tests for permission flows — open; only the `LocationSettings` builder is unit-tested (`test/unit/features/shared/sensors/gps_location_settings_test.dart`)

### Success Criteria

- ~~Can request "Always" location permission~~ — **out of scope for Phase A** (while-in-use by decision; moves to Phase B)
- ⬜ Foreground service starts without crash — pending the on-device smoke (WP6b)
- ⬜ Notification appears when service runs — pending the on-device smoke (WP6b)
- ⬜ iOS background location works — pending an on-device check (no iOS hardware in the smoke plan yet)

---

## Sprint 5: Continuous Tracking Core

**Effort:** 8-10 days | **Priority:** High | **Dependencies:** Sprints 1, 2, 3, 4

Implement core continuous tracking functionality.

> **Status: nothing built.** `continuous_tracking_service.dart`, `reset_point_scheduler.dart`,
> `continuous_tracking_provider.dart`, `continuous_status_indicator.dart` and
> `continuous_toggle_button.dart` are all absent from `lib/`. Of the listed dependencies, Sprints 1,
> 2 and 4 are done; only Sprint 3 is outstanding — so this sprint is **ready to start**, not blocked.
> Note that Phase A background tracking (WP1–WP5) covers *active* sessions only; a continuous
> runtime that survives a process kill is Phase B, see
> [BACKGROUND_TRACKING_PLAN.md](./BACKGROUND_TRACKING_PLAN.md).

### Tasks

1. **ContinuousTrackingService**
   - File: `lib/features/session/services/continuous_tracking_service.dart`
   - Start/stop continuous tracking
   - Session lifecycle management
   - `isActive` and `isPausedForManual` getters

2. **Reset Point Scheduler**
   - Schedule daily reset at configured time(s)
   - Use Android AlarmManager / iOS BGTaskScheduler
   - Handle timezone changes
   - Create new session at reset

3. **Background Location Updates**
   - Low-frequency GPS (5 min / 100m)
   - Save to `gps_points` table
   - Handle location updates in background

4. **Activity Screen UI - Toggle**
   - Add continuous tracking toggle button
   - "Start Continuous Tracking" / "Stop" states
   - Handle permission requests on enable

5. **Activity Screen UI - Status Indicator**
   - Red pulsing dot (◉) component
   - Top-left placement
   - Animation implementation
   - State-based display (active/paused/disabled)

6. **ContinuousTrackingProvider**
   - State management for UI
   - Connect to ContinuousTrackingService
   - Expose status for other providers

### Deliverables

- [ ] `lib/features/session/services/continuous_tracking_service.dart`
- [ ] `lib/features/session/services/reset_point_scheduler.dart`
- [ ] `lib/providers/continuous_tracking_provider.dart`
- [ ] Updated `lib/presentation/screens/activity/activity_screen.dart`
- [ ] `lib/presentation/widgets/continuous_status_indicator.dart`
- [ ] `lib/presentation/widgets/continuous_toggle_button.dart`
- [ ] Unit tests for service
- [ ] Widget tests for UI components

### Success Criteria

- Can enable/disable continuous tracking from Activity screen
- Status indicator shows correct state
- Sessions reset at configured time
- GPS points saved in background

---

## Sprint 6: Manual-Continuous Integration 🟡 partially delivered (session-record level)

**Effort:** 4-5 days | **Priority:** High | **Dependencies:** Sprint 5

Seamless switching between manual and continuous sessions.

> **Caveat:** tasks 1 and 2 are implemented, but they only write `sessions` rows.
> `continuous_tracking_state` is never touched and no continuous GPS runtime exists (Sprint 5), so
> the transition is currently **inert** — continuous tracking never runs, so there is never anything
> to end or restart. Tasks 3 (edge cases) and 4 (event emission) remain open.

### Tasks

1. **Manual Session Start Handler** ✅ (partly)
   - ✅ `ActivityProvider._endActiveContinuousSessions()` (activity_provider.dart:597-652) completes
     every active `continuousDaily` session before a manual session is created (called from
     `startSession` at :312) and remembers `_wasContinuousActive`.
   - Detect when manual session starts
   - Complete current continuous session (save data)
   - Queue for sync
   - Update tracking state to "paused for manual"

2. **Manual Session End Handler** ✅ (partly)
   - ✅ `ActivityProvider._startContinuousSession()` (activity_provider.dart:658-687) creates a fresh
     continuous session on stop when it was active (called at :545-546).
   - Detect when manual session ends
   - Auto-restart continuous session
   - ⬜ Update tracking state to "active" — `continuous_tracking_state` is not written

3. **Edge Case Handling**
   - App crash during manual → recovery on next app start
   - Multiple rapid start/stop → debounce
   - Permission revoked mid-session
   - Network sync during transition

4. **Integration with ActivityProvider**
   - Coordinate with existing manual session logic
   - Emit events for continuous tracking changes

### Deliverables

- [x] Updated `ActivityProvider` with continuous integration (session-record level only)
- [ ] Session transition logic in `ContinuousTrackingService` — **class does not exist yet** (Sprint 5)
- [ ] Edge case handlers
- [ ] Integration tests for all transition scenarios

### Success Criteria

- 🟡 Manual session correctly ends continuous — true for `sessions` rows; untestable end-to-end until Sprint 5
- 🟡 Continuous auto-restarts after manual — same caveat
- ⬜ No data loss during transitions — no continuous data exists to lose yet
- ⬜ Smooth UI updates during transitions — no continuous UI exists (Sprint 5)

---

## Sprint 7: Background Service Polish 🟡 partially delivered (WP2)

**Effort:** 5-6 days | **Priority:** Medium | **Dependencies:** Sprints 4, 5

Complete background service implementation.

> The basic foreground notification shipped with WP2 (gps_sensor.dart:236-242). Notification
> **actions** (pause/stop/open) are **not implementable** with geolocator's
> `ForegroundNotificationConfig` — they require `flutter_background_service` (Phase B / Option 2),
> see [BACKGROUND_TRACKING_PLAN.md](./BACKGROUND_TRACKING_PLAN.md) §5. Tasks 2-4 below have no code
> in the repository at all.

### Tasks

1. **Foreground Notification** 🟡
   - [x] Design notification content — "BeneFit" / "Recording your activity session…", `setOngoing: true` (gps_sensor.dart:236-242)
   - ⬜ Add actions: Pause, Stop, Open App — **blocked on Phase B** (needs `flutter_background_service`)
   - ⬜ Show current session stats (distance, time) — the notification text is static
   - ⬜ Update notification periodically — not supported by the plugin config

2. **Battery Optimization Handling** ⬜ (no code in the repository)
   - Request Doze mode exemption (with user consent)
   - Handle App Standby
   - Detect Battery Saver mode
   - Adaptive GPS frequency based on battery level

3. **Manufacturer-Specific Handling** ⬜ (no code in the repository)
   - Samsung battery optimization
   - Xiaomi AutoStart
   - Huawei power management
   - Guide user to settings if needed

4. **Error Recovery** ⬜ (no code in the repository; no boot receiver in AndroidManifest.xml)
   - Auto-restart after app crash
   - Auto-restart after phone reboot
   - Recover partial session data
   - Handle clock/timezone changes

### Deliverables

- [~] Basic foreground notification ✅ (WP2) — **with actions: blocked on Phase B**
- [ ] Battery optimization handling
- [ ] Manufacturer-specific guides/deep-links
- [ ] Crash recovery logic
- [ ] Boot receiver for auto-restart
- [ ] Manual tests on major phone brands

### Success Criteria

- ⬜ Notification shows accurate data — text is static today
- ⬜ Notification actions work correctly — blocked on Phase B
- ⬜ Tracking survives Doze mode — untested; needs the on-device smoke (WP6b) plus battery handling
- ⬜ Tracking resumes after crash/reboot — not implemented (Phase A does not survive a process kill)

---

## Sprint 8: Cross-Validation with Health APIs 🟡 partially delivered

**Effort:** 6-8 days | **Priority:** Medium | **Dependencies:** Sprint 3

Integrate Health Connect/HealthKit for cross-validation.

> The Health integrations already ship — but under a different path than this plan assumed, and
> nothing consumes them for cross-validation yet.

### Tasks

1. **Health Connect Integration (Android)** ✅
   - ✅ `health` package is a direct dependency (`health: ^13.3.1`, pubspec.yaml:68)
   - ✅ Ships as `lib/features/wearable_integration/data/sources/health_connect_source.dart`
     (`HealthConnectSource implements WearableRepository`, :13; permission request :79-110;
     `HealthDataType.STEPS` read at :85 and :118)
   - ⬜ Read activity sessions (optional) — not implemented

2. **HealthKit Integration (iOS)** ✅
   - ✅ `lib/features/wearable_integration/data/sources/healthkit_source.dart` (`HealthKitSource`, :12)
   - ⬜ Read workout sessions (optional) — not implemented

3. **Step Length Calculation Service** ⬜
   - File: `lib/features/session/services/step_length_service.dart` — **does not exist**
   - Use height/gender/age from user profile
   - Calculate expected step length
   - Activity-specific adjustments
   - > The maths already exists as pure functions in `lib/core/config/step_validation_config.dart`
     > (`calculateStepLength`, `expectedSteps`, :169-330). What is missing is a service that feeds a
     > real user profile into it.

4. **Validation Service** ⬜
   - File: `lib/features/session/services/movement_validation_service.dart` — **does not exist**
   - Cross-validate GPS distance vs step count
   - Calculate z-score
   - Adjust trust multiplier based on validation
   - Flag suspicious sessions
   - > Likewise pre-built as pure functions: `calculateZScore`, `zScoreToConfidence`, `validateSteps`,
     > `getTrustAdjustment`, `validateAndAdjust` (step_validation_config.dart:169-330). The service
     > only has to wire real GPS distance + Health step counts into them and persist the adjusted trust.

5. **HR Source Detection via Health APIs**
   - Detect source device from Health Connect/HealthKit
   - Identify chest strap vs wrist device
   - Update trust multiplier accordingly

### Deliverables

- [x] `lib/features/wearable_integration/data/sources/health_connect_source.dart` *(the `lib/features/health/` directory this plan originally named does not exist)*
- [x] `lib/features/wearable_integration/data/sources/healthkit_source.dart`
- [ ] `lib/features/session/services/step_length_service.dart` *(z-score + step-length maths already in `lib/core/config/step_validation_config.dart` — the service only has to wire it up)*
- [ ] `lib/features/session/services/movement_validation_service.dart` *(same — the maths exists, the wiring does not)*
- [ ] Unit tests for validation logic
- [ ] Integration tests with mock health data

### Success Criteria

- Can read step count from Health Connect/HealthKit
- Step length calculated correctly for user
- Z-score validation identifies suspicious data
- Trust multiplier adjusted based on validation

---

## Sprint 9: Session Timeout Implementation

**Effort:** 3-4 days | **Priority:** Medium | **Dependencies:** Sprint 5

Complete the session timeout service. The file already exists as a **documented stub**:
`lib/features/security/services/session_timeout_service.dart` — `bool get isEnabled => false;` (:96)
and `recordActivity` / `startMonitoring` / `stopMonitoring` / `extendSession` only `debugPrint`
"NOT IMPLEMENTED" (:99-120). SESSION_DESIGN.md used to refer to it as a "Sprint 6 security feature";
that reference now points here — **Sprint 9 is authoritative**.

### Tasks

1. **Implement SessionTimeoutService**
   - File: `lib/features/security/services/session_timeout_service.dart`
   - Activity monitoring timer
   - Warning timer
   - Check tracking state before timeout

2. **Integration with Tracking State**
   - Check `ActivityProvider.isTracking`
   - Check `ActivityProvider.isPaused`
   - Check `ContinuousTrackingService.isActive` — only wireable once Sprint 5 exists; until then the
     timeout can ship checking `ActivityProvider.isTracking` / `isPaused` only
   - Skip timeout if any tracking active

3. **UI Components**
   - Warning dialog ("Session expiring in 5 minutes")
   - "Stay Logged In" action
   - Auto-logout flow

4. **App-Level Integration**
   - GestureDetector wrapper for activity detection
   - Start monitoring on login
   - Stop monitoring on logout

### Deliverables

- [ ] Replace the stub in `session_timeout_service.dart` with the real timers
- [ ] Warning dialog component
- [ ] Updated `main.dart` with gesture detector
- [ ] Integration with `AuthProvider` for logout
- [ ] Unit tests for timeout logic
- [ ] Integration tests for full flow

### Success Criteria

- Session times out after inactivity
- Timeout skipped during any tracking
- Warning shows before timeout
- "Stay Logged In" extends session

---

## Sprint 10: Scoring Integration (unowned until now)

**Effort:** 4-6 days | **Priority:** High | **Dependencies:** Sprints 3, 8

Wire the Sprint-1 scoring stack into the running app.

> **Why this sprint exists:** Sprint 1 delivered `TrackingConfig`, `DeviceProfiles`,
> `HrDeviceProfiles` and `StepValidationConfig`, and [SESSION_DESIGN.md](./SESSION_DESIGN.md)
> presents the "Final Scoring Formula" as *the* way points are computed. In the shipped code these
> classes are referenced only inside `lib/core/config/` and their own unit tests — no production code
> calls `calculateScore`, `getDeviceMultiplier`, `getTrustMultiplier` or `validateAndAdjust`, and no
> session or benefit code computes points at all. **No previous sprint owned that integration.**

### Tasks

1. **Compute points at session completion**
   - In `ActivityProvider.stopSession()` / the session repository's completion path
   - Feed `TrackingConfig.calculateScore` with the sensor set actually present in the session
     (GPS-only, GPS + HR, GPS + HR + wearable …)
   - Apply `DeviceProfiles.getDeviceMultiplier` and the activity multiplier

2. **Persist the result**
   - Store the computed points on the session row (schema change — bump `DatabaseHelper.dbVersion`)
   - Store the inputs (trust/device/activity multipliers) so a score can be explained and reproduced

3. **Apply the cross-validation adjustment** *(after Sprint 8)*
   - Run `StepValidationConfig.validateAndAdjust` when Health step data is available
   - Persist the adjusted trust and the validation outcome

4. **Surface points in the UI**
   - Session detail + progress screen
   - Feed the existing benefit/progress flow

### Deliverables

- [ ] Scoring called on session completion
- [ ] Points column(s) on `sessions` + migration
- [ ] Unit tests: same session inputs → same stored score
- [ ] UI shows the score and its breakdown

### Success Criteria

- A completed session yields a stored, reproducible point value
- `TrackingConfig.calculateScore` has at least one production caller

---

## Future Sprints (Post-MVP)

### Sprint F1: Server-Side Validation

**Dependencies:** Backend API ready

- [ ] Anomaly detection API endpoint
- [ ] Pattern matching for gaming
- [ ] Cross-user validation (statistical outliers)
- [ ] Fraud flagging system
- [ ] Admin dashboard for flagged sessions

### Sprint F2: Auto Activity Detection

**Dependencies:** Real-world data collected

- [ ] Speed-based activity classification
- [ ] Accelerometer pattern analysis
- [ ] User confirmation UI ("Looks like running?")
- [ ] `activity_segments` table population
- [ ] Correction feedback loop

### Sprint F3: ML-Based Pattern Recognition

**Dependencies:** Sufficient training data

- [ ] Collect labeled activity data
- [ ] Train classification model
- [ ] On-device inference (TensorFlow Lite)
- [ ] Confidence scoring
- [ ] Continuous improvement pipeline

---

## Sprint Summary

| Sprint | Name | Effort | Priority | Dependencies | Status |
|--------|------|--------|----------|--------------|--------|
| 1 | Configuration Foundation | 3-4 days | High | None | ✅ Complete |
| 2 | Database Schema | 2-3 days | High | None | ✅ Complete |
| 3 | Sensor & Trust Infrastructure | 5-7 days | High | Sprint 1 | Ready (not started) |
| 4 | Permissions & Background | 4-5 days | High | None | ✅ Phase A done (WP1–WP3, 2026-06-13) |
| 5 | Continuous Tracking Core | 8-10 days | High | 1, 2, 3, 4 | Ready (unblocked — 1, 2, 4 done; 3 not required for Phase A) |
| 6 | Manual-Continuous Integration | 4-5 days | High | Sprint 5 | 🟡 Partial (session-record transitions in `ActivityProvider`) |
| 7 | Background Service Polish | 5-6 days | Medium | 4, 5 | 🟡 Partial (basic FGS notification; actions blocked on Phase B) |
| 8 | Cross-Validation | 6-8 days | Medium | Sprint 3 | 🟡 Partial (Health Connect / HealthKit sources ship; validation services open) |
| 9 | Session Timeout | 3-4 days | Medium | Sprint 5 | Ready (stub exists) |
| 10 | Scoring Integration | 4-6 days | High | 3, 8 | Not started (previously unowned) |

*Status as of 2026-08-28; code state = commit `fd7dfc1` (WP5).*

**Critical Path:** Sprints 3 → 5 → 6 (1, 2 and 4 are done)

**Parallel Tracks:**
- Track A: Sprints 3, 5, 6 (core functionality; 1 and 2 complete)
- Track B: Sprint 7 remainder — battery / OEM / crash-recovery — see [BACKGROUND_TRACKING_PLAN.md](./BACKGROUND_TRACKING_PLAN.md)
- Track C: Sprint 8 (can start after Sprint 3), then Sprint 10

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Background location unreliable | High | Extensive testing on multiple devices |
| Battery drain complaints | Medium | Adaptive GPS frequency, user controls |
| Health API permission denied | Medium | Graceful degradation, work without it |
| Manufacturer restrictions | High | Document workarounds, guide users |
| Step count accuracy varies | Medium | Cross-validation catches outliers |

---

## Definition of Done

Each sprint is complete when:

1. All tasks checked off
2. Unit tests written and passing
3. Integration tests passing
4. Code reviewed and merged
5. Documentation updated
6. Tested on Android + iOS devices
7. No critical bugs remaining

