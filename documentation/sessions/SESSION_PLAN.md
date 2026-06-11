---
> **Documentation Type:** IMPLEMENTATION PLAN (Sprint Breakdown)
>
> **Design Document:** [SESSION_DESIGN.md](./SESSION_DESIGN.md) - Full design details
>
> **Related:** [DATABASE.md](../../database/DATABASE.md) | [AUTH.md](../../AUTH.md)
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
- [x] Updated `database/schema_actual.puml` (version 11, 16 tables)
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

## Sprint 4: Permissions & Background Infrastructure

**Effort:** 4-5 days | **Priority:** High | **Dependencies:** None

Set up permissions and Android foreground service foundation.

### Tasks

1. **Permission Service Enhancement**
   - Update: `lib/services/permission/permission_service.dart`
   - Location "Always" permission flow
   - Activity Recognition permission
   - Bluetooth permissions (for wearables)
   - Notification permission (Android 13+)
   - Rationale dialogs
   - Settings deep-link for denied permissions

2. **Android Foreground Service Setup**
   - Create notification channel
   - Service declaration in AndroidManifest
   - Foreground service type (location)
   - Basic notification (content TBD in Sprint 7)

3. **iOS Background Modes**
   - Configure Info.plist for background location
   - Background fetch capability

### Deliverables

- [ ] Enhanced `permission_service.dart`
- [ ] `lib/core/services/foreground_service.dart` (skeleton)
- [ ] Android notification channel configuration
- [ ] Updated `AndroidManifest.xml`
- [ ] Updated `Info.plist`
- [ ] Permission request UI components
- [ ] Integration tests for permission flows

### Success Criteria

- Can request "Always" location permission
- Foreground service starts without crash
- Notification appears when service runs
- iOS background location works

---

## Sprint 5: Continuous Tracking Core

**Effort:** 8-10 days | **Priority:** High | **Dependencies:** Sprints 1, 2, 3, 4

Implement core continuous tracking functionality.

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

## Sprint 6: Manual-Continuous Integration

**Effort:** 4-5 days | **Priority:** High | **Dependencies:** Sprint 5

Seamless switching between manual and continuous sessions.

### Tasks

1. **Manual Session Start Handler**
   - Detect when manual session starts
   - Complete current continuous session (save data)
   - Queue for sync
   - Update tracking state to "paused for manual"

2. **Manual Session End Handler**
   - Detect when manual session ends
   - Auto-restart continuous session
   - Update tracking state to "active"

3. **Edge Case Handling**
   - App crash during manual → recovery on next app start
   - Multiple rapid start/stop → debounce
   - Permission revoked mid-session
   - Network sync during transition

4. **Integration with ActivityProvider**
   - Coordinate with existing manual session logic
   - Emit events for continuous tracking changes

### Deliverables

- [ ] Updated `ActivityProvider` with continuous integration
- [ ] Session transition logic in `ContinuousTrackingService`
- [ ] Edge case handlers
- [ ] Integration tests for all transition scenarios

### Success Criteria

- Manual session correctly ends continuous
- Continuous auto-restarts after manual
- No data loss during transitions
- Smooth UI updates during transitions

---

## Sprint 7: Background Service Polish

**Effort:** 5-6 days | **Priority:** Medium | **Dependencies:** Sprints 4, 5

Complete background service implementation.

### Tasks

1. **Foreground Notification**
   - Design notification content
   - Add actions: Pause, Stop, Open App
   - Show current session stats (distance, time)
   - Update notification periodically

2. **Battery Optimization Handling**
   - Request Doze mode exemption (with user consent)
   - Handle App Standby
   - Detect Battery Saver mode
   - Adaptive GPS frequency based on battery level

3. **Manufacturer-Specific Handling**
   - Samsung battery optimization
   - Xiaomi AutoStart
   - Huawei power management
   - Guide user to settings if needed

4. **Error Recovery**
   - Auto-restart after app crash
   - Auto-restart after phone reboot
   - Recover partial session data
   - Handle clock/timezone changes

### Deliverables

- [ ] Complete foreground notification with actions
- [ ] Battery optimization handling
- [ ] Manufacturer-specific guides/deep-links
- [ ] Crash recovery logic
- [ ] Boot receiver for auto-restart
- [ ] Manual tests on major phone brands

### Success Criteria

- Notification shows accurate data
- Notification actions work correctly
- Tracking survives Doze mode
- Tracking resumes after crash/reboot

---

## Sprint 8: Cross-Validation with Health APIs

**Effort:** 6-8 days | **Priority:** Medium | **Dependencies:** Sprint 3

Integrate Health Connect/HealthKit for cross-validation.

### Tasks

1. **Health Connect Integration (Android)**
   - Add `health` package
   - Request permissions
   - Read step count data
   - Read activity sessions (optional)

2. **HealthKit Integration (iOS)**
   - Configure HealthKit capabilities
   - Request permissions
   - Read step count data
   - Read workout sessions (optional)

3. **Step Length Calculation Service**
   - File: `lib/features/session/services/step_length_service.dart`
   - Use height/gender/age from user profile
   - Calculate expected step length
   - Activity-specific adjustments

4. **Validation Service**
   - File: `lib/features/session/services/movement_validation_service.dart`
   - Cross-validate GPS distance vs step count
   - Calculate z-score
   - Adjust trust multiplier based on validation
   - Flag suspicious sessions

5. **HR Source Detection via Health APIs**
   - Detect source device from Health Connect/HealthKit
   - Identify chest strap vs wrist device
   - Update trust multiplier accordingly

### Deliverables

- [ ] `lib/features/health/health_connect_service.dart`
- [ ] `lib/features/health/healthkit_service.dart`
- [ ] `lib/features/session/services/step_length_service.dart`
- [ ] `lib/features/session/services/movement_validation_service.dart`
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

Complete the session timeout service from Sprint 6 security.

### Tasks

1. **Implement SessionTimeoutService**
   - File: `lib/features/security/services/session_timeout_service.dart`
   - Activity monitoring timer
   - Warning timer
   - Check tracking state before timeout

2. **Integration with Tracking State**
   - Check `ActivityProvider.isTracking`
   - Check `ActivityProvider.isPaused`
   - Check `ContinuousTrackingService.isActive`
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

- [ ] Complete `session_timeout_service.dart`
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
| 3 | Sensor & Trust Infrastructure | 5-7 days | High | Sprint 1 | Ready |
| 4 | Permissions & Background | 4-5 days | High | None | Ready |
| 5 | Continuous Tracking Core | 8-10 days | High | 1, 2, 3, 4 | Blocked |
| 6 | Manual-Continuous Integration | 4-5 days | High | Sprint 5 | Blocked |
| 7 | Background Service Polish | 5-6 days | Medium | 4, 5 | Blocked |
| 8 | Cross-Validation | 6-8 days | Medium | Sprint 3 | Blocked |
| 9 | Session Timeout | 3-4 days | Medium | Sprint 5 | Blocked |

**Critical Path:** Sprints 1 → 3 → 5 → 6 (with 2 and 4 in parallel)

**Parallel Tracks:**
- Track A: Sprints 1, 2, 3, 5, 6 (core functionality)
- Track B: Sprint 4, 7 (background infrastructure)
- Track C: Sprint 8 (can start after Sprint 3)

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

