---
> **Documentation Type:** DESIGN (Planning & Decision Document)
>
> **Related:** [DATABASE.md](../../database/DATABASE.md) | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [SENSORS.md](../../lib/features/shared/sensors/SENSORS.md)
---

# Session & Tracking System Design

## Overview

BeneFit supports two tracking modes to capture user movement data:

| Mode | Purpose | GPS Frequency | Duration |
|------|---------|---------------|----------|
| **Manual** | User-initiated workouts | High (~5s / 10m) | Minutes to hours |
| **Continuous** | Passive daily tracking | Low (~5min / 100m) | Until next reset point |

---

## Design Decisions

### 1. Continuous Session Lifecycle

**Problem:** We cannot create endless sessions - this makes syncing difficult and data management complex.

**Solution:** Continuous sessions reset at configurable time points.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONTINUOUS SESSION LIFECYCLE                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Day 1                              Day 2                            │
│  ─────                              ─────                            │
│                                                                      │
│  00:00 ─────────────────────────── 00:00 ────────────────────────    │
│    │                                  │                              │
│    │  [Session A running]             │  [Session B running]         │
│    │                                  │                              │
│  03:00 ◄── RESET POINT               03:00 ◄── RESET POINT          │
│    │       • Session A ends           │       • Session B ends       │
│    │       • Session A queued         │       • Session B queued     │
│    │         for sync                 │         for sync             │
│    │       • Session B starts         │       • Session C starts     │
│    │                                  │                              │
│  23:59 ────────────────────────────  23:59                           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Configuration:**
- Default: 1 reset point at 03:00 (when most users are asleep)
- System must support **multiple reset points** (e.g., 03:00, 11:00, 19:00)
- Reset points stored in user preferences or app config

```dart
// Example configuration structure
class ContinuousTrackingConfig {
  final List<TimeOfDay> resetPoints; // e.g., [03:00] or [03:00, 11:00, 19:00]
  final Duration minimumSessionDuration; // Don't create micro-sessions
}
```

**Why 03:00?**
- Most users asleep = minimal data loss at boundary
- Low server load time for sync
- Clear "daily" boundary for statistics

---

### 2. Manual Session Interruption

**Behavior:** Manual sessions interrupt continuous tracking.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MANUAL INTERRUPTS CONTINUOUS                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Timeline:                                                           │
│  ─────────────────────────────────────────────────────────────────   │
│                                                                      │
│  08:00    [Continuous Session A running...]                          │
│     │                                                                │
│  09:15    User taps "Start Run"                                      │
│     │       │                                                        │
│     │       ├─► Continuous Session A → COMPLETED                     │
│     │       │   (queued for sync)                                    │
│     │       │                                                        │
│     │       └─► Manual Session M → STARTED                           │
│     │                                                                │
│  09:45    User taps "Stop"                                           │
│     │       │                                                        │
│     │       ├─► Manual Session M → COMPLETED                         │
│     │       │   (queued for sync)                                    │
│     │       │                                                        │
│     │       └─► Continuous Session B → STARTED (auto)                │
│     │                                                                │
│  03:00    Reset point                                                │
│           Continuous Session B → COMPLETED                           │
│           Continuous Session C → STARTED                             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- Continuous session data up to interruption is **preserved** (not discarded)
- No gap in tracking - manual session captures the "active" period
- Automatic restart after manual session ends (no user action needed)

---

### 3. Continuous Tracking Default State

**Decision:** Continuous tracking is **OFF by default**.

- Users must explicitly enable it
- Should be easy to activate (one toggle)
- Location: Settings screen or Activity screen (TBD)

**Rationale:**
- Battery impact needs user consent
- Background location permissions require explanation
- Some users only want manual tracking

---

### 4. Activity Detection Strategy

**Decision:** Hybrid approach - manual first, auto-detect later.

| Phase | Detection Method | User Interaction |
|-------|-----------------|------------------|
| **Phase 1 (Now)** | User declares activity | Select before start |
| **Phase 2 (Future)** | Auto-detect with confirmation | "Looks like running - correct?" |
| **Phase 3 (Future)** | Full auto-detect | Silent classification |

**For Continuous Sessions:**
- Phase 1: Default to "mixed" or "daily_movement" activity type
- Phase 2+: Auto-classify segments within continuous session

**For Manual Sessions:**
- Phase 1: User selects (walk/run/cycle) before starting
- Phase 2+: Pre-fill based on detected movement, user confirms

---

### 5. Data Retention

**Policy:** Keep data until successfully synced.

| Scenario | Action |
|----------|--------|
| Normal | Sync on WiFi/cellular, delete after confirmed |
| Offline for days | Queue grows, sync when connected |
| Offline very long (weeks?) | Warn user, eventually purge oldest |

**Purge Strategy (emergency only):**
- Keep session summaries (distance, duration, calories)
- Delete raw GPS points first
- Delete continuous data before manual data
- Never delete without user warning

See [DATABASE.md](../../database/DATABASE.md) sync_queue table for implementation.

---

## Open Design: Movement Scope & Scoring

This is the most complex design challenge. We need to decide what movements count and how they're weighted.

### The Core Problem

**Goal:** Reward all beneficial movement, not just "exercise sessions."

**Challenges:**

| Challenge | Example | Risk |
|-----------|---------|------|
| **False positives** | Hand wiggling detected as steps | Inflated scores |
| **False negatives** | Climbing stairs not detected | User frustration |
| **Activity confusion** | Pull-ups vs standing up | Wrong classification |
| **Device variance** | Phone in pocket vs hand vs bag | Inconsistent data |
| **Gaming** | Shaking phone to fake steps | Reward fraud |

### Movement Categories to Consider

| Category | Examples | Detection Difficulty | Value |
|----------|----------|---------------------|-------|
| **Walking** | Commute, errands, strolls | Easy (accelerometer) | Base |
| **Running** | Jogging, sprinting | Easy (speed + cadence) | High |
| **Cycling** | Bike commute, leisure | Medium (speed + GPS) | High |
| **Stairs** | Climbing up/down | Hard (barometer?) | Higher than walking |
| **Standing** | Standing desk, waiting | Hard to distinguish | Low |
| **Exercises** | Pull-ups, squats, etc. | Very hard | ??? |

### Detection Methods Available

| Sensor | What it detects | Availability |
|--------|----------------|--------------|
| **Accelerometer** | Movement patterns, steps | All phones |
| **GPS** | Location, speed, distance | All phones |
| **Gyroscope** | Rotation, orientation | Most phones |
| **Barometer** | Altitude/pressure changes | Some phones |
| **Heart Rate** | Exertion level | Wearables only |
| **Pedometer** | Step count (OS-level) | iOS/Android native |

### Scoring Approach Options

**Option A: Binary (Counts or Doesn't)**
```
Walking: counts
Running: counts
Sitting: doesn't count
```
Simple but loses nuance.

**Option B: Activity Multipliers**
```
Walking:     1.0x base points
Running:     1.5x base points
Cycling:     1.3x base points
Stairs up:   2.0x base points
Stairs down: 1.2x base points
```
More fair but harder to detect accurately.

**Option C: Effort-Based (Heart Rate)**
```
Points = duration × heart_rate_zone_multiplier
Zone 1 (recovery): 0.5x
Zone 2 (easy):     1.0x
Zone 3 (moderate): 1.5x
Zone 4 (hard):     2.0x
Zone 5 (max):      2.5x
```
Most accurate but requires wearable.

**Option D: Hybrid Distance + Effort**
```
Points = distance_km × activity_modifier × optional_hr_bonus
```

### Discussion Questions

1. **Should we trust phone accelerometer for step counting?**
   - Pro: Universal, no extra hardware
   - Con: Prone to artifacts (hand movements, vehicle vibration)

2. **How do we handle "phone in bag" vs "phone in hand"?**
   - Different motion patterns for same activity
   - Should we ask user about phone placement?

3. **What's our fraud tolerance?**
   - Some users will try to game the system
   - Do we need server-side validation?

4. **Minimum thresholds to filter noise?**
   ```
   Minimum to count as "activity":
   - Duration: ___ seconds? (30? 60? 120?)
   - Steps: ___ steps? (10? 50? 100?)
   - Distance: ___ meters? (20? 50? 100?)
   ```

5. **How to handle exercises without displacement?**
   - Pull-ups, weight lifting, yoga
   - Heart rate is only reliable indicator
   - Do we even want to track these? (outside app scope?)

### Artifact Scenarios to Handle

| Scenario | Sensor Reading | Actual Activity | How to Filter? |
|----------|---------------|-----------------|----------------|
| Shaking phone | High step count | None | Require GPS movement? |
| Driving on bumpy road | Steps detected | Sitting in car | Speed > 20km/h = vehicle |
| Train/bus | Steps + movement | Sitting | Speed patterns? |
| Elevator | Altitude change | Standing | No steps = not stairs |
| Escalator | Altitude + steps | Minimal effort | Reduce stair bonus? |
| Treadmill | Steps, no GPS | Running | Allow manual override? |
| Stationary bike | No steps, no GPS | Cycling | Heart rate only? |

### Sensor-Based Trust Scoring (Decided Approach)

**Core Insight:** Instead of fixed thresholds, adjust confidence based on available sensors.

**Philosophy:** "Every movement counts" - but we apply a trust multiplier based on how well we can verify it.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      SENSOR TRUST MODEL                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Available Sensors              Trust Level    Point Multiplier     │
│  ──────────────────────────────────────────────────────────────────  │
│                                                                      │
│  GPS only                       Low            0.3x - 0.4x          │
│  • Could be in vehicle                                               │
│  • Weak signal areas unreliable                                      │
│  • Easy to spoof                                                     │
│                                                                      │
│  GPS + Pedometer                Medium         0.5x - 0.6x          │
│  • Confirms walking motion                                           │
│  • Filters out vehicles                                              │
│  • Still some artifact risk                                          │
│                                                                      │
│  GPS + Pedometer + Barometer    High           0.7x - 0.8x          │
│  • Can detect elevation changes                                      │
│  • Better stair detection                                            │
│  • Cross-validation possible                                         │
│                                                                      │
│  GPS + Pedometer + Wrist HR     High           0.7x - 0.8x          │
│  • Confirms physical exertion                                        │
│  • Wrist HR less accurate but still useful                           │
│  • Requires wearable (watch/band)                                    │
│                                                                      │
│  GPS + Pedometer + Chest HR     Very High      0.85x - 0.9x         │
│  • Chest strap = most accurate HR method                             │
│  • Medical-grade precision                                           │
│  • Strong exertion validation                                        │
│                                                                      │
│  All sensors + Chest Strap      Highest        0.90x - 0.95x        │
│  • Full cross-validation                                             │
│  • Multiple independent signals                                      │
│  • Highest confidence                                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Why not 1.0x?** Even with all sensors, some uncertainty remains. Server-side validation (future) will handle remaining edge cases.

---

### Device Accuracy Profiles

**Problem:** Different devices have different sensor quality.

**Solution:** Maintain a device profile system with accuracy multipliers.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DEVICE PROFILE SYSTEM                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Approach: Runtime capability detection + device-specific overrides  │
│                                                                      │
│  1. RUNTIME DETECTION (default)                                      │
│     • Query available sensors at app start                           │
│     • Determine base trust level from sensor combination             │
│     • Works for all devices automatically                            │
│                                                                      │
│  2. DEVICE OVERRIDES (known problematic/excellent devices)           │
│     • Database of device models with known accuracy issues           │
│     • Can increase OR decrease trust multiplier                      │
│     • Updated via app config / remote config                         │
│                                                                      │
│  Example overrides:                                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Device Model          │ Override │ Reason                  │    │
│  ├────────────────────────┼──────────┼─────────────────────────┤    │
│  │  "Cheap Phone X"       │  0.7x    │ Known step count drift  │    │
│  │  "Fitness Watch Pro"   │  1.1x    │ Excellent HR accuracy   │    │
│  │  "Budget Tracker 3"    │  0.8x    │ GPS drift issues        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Heart Rate Device Identification

**Problem:** Chest strap HR is significantly more accurate than wrist HR. We need to reliably identify which type the user has.

**Decision:** Manufacturer database + BLE device type verification

```
┌─────────────────────────────────────────────────────────────────────┐
│                   HR DEVICE IDENTIFICATION                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Step 1: BLE Device Type Check                                       │
│  ─────────────────────────────────────────────────────────────────  │
│  • Read BLE GATT service UUIDs                                       │
│  • Heart Rate Service: 0x180D                                        │
│  • Check device appearance/type if available                         │
│                                                                      │
│  Step 2: Manufacturer Database Lookup                                │
│  ─────────────────────────────────────────────────────────────────  │
│  • Match device name/model against known devices                     │
│  • Categorize as: chest_strap | wrist_watch | wrist_band | unknown  │
│                                                                      │
│  Step 3: Assign Trust Level                                          │
│  ─────────────────────────────────────────────────────────────────  │
│  • chest_strap → 0.88x multiplier                                   │
│  • wrist_watch/band → 0.75x multiplier                              │
│  • unknown → 0.70x multiplier (conservative)                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Known Chest Strap Manufacturers/Models:**

| Manufacturer | Model Patterns | Notes |
|--------------|---------------|-------|
| Polar | H10, H9, H7 | Gold standard accuracy |
| Garmin | HRM-Pro, HRM-Dual, HRM-Run | Dual ANT+/BLE |
| Wahoo | TICKR, TICKR X, TICKR FIT | Popular choice |
| Coospo | H6, H808S | Budget option |
| Magene | H64, H303 | Good value |

**Known Wrist Devices (not exhaustive):**

| Type | Examples |
|------|----------|
| Smart Watches | Apple Watch, Samsung Galaxy Watch, Garmin Venu |
| Fitness Bands | Fitbit, Xiaomi Mi Band, Huawei Band |

**Config File:** `lib/core/config/hr_device_profiles.dart`

```dart
enum HrDeviceType {
  chestStrap,    // Highest accuracy
  wristWatch,    // Medium accuracy
  wristBand,     // Medium accuracy
  unknown,       // Conservative estimate
}

class HrDeviceProfiles {
  /// Known chest strap identifiers (partial match on device name)
  static const List<String> chestStrapPatterns = [
    'polar h10', 'polar h9', 'polar h7',
    'hrm-pro', 'hrm-dual', 'hrm-run', 'hrm-tri',
    'tickr',
    'coospo h', 'h808',
    'magene h',
    // Add more as discovered
  ];

  /// Identify device type from BLE device name
  static HrDeviceType identifyDevice(String deviceName) {
    final nameLower = deviceName.toLowerCase();

    for (final pattern in chestStrapPatterns) {
      if (nameLower.contains(pattern)) {
        return HrDeviceType.chestStrap;
      }
    }

    // Could add wrist device patterns here for explicit matching
    // For now, non-chest-strap HR devices default to wrist
    return HrDeviceType.unknown;
  }

  /// Get trust multiplier for device type
  static double getTrustMultiplier(HrDeviceType type) {
    switch (type) {
      case HrDeviceType.chestStrap:
        return 0.88;
      case HrDeviceType.wristWatch:
      case HrDeviceType.wristBand:
        return 0.75;
      case HrDeviceType.unknown:
        return 0.70;
    }
  }
}
```

**Why not user selection?**
- Users might not know the difference
- Could be gamed (claim chest strap when using wrist)
- BLE + database gives us certainty

---

### Centralized Configuration

**Requirement:** All tunable parameters in one place for easy adjustment.

**File:** `lib/core/config/tracking_config.dart`

```dart
/// Centralized tracking configuration
/// All values here can be tuned based on real-world data
class TrackingConfig {
  // ============================================================
  // SENSOR TRUST MULTIPLIERS
  // ============================================================

  /// GPS only - lowest trust (vehicle detection impossible)
  static const double gpsOnlyMultiplier = 0.35;

  /// GPS + Pedometer - medium trust
  static const double gpsPedometerMultiplier = 0.55;

  /// GPS + Pedometer + Barometer - high trust
  static const double gpsBarometerMultiplier = 0.75;

  /// GPS + Pedometer + Wrist HR - high trust
  static const double gpsWristHrMultiplier = 0.75;

  /// GPS + Pedometer + Chest Strap HR - very high trust
  static const double gpsChestHrMultiplier = 0.88;

  /// Full sensor suite - highest trust
  static const double fullSensorMultiplier = 0.90;

  // ============================================================
  // ANTI-GAMING FILTERS
  // ============================================================

  /// Speed above this = likely vehicle, discard
  static const double maxValidSpeedKmh = 25.0;

  /// Speed below this = stationary noise, discard
  static const double minValidSpeedKmh = 0.3;

  /// GPS accuracy worse than this = unreliable
  static const double maxGpsAccuracyMeters = 50.0;

  // ============================================================
  // CONTINUOUS TRACKING
  // ============================================================

  /// Continuous tracking OFF by default
  static const bool continuousEnabledByDefault = false;

  /// Default reset time(s)
  static const List<String> defaultResetPoints = ["03:00"];

  /// GPS polling interval for continuous mode
  static const Duration continuousGpsInterval = Duration(minutes: 5);

  /// Minimum movement to record a point
  static const double continuousMinDistanceMeters = 100.0;

  // ============================================================
  // MANUAL TRACKING
  // ============================================================

  /// GPS polling interval for manual mode
  static const Duration manualGpsInterval = Duration(seconds: 5);

  /// Minimum movement to record a point
  static const double manualMinDistanceMeters = 10.0;

  // ============================================================
  // ACTIVITY MULTIPLIERS (user-declared activities)
  // ============================================================

  static const double walkingMultiplier = 1.0;
  static const double runningMultiplier = 1.3;
  static const double cyclingMultiplier = 1.2;
  // Future: stairs, swimming, etc.
}
```

**Device Profile Config:** `lib/core/config/device_profiles.dart`

```dart
/// Known device accuracy profiles
/// Updated periodically based on user feedback and testing
class DeviceProfiles {
  static const Map<String, double> overrides = {
    // Format: "manufacturer_model": multiplier
    // Values < 1.0 = less trusted, > 1.0 = more trusted

    // Example entries (to be populated with real data):
    // "samsung_galaxy_s21": 1.0,      // baseline good
    // "generic_budget_phone": 0.8,    // known issues
    // "garmin_forerunner_945": 1.1,   // excellent sensors
  };

  /// Get multiplier for current device
  static double getDeviceMultiplier(String deviceId) {
    return overrides[deviceId] ?? 1.0; // default: no adjustment
  }
}
```

---

### Final Scoring Formula

```
Points = base_distance_points
       × sensor_trust_multiplier
       × device_accuracy_multiplier
       × activity_type_multiplier
```

**Example:**
- User walks 1km (100 base points)
- Has GPS + Pedometer (0.55 trust)
- Standard device (1.0 device)
- Walking (1.0 activity)
- **Result:** 100 × 0.55 × 1.0 × 1.0 = **55 points**

Same walk with full sensors + wearable:
- **Result:** 100 × 0.90 × 1.0 × 1.0 = **90 points**

---

### Phase 1 Implementation (Simplified)

For initial release, we simplify:

1. **Displacement-based only** (GPS distance)
   - No stationary exercise tracking
   - No stair detection
   - Indoor movement without GPS doesn't count

2. **GPS + Pedometer validation**
   - Pedometer confirms "person is walking" (not vehicle)
   - Steps > 0 required during movement

3. **Speed filters**
   - Discard if speed > 25 km/h (vehicle)
   - Discard if speed < 0.3 km/h (noise)

4. **User-declared activity type**
   - Manual sessions: user selects walk/run/cycle
   - Continuous sessions: "daily_movement" (no multiplier bonus)

5. **Server-side validation** (future phase)
   - Will add anomaly detection
   - Pattern matching for gaming detection
   - Cross-user validation

**Revisit in Phase 2** once we have real-world data on detection accuracy.

---

## Cross-Validation & Step Length Estimation

### The Opportunity

We can cross-validate GPS distance against Health Connect/HealthKit step counts using **personalized step length estimates** based on user biometrics we already collect.

### Step Length Research

Step length follows a **Gaussian (normal) distribution** within demographic groups. Key predictors:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STEP LENGTH PREDICTORS                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Primary Factor: HEIGHT                                              │
│  ─────────────────────────────────────────────────────────────────  │
│  Walking step length ≈ height_cm × 0.415 (±15%)                     │
│  Running step length ≈ height_cm × 0.65 to 1.0 (speed dependent)    │
│                                                                      │
│  Secondary Factors:                                                  │
│  ─────────────────────────────────────────────────────────────────  │
│  • Gender: Males ~5-8% longer at same height                        │
│  • Age: ~1-2% decrease per decade after 60                          │
│  • Speed: Stride increases with pace                                │
│  • Fitness level: Trained runners have longer strides               │
│                                                                      │
│  Distribution:                                                       │
│  ─────────────────────────────────────────────────────────────────  │
│  Step length ~ N(μ, σ²) where:                                      │
│  • μ = estimated mean based on height/gender/activity               │
│  • σ ≈ 10-15% of μ (natural variation)                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Formulas by Activity Type

**Walking (based on biomechanics research):**
```
step_length_cm = height_cm × base_multiplier × gender_factor × age_factor

Where:
  base_multiplier = 0.415
  gender_factor   = 1.0 (male) or 0.97 (female)
  age_factor      = 1.0 - (max(0, age - 60) × 0.015)  // 1.5% reduction per decade after 60

Standard deviation: σ = step_length × 0.12 (±12% variation)
```

**Running (speed-dependent):**
```
step_length_cm = height_cm × (0.65 + (speed_kmh - 8) × 0.03)

Where:
  Minimum multiplier at jogging pace (8 km/h): 0.65
  Maximum multiplier at sprint (20 km/h): ~1.0

Standard deviation: σ = step_length × 0.15 (±15% variation, more variable)
```

**Cycling:** Not applicable (no steps)

### Expected Steps per Kilometer

| Height | Gender | Walking (steps/km) | Running (steps/km) |
|--------|--------|-------------------|-------------------|
| 155 cm | Female | ~1,600 | ~1,100-900 |
| 165 cm | Female | ~1,500 | ~1,000-850 |
| 170 cm | Male | ~1,420 | ~950-800 |
| 180 cm | Male | ~1,340 | ~900-750 |
| 190 cm | Male | ~1,270 | ~850-700 |

### Validation Algorithm

```dart
/// Cross-validate GPS distance against step count
class StepValidation {

  /// Returns confidence score 0.0 - 1.0
  double validateMovement({
    required double distanceMeters,
    required int stepCount,
    required double heightCm,
    required String gender,
    required int age,
    required String activityType,
    double? speedKmh,
  }) {
    // Calculate expected step length
    final expectedStepLength = _calculateExpectedStepLength(
      heightCm: heightCm,
      gender: gender,
      age: age,
      activityType: activityType,
      speedKmh: speedKmh,
    );

    // Calculate expected steps for this distance
    final expectedSteps = distanceMeters * 100 / expectedStepLength;

    // Standard deviation (natural variation)
    final sigma = expectedSteps * 0.12; // 12% variation

    // Calculate z-score (how many std devs from expected)
    final zScore = (stepCount - expectedSteps).abs() / sigma;

    // Convert to confidence (normal distribution)
    // z=0 → 1.0 confidence
    // z=1 → 0.68 confidence (within 1σ)
    // z=2 → 0.32 confidence (within 2σ)
    // z=3 → 0.05 confidence (outlier)
    return _normalConfidence(zScore);
  }

  double _normalConfidence(double zScore) {
    // Simplified: exponential decay based on z-score
    return exp(-0.5 * zScore * zScore);
  }
}
```

### Validation Outcomes

| Z-Score | Confidence | Interpretation | Action |
|---------|------------|----------------|--------|
| 0-1 | 68-100% | Normal variation | ✅ Accept |
| 1-2 | 32-68% | Slightly unusual | ✅ Accept with note |
| 2-3 | 5-32% | Suspicious | ⚠️ Flag for review |
| >3 | <5% | Likely invalid | ❌ Reduce trust multiplier |

### Example Validations

**Valid Case:**
```
User: 175cm male, 35 years old
GPS distance: 1,500 meters (walking)
Health Connect steps: 2,100

Expected step length: 175 × 0.415 × 1.0 × 1.0 = 72.6 cm
Expected steps: 150,000 cm / 72.6 cm = 2,066 steps
Actual steps: 2,100
Z-score: |2,100 - 2,066| / (2,066 × 0.12) = 0.14

Result: ✅ High confidence (z < 1)
```

**Suspicious Case (likely vehicle):**
```
User: 175cm male, 35 years old
GPS distance: 1,500 meters
Health Connect steps: 200

Expected steps: 2,066
Actual steps: 200
Z-score: |200 - 2,066| / 248 = 7.5

Result: ❌ Very suspicious (z > 3), likely in vehicle
```

**Suspicious Case (likely gaming/shaking phone):**
```
User: 175cm male, 35 years old
GPS distance: 100 meters
Health Connect steps: 5,000

Expected steps: 138
Actual steps: 5,000
Z-score: way off scale

Result: ❌ Definite gaming attempt
```

### Configuration

Add to `lib/core/config/tracking_config.dart`:

```dart
class StepValidationConfig {
  // Base multipliers
  static const double walkingStepMultiplier = 0.415;
  static const double runningStepMultiplierBase = 0.65;
  static const double runningStepMultiplierPerKmh = 0.03;

  // Gender adjustments
  static const double maleGenderFactor = 1.0;
  static const double femaleGenderFactor = 0.97;

  // Age adjustments
  static const int ageDeclineStartAge = 60;
  static const double ageDeclinePerDecade = 0.015;

  // Validation thresholds
  static const double naturalVariationSigma = 0.12; // 12%
  static const double acceptThresholdZScore = 2.0;
  static const double rejectThresholdZScore = 3.0;

  // Trust adjustments based on validation
  static const double validatedBonus = 0.05;      // Add 5% if cross-validated
  static const double suspiciousPenalty = 0.30;   // Reduce 30% if suspicious
  static const double rejectedPenalty = 0.80;     // Reduce 80% if rejected
}
```

### Ethnicity Considerations

**Research suggests:**
- Leg-to-height ratio varies across populations
- However, **height remains the dominant predictor** (explains ~70% of variance)
- Adding ethnicity as a factor is:
  - Potentially sensitive/controversial
  - Marginal improvement (~2-5%)
  - Requires user to self-identify

**Recommendation for Phase 1:**
- Use height + gender + age (we already have these)
- The ±12% σ accounts for population variation
- Revisit ethnicity factor only if validation accuracy proves insufficient

### Data We Already Collect

From `user_biometrics_reported` table:
- ✅ `height_cm`
- ✅ `weight_kg` (not used for step length, but useful for calories)

From `users` table:
- ✅ `gender`
- ✅ `date_of_birth` (for age calculation)

**No new data collection needed!**

---

## Activity Screen UI Design

### Continuous Tracking Toggle Location

**Decision:** Activity screen (not Settings)

**Rationale:**
- Visible to all users immediately
- Contextually relevant (this is where tracking happens)
- Easy to discover and enable

### Screen Layout (Conceptual)

```
┌─────────────────────────────────────────────────────────────────────┐
│  ◉ Continuous Active                              [Profile Icon]   │
│  ─────────────────────────────────────────────────────────────────  │
│                                                                      │
│                        ┌─────────────┐                               │
│                        │             │                               │
│                        │   00:00:00  │  ◄── Timer (manual sessions) │
│                        │             │                               │
│                        └─────────────┘                               │
│                                                                      │
│                           0.00 km                                    │
│                                                                      │
│         ┌─────────┐   ┌─────────┐   ┌─────────┐                     │
│         │  Walk   │   │   Run   │   │  Cycle  │                     │
│         └─────────┘   └─────────┘   └─────────┘                     │
│                                                                      │
│                     ╔═══════════════════╗                            │
│                     ║                   ║                            │
│                     ║   START SESSION   ║  ◄── Manual session       │
│                     ║                   ║                            │
│                     ╚═══════════════════╝                            │
│                                                                      │
│         ┌─────────────────────────────────────┐                     │
│         │  ↻  Start Continuous Tracking       │  ◄── Toggle        │
│         └─────────────────────────────────────┘                     │
│                                                                      │
│  ─────────────────────────────────────────────────────────────────  │
│  [Home]      [Activity]      [Progress]      [Profile]              │
│                  ▲                                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Continuous Tracking Status Indicator

**Location:** Top-left of Activity screen (and possibly in app bar globally)

**Decision:** Red pulsing dot (◉) - classic "recording" indicator

**Why Red?**
- Universal "recording" metaphor (video cameras, voice recorders)
- Stands out against app's green design theme
- Pulsing animation clarifies it's "active" not "error"
- Label "Continuous Active" removes ambiguity

| State | Symbol | Color | Description |
|-------|--------|-------|-------------|
| **Active** | ◉ (pulsing) | Red | Recording in progress |
| **Paused** (manual active) | ◎ | Orange/Amber | Temporarily paused |
| **Disabled** | (none) | - | No indicator shown |

**Pulsing Animation:**
- Subtle scale pulse (1.0x → 1.2x → 1.0x)
- Period: ~2 seconds
- Smooth ease-in-out timing

### Toggle Button States

| State | Button Text | Action |
|-------|-------------|--------|
| Continuous OFF | "↻ Start Continuous Tracking" | Enable continuous |
| Continuous ON | "◉ Continuous Active - Tap to Stop" | Disable continuous |
| Manual Active | (hidden or disabled) | Can't toggle during manual |

### Interaction Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    USER INTERACTIONS                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SCENARIO A: Enable Continuous                                       │
│  ─────────────────────────────────────────────────────────────────  │
│  1. User taps "Start Continuous Tracking"                           │
│  2. Permission check (location always)                              │
│  3. If granted: Start continuous session                            │
│  4. Show ◉ indicator at top                                         │
│  5. Button changes to "Continuous Active - Tap to Stop"             │
│                                                                      │
│  SCENARIO B: Start Manual While Continuous Active                   │
│  ─────────────────────────────────────────────────────────────────  │
│  1. ◉ shows continuous is active                                    │
│  2. User taps "START SESSION"                                       │
│  3. Continuous session → COMPLETED (saved)                          │
│  4. Manual session → STARTED                                        │
│  5. Indicator changes: ◉ → ◎ (paused)                               │
│  6. Continuous toggle hidden/disabled                               │
│                                                                      │
│  SCENARIO C: Stop Manual Session                                    │
│  ─────────────────────────────────────────────────────────────────  │
│  1. User taps "STOP"                                                │
│  2. Manual session → COMPLETED (saved)                              │
│  3. Continuous session → AUTO-RESTARTED                             │
│  4. Indicator changes: ◎ → ◉ (active again)                         │
│  5. Continuous toggle visible again                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Database Schema (Refined)

### continuous_tracking_config (NEW)

| Column | Type | Description |
|--------|------|-------------|
| id | TEXT | Primary key |
| user_id | TEXT | FK to users (unique) |
| is_enabled | INTEGER | 0/1 - continuous tracking on/off |
| reset_points | TEXT | JSON array of times, e.g., ["03:00"] |
| created_at | INTEGER | Timestamp |
| updated_at | INTEGER | Timestamp |

### continuous_tracking_state

| Column | Type | Description |
|--------|------|-------------|
| id | TEXT | Primary key |
| user_id | TEXT | FK to users |
| current_session_id | TEXT | FK to sessions (current continuous) |
| last_reset_at | INTEGER | When last reset occurred |
| next_reset_at | INTEGER | Calculated next reset time |
| is_paused_for_manual | INTEGER | 0/1 - paused because manual active |
| paused_at | INTEGER | When paused for manual session |
| updated_at | INTEGER | Timestamp |

### sessions (tracking_mode values)

```
tracking_mode:
  - 'manual'           -- User-initiated session
  - 'continuous'       -- Background continuous session
```

### activity_segments (NEW - for future auto-detection)

| Column | Type | Description |
|--------|------|-------------|
| id | TEXT | Primary key |
| session_id | TEXT | FK to sessions |
| start_time | INTEGER | Segment start |
| end_time | INTEGER | Segment end |
| detected_activity | TEXT | walk/run/cycle/stationary/vehicle |
| confidence | REAL | 0.0 - 1.0 |
| user_corrected | INTEGER | 0/1 - did user override? |
| corrected_activity | TEXT | User's correction |

---

## Dependencies & Integration Notes

### Session Timeout Service Dependency

**File:** `lib/features/security/services/session_timeout_service.dart`

The session timeout service (Sprint 6 security feature) depends on continuous tracking state:

```
┌─────────────────────────────────────────────────────────────────────┐
│                 SESSION TIMEOUT LOGIC                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Should auto-logout?                                                 │
│         │                                                            │
│         ▼                                                            │
│  ┌─────────────────────────────────┐                                │
│  │ ActivityProvider.isTracking?    │── YES ──► SKIP timeout         │
│  └─────────────────────────────────┘           (manual active)      │
│         │ NO                                                         │
│         ▼                                                            │
│  ┌─────────────────────────────────┐                                │
│  │ ActivityProvider.isPaused?      │── YES ──► SKIP timeout         │
│  └─────────────────────────────────┘           (will resume)        │
│         │ NO                                                         │
│         ▼                                                            │
│  ┌─────────────────────────────────┐                                │
│  │ ContinuousTracking.isActive?    │── YES ──► SKIP timeout         │
│  └─────────────────────────────────┘           (background active)  │
│         │ NO                                    ▲                    │
│         ▼                                       │                    │
│  ┌─────────────────────────────────┐           │                    │
│  │ Inactivity > timeout threshold? │           │                    │
│  └─────────────────────────────────┘    ┌──────┴───────┐            │
│         │ YES                           │ REQUIRES:    │            │
│         ▼                               │ continuous   │            │
│    LOGOUT USER                          │ tracking     │            │
│                                         │ state check  │            │
│                                         └──────────────┘            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Implementation Order:**
1. First: Implement `continuous_tracking_state` table and service
2. Then: Session timeout can properly check `ContinuousTrackingService.isActive`

**Required API for Session Timeout:**
```dart
abstract class ContinuousTrackingService {
  /// Whether continuous tracking is currently active
  bool get isActive;

  /// Whether continuous tracking is paused (e.g., for manual session)
  bool get isPausedForManual;
}
```

---

## Implementation Phases

### Phase 1: Manual Sessions (Current)
- [x] Session create/update/complete
- [x] GPS tracking during session
- [x] Timer and distance display
- [x] Session persistence
- [x] User-declared activity type

### Phase 2: Configuration & Scoring Foundation
- [ ] Create `lib/core/config/tracking_config.dart`
- [ ] Create `lib/core/config/device_profiles.dart`
- [ ] Implement sensor capability detection
- [ ] Implement trust multiplier calculation
- [ ] Add pedometer integration (OS-level)

### Phase 3: Continuous Foundation
- [ ] `continuous_tracking_config` table
- [ ] `continuous_tracking_state` table
- [ ] Settings UI to enable/disable (default: OFF)
- [ ] Configurable reset points (start with single 03:00)
- [ ] Reset point scheduler/alarm

### Phase 4: Manual-Continuous Integration
- [ ] Detect manual session start → end continuous
- [ ] Detect manual session end → restart continuous
- [ ] Handle edge cases (crash during manual, etc.)
- [ ] Seamless session transitions

### Phase 5: Background Service
- [ ] Background location service
- [ ] Foreground notification (Android requirement)
- [ ] Battery optimization handling
- [ ] Wake lock management

### Phase 6: Server-Side Validation (Future)
- [ ] Anomaly detection API
- [ ] Pattern matching for gaming
- [ ] Cross-user validation
- [ ] Fraud flagging system

### Phase 7: Auto Activity Detection (Future)
- [ ] Speed-based activity classification
- [ ] User confirmation UI
- [ ] activity_segments table
- [ ] ML-based pattern recognition

---

## TODO: Topics to Design

The following topics need detailed design before implementation:

### Error Handling / Edge Cases

- [ ] App crash during manual session - how to recover?
- [ ] App crash during continuous tracking - auto-restart?
- [ ] Phone restart - resume continuous tracking automatically?
- [ ] Low battery behavior - reduce GPS frequency? Stop tracking?
- [ ] GPS signal loss during session - interpolate? Mark gap?
- [ ] Health Connect unavailable - fallback behavior?
- [ ] BLE device disconnects mid-session - how to handle?
- [ ] Session data corruption - validation and recovery?
- [ ] Clock/timezone changes during session?

### Android Foreground Service

- [ ] Notification content and design
- [ ] Notification actions (pause, stop, open app)
- [ ] Notification channel configuration
- [ ] When to show/hide notification
- [ ] Behavior when user dismisses notification
- [ ] Android 14+ foreground service type declaration

### Battery Optimization

- [ ] Doze mode handling - request exemption?
- [ ] App Standby buckets - impact on tracking
- [ ] Battery Saver mode - reduce functionality?
- [ ] User battery settings guidance
- [ ] Manufacturer-specific optimizations (Samsung, Xiaomi, etc.)
- [ ] Battery usage monitoring and alerts
- [ ] Adaptive GPS frequency based on battery level

### Permissions Required

- [ ] Location "Always" vs "While Using" - when to request each
- [ ] Activity Recognition permission (for step counting)
- [ ] Bluetooth permissions (for wearables)
- [ ] Notification permission (Android 13+)
- [ ] Background location rationale dialog
- [ ] Permission denial handling and re-request flow
- [ ] Settings deep-link for manually enabling permissions

---

## Notes & Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-02-23 | Continuous sessions reset at configurable times | Enables sync, prevents endless sessions |
| 2025-02-23 | Support multiple reset points (1-N per day) | Flexibility for future optimization |
| 2025-02-23 | Manual session ends continuous, auto-restarts after | Seamless user experience |
| 2025-02-23 | Hybrid activity detection (manual now, auto later) | Start simple, iterate based on data |
| 2025-02-23 | Keep data until synced, purge only as emergency | Maximize data integrity |
| 2025-02-23 | Skip privacy levels for now | Focus on core functionality first |
| 2025-02-23 | Continuous tracking OFF by default | Battery impact, permissions need consent |
| 2025-02-23 | Sensor-based trust scoring | More sensors = more trust = higher multiplier |
| 2025-02-23 | Device accuracy profiles | Account for hardware variance |
| 2025-02-23 | Centralized config file for all parameters | Easy tuning as we learn from real data |
| 2025-02-23 | Displacement-based only for Phase 1 continuous | Simplify, no stationary/stair tracking yet |
| 2025-02-23 | Server-side validation planned | Anti-gaming, but not in Phase 1 |
| 2025-02-23 | No fixed min distance/duration thresholds | "Every movement counts" via trust multiplier |
| 2025-02-23 | Chest strap HR gets higher trust than wrist HR | Chest strap is most accurate HR method |
| 2025-02-23 | Continuous toggle on Activity screen | Visible, contextual, easy to discover |
| 2025-02-23 | Red pulsing dot (◉) for continuous status indicator | Classic "recording" metaphor, stands out from green theme |
| 2025-02-23 | HR device detection via BLE + manufacturer database | Reliable identification, can't be gamed |
| 2025-02-23 | Cross-validation using Health Connect + personalized step length | Detect gaming/vehicle, uses existing biometric data |
| 2025-02-23 | Step length estimation based on height/gender/age | Gaussian distribution with ±12% σ for natural variation |
| 2025-02-23 | GPS remains primary, Health APIs for validation | Battery flexibility, cross-check capability |

