---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [WEARABLE_INTEGRATION.md](../../lib/features/wearable_integration/WEARABLE_INTEGRATION.md) - Implementation details with code examples
>
> **Related:** [DATABASE.md](../../database/DATABASE.md) | [SENSORS.md](../../lib/features/shared/sensors/SENSORS.md)
---

# Wearable Integration Overview

Based on the investigation of the BeneFit Flutter app codebase and research into the 2025 wearable ecosystem.

> **Note:** This document began as a pre-implementation research/recommendation
> paper on the 2025 wearable ecosystem. The wearable integration described below
> has since been **built** — with important parts not yet wired up end to end
> (see section 1). Sections 1, 6 and 7 reflect the current code; sections 2-5 and 8
> are the original 2025 ecosystem research and are deliberately left as they were.
>
> **Status:** ecosystem research from 2025; implementation status re-verified against
> the code on **2026-08-28** (branch `feat/phase-2-background-tracking`). For the
> file-and-line detail behind every claim in section 1, see
> [WEARABLE_INTEGRATION.md](../../lib/features/wearable_integration/WEARABLE_INTEGRATION.md).

## 1. Current State of Your App

Your BeneFit Flutter app has a **substantial wearable integration** under
`lib/features/wearable_integration/` — the Health-platform half works end to end; the
BLE half is built but not yet connected up:

**Implemented and working:**
- Extensible sensor framework (`BaseSensor<T>` pattern)
- GPS tracking with real-time streaming
- Session management (manual & continuous modes)
- User biometrics storage (height, weight)
- 3rd party health API integration: Health Connect (Android) and Apple
  HealthKit (iOS) via the `health` package, orchestrated by `HealthSyncService`
  and `HealthPlatformProvider` — connect, permission handling, a manual "Sync Now"
  of a 7-day window and local batch storage all work
- BLE device scan and pairing UI (`DevicePairingScreen`)
- Five dedicated database tables (`wearable_devices`, `health_platform_data`,
  `session_biometric_data`, `session_motion_data`, `session_sensor_summary`)
  with matching DAOs

**Built but NOT wired end-to-end:**
- **BLE heart-rate stack** (Heart Rate Service `0x180D`): `HeartRateSensor`,
  `BleDataSource` and the `ActivityProvider` plumbing are complete, but no UI passes a
  device id to `startSession()` (`activity_screen.dart:107`), and every screen/provider
  owns a **separate** `BleDataSource` instance (`device_pairing_screen.dart:21`,
  `device_connection_screen.dart:31`, `activity_provider.dart:108`). Live heart rate,
  the connected-device list and BLE session summaries therefore never fire in the
  shipped app.
- **Local-first storage with sync-strategy scaffolding**: `SessionSyncStrategy.uploadToRemote()`
  is a stub returning `true` without a network call (`session_sync_strategy.dart:23-32`)
  and `downloadFromRemote()` throws `UnimplementedError` (`:34-42`). No backend is wired,
  so "offline-first sync" is currently offline-only storage.
- Automatic health sync after a successful connect — the call exists but is guarded by a
  user id that nothing ever sets (`HealthPlatformProvider.initialize()` has no caller).

**Not Implemented:**
- Standalone step-counter / power-meter BLE sensors (only `HeartRateSensor`
  exists as a BLE sensor; steps/power arrive via the Health platform APIs)
- ANT+ protocol support
- Google Fit (intentionally skipped in favour of Health Connect)
- Persistence of paired BLE devices — `wearable_devices` is written only by the demo
  seeder (`seed_service.dart:302-315`)
- Heart-rate zone computation and display — the session summary shows a hard-coded
  placeholder behind a TODO (`session_summary_screen.dart:299-334`)
- Health-platform enrichment at session completion — `enrichSession()` exists but has no
  production caller
- The 90-day health-data cleanup — `cleanupOldData()` has no caller
  (`health_platform_provider.dart:260`), so `health_platform_data` grows unbounded
- Deduplication of health syncs — every sync re-inserts the window under fresh UUIDs
- BLE auto-reconnect and battery readout (`ble_data_source.dart:236-241`)
- Sleep / SpO2 / VO2 max / workout sync — `syncAll()` covers 6 types only
  (`health_sync_service.dart:111-116`), and on Android resting heart rate has no
  Health Connect permission, so 5 land in practice

---

## 2. Wearable Device Types & Connection Methods

### A. Direct Device Connection (Bluetooth BLE)

**BLE (Bluetooth Low Energy)** - The dominant technology in 2025:
- **Market Share:** 648 million Bluetooth wearables shipped (2024 figure, from the 2025 research)
- **Supported Devices:** Almost all modern wearables
- **Power Consumption:** Excellent - months on coin battery
- **Range:** ~10-30 meters

**Device Categories:**

| Device Type | Data Provided | Connection Method | Examples |
|-------------|---------------|-------------------|----------|
| **Heart Rate Monitors (HRM)** | Heart rate, HRV, calories | BLE (primary), ANT+ | Polar H10, Garmin HRM-Pro |
| **Fitness Trackers** | Steps, heart rate, sleep, calories | BLE | Fitbit, Xiaomi Mi Band, Garmin |
| **Smartwatches** | Multi-sensor (HR, GPS, steps, SpO2) | BLE + WiFi | Apple Watch, Galaxy Watch, Garmin |
| **Cycling Sensors** | Cadence, power, speed | BLE, ANT+ | Wahoo, Garmin Edge |
| **Running Pods** | Cadence, ground contact time | BLE, ANT+ | Stryd, Garmin Running Dynamics |
| **Smart Scales** | Weight, body fat %, BMI | BLE + WiFi | Withings, Fitbit Aria |

**ANT+ Protocol:**
- **Market Share:** Limited - primarily Garmin, Wahoo, some Polar/Suunto/Coros
- **Use Case:** Multi-device fitness (one HRM → multiple receivers)
- **Power:** Slightly better than BLE for multi-device scenarios
- **Android Support:** Requires special ANT+ radio (not all phones have it)

---

### B. 3rd Party Health Platform APIs

**Google Fit APIs were shut down on 30 June 2025** — Health Connect is the Android standard.

| Platform | OS | Status | Data Types | Integration Complexity |
|----------|----|---------|-----------|-----------------------|
| **Health Connect** | Android | **Android standard** | Steps, heart rate, distance, sleep, nutrition, SpO2, VO2 max | Medium |
| **Apple HealthKit** | iOS | Active, no changes | Same as Health Connect + clinical records | Medium |
| **Samsung Health** | Android | Active (migrating to Health Connect) | Same as Health Connect | Medium |
| **Google Fit** | Android | **Retired (June 2025)** | Steps, heart rate, distance, calories | Don't use |

**Key Insight:** For Android, you should integrate with **Health Connect**, not Google Fit.

**What These APIs Provide:**
- **Aggregated data** from all connected wearables (user connects their Fitbit, Garmin, etc. to Health Connect/HealthKit)
- **On-device storage** (privacy-focused)
- **Automatic syncing** from compatible devices
- **Unified data model** across different device brands

---

## 3. Connection Infrastructure Comparison

### Option A: Direct BLE Connection
**Pros:**
- Real-time data streaming
- Works offline
- Full control over data
- No dependency on user having other apps

**Cons:**
- Must support each device individually
- Complex BLE protocol implementation
- Battery drain from active scanning
- Pairing/connection management complexity

### Option B: Health Platform APIs (Health Connect/HealthKit)
**Pros:**
- Works with hundreds of devices automatically
- User's existing device ecosystems
- Simple API - no BLE complexity
- Apple/Google handle device compatibility

**Cons:**
- Requires user to set up wearable with platform first
- Data may be delayed (not real-time)
- Platform-specific (iOS vs Android)
- Less control over data quality

### Option C: Hybrid Approach (Recommended)
**Combination of both:**
- Primary: Health Connect (Android) / HealthKit (iOS) for broad compatibility
- Secondary: Direct BLE for specific devices (e.g., professional HRMs for live session tracking)

---

## 4. Popular Wearable Ecosystems

### Devices & Their Integration Paths

| Brand | Native App | Health Platform Support | Direct BLE | Recommendation |
|-------|-----------|------------------------|------------|----------------|
| **Fitbit** | Fitbit app | Health Connect, HealthKit | Restricted | Use Health APIs |
| **Garmin** | Garmin Connect | Health Connect, HealthKit | BLE + ANT+ | Use Health APIs |
| **Apple Watch** | iPhone Health | HealthKit only | Restricted | Use HealthKit |
| **Samsung Galaxy Watch** | Samsung Health | Health Connect | Limited BLE | Use Health Connect |
| **Polar** | Polar Flow | Health Connect, HealthKit | BLE (excellent) | Hybrid |
| **Wahoo** | Wahoo Fitness | Health Connect, HealthKit | BLE + ANT+ | Hybrid |
| **Xiaomi Mi Band** | Mi Fit | Limited | BLE (community) | Direct BLE |
| **Whoop** | Whoop app | Health Connect, HealthKit | Restricted | Use Health APIs |
| **Oura Ring** | Oura app | Health Connect, HealthKit | Restricted | Use Health APIs |

---

## 5. Data Types & Sensors Available

### Real-Time Sensors (BLE Direct Connection)
- **Heart Rate:** Beats per minute (BPM)
- **Heart Rate Variability (HRV):** Milliseconds between beats
- **Cadence:** Steps/minute (running) or RPM (cycling)
- **Power:** Watts (cycling, rowing)
- **Speed/Distance:** GPS or wheel sensor
- **Elevation:** Barometric altimeter
- **Temperature:** Skin or ambient

### Historical/Aggregated Data (Health APIs)
- **Steps:** Daily count
- **Distance:** Meters/kilometers
- **Calories:** Active + resting
- **Sleep:** Stages (deep, light, REM, awake)
- **SpO2:** Blood oxygen percentage
- **VO2 Max:** Cardio fitness estimate
- **Resting Heart Rate:** Daily average
- **Body Metrics:** Weight, body fat %, BMI
- **Workout Sessions:** Type, duration, heart rate zones

---

## 6. Modular Architecture (As Implemented)

The original recommendation has been realised with some adjustments. The actual
layout is:

```
lib/features/wearable_integration/
├── domain/
│   ├── enums.dart                     # IntegrationSource, WearableDeviceType,
│   │                                  #   SensorType, ConnectionStatus
│   ├── health_data_type.dart          # HealthDataType enum + HealthDataPoint model
│   ├── sensor_data_point.dart         # SensorDataPoint + SessionSensorSummary
│   ├── wearable_device.dart           # WearableDevice model
│   └── repositories/
│       └── wearable_repository.dart   # Unified abstract interface
├── data/
│   ├── sources/
│   │   ├── ble_data_source.dart       # Direct BLE connections
│   │   ├── health_connect_source.dart # Android Health Connect
│   │   └── healthkit_source.dart      # iOS HealthKit
│   ├── sensors/
│   │   └── heart_rate_sensor.dart     # Extends BaseSensor<int>
│   ├── services/
│   │   └── health_sync_service.dart   # Health platform sync orchestration
│   └── daos/
│       ├── wearable_device_dao.dart
│       ├── health_platform_data_dao.dart
│       ├── session_biometric_data_dao.dart
│       ├── session_motion_data_dao.dart
│       └── session_sensor_summary_dao.dart

lib/providers/
└── health_platform_provider.dart      # HealthPlatformProvider (ChangeNotifier)

lib/presentation/screens/wearable/
├── device_connection_screen.dart
├── device_pairing_screen.dart
└── widgets/
    └── heart_rate_display.dart        # HeartRateDisplay + Compact + HeartRateZone
```

> **Diverges from the original recommendation:** the `IntegrationSource` enum
> lives in `enums.dart` (alongside three other enums) rather than a separate
> `integration_source.dart`; there is no separate `parsers/` directory (BLE HRM
> bytes are parsed inline in `HeartRateSensor`, health mapping inline in the
> source classes); the only BLE sensor is `HeartRateSensor` (no
> `step_counter_sensor.dart` / `power_meter_sensor.dart` — steps/power come from
> the Health platform APIs); UI screens live under
> `lib/presentation/screens/wearable/` and the provider under `lib/providers/`,
> not inside the feature folder.

**Key Design Principles:**
1. **Source Abstraction:** Each data source (BLE, Health Connect, HealthKit) implements the same repository interface
2. **Sensor Extension:** New sensors extend your existing `BaseSensor<T>` pattern
3. **Platform-Specific Implementations:** Use Flutter platform channels where needed
4. **Unified Data Model:** Normalize data from all sources to common models
5. **Priority System (design intent, not implemented):** no cross-source merge exists.
   Session summaries are built from BLE readings only (`activity_provider.dart:1020-1033`)
   and `HealthSyncService.enrichSession()` (`health_sync_service.dart:302`) is never
   invoked at session completion — see WEARABLE_INTEGRATION.md → *Conflict Resolution*.

---

## 7. Flutter Packages (In Use)

**For BLE Direct Connection:**
- `flutter_blue_plus` (resolved `2.1.1`) - BLE package used by `BleDataSource`
  and `HeartRateSensor`
- `permission_handler` - For Bluetooth permissions (and `openAppSettings`)

**For Health Platform APIs:**
- `health` (resolved `13.3.1`) - Supports Health Connect + HealthKit
- Note: Handles iOS/Android differences automatically

**Other dependencies used:**
- `url_launcher` - opening the Play Store / external apps from the connection UI
- `uuid` - id generation for devices and data points
- `sqflite` - local persistence for the wearable DAOs
- `provider` - `HealthPlatformProvider` (`ChangeNotifier` / `Consumer`)

**For ANT+ (Not adopted):**
- `ant_plus` was considered for Garmin/cycling sensors but is **not** a
  dependency; ANT+ is not supported.

**Testing** (`pubspec.yaml:103-121`):
- `flutter_test` (SDK) and `integration_test` (SDK) — the latter drives
  `integration_test/app_happy_path_test.dart`
- `sqflite_common_ffi` `^2.4.2` - host-side DAO/migration tests
  (`test/features/shared/database/migration_test.dart`)
- `flutter_lints` `^6.0.0`, `flutter_launcher_icons` `^0.14.4`
- Mocks are hand-written; `mockito`/`mocktail` are **not** dependencies. Examples:
  `test/mocks/mock_gps_sensor.dart` (extends `BaseSensor`) and
  `test/helpers/health_fakes.dart` (`FakeHealthSyncService implements HealthSyncService`,
  injected via `HealthPlatformProvider(syncService: ...)`)
- **Platform constraint that shapes the tests:** `HealthSyncService`'s constructor throws
  `UnsupportedError` on anything other than Android/iOS
  (`health_sync_service.dart:16-26`), while `main.dart:196` constructs
  `HealthPlatformProvider` unconditionally. Host tests therefore *must* inject the fake.
  `ActivityProvider` offers the same kind of seams (`bleDataSource:`, `biometricDao:` —
  `activity_provider.dart:96-109`)
- Automated coverage of this feature is thin: the domain models, the provider (against the
  fake) and the schema are tested; `BleDataSource`, `HeartRateSensor`, the two health
  sources, `HealthSyncService` and the five wearable DAOs have **no tests**
- Physical devices remain required for BLE testing

---

## 8. Integration Complexity Estimate

| Approach | Development Effort | Device Coverage | Real-Time Capability |
|----------|-------------------|-----------------|---------------------|
| **Health APIs Only** | Low (2-3 weeks) | 90% of users | No (delayed sync) |
| **BLE Direct Only** | High (8-12 weeks) | 40% (per device) | Yes |
| **Hybrid (Recommended)** | Medium (4-6 weeks) | 95% of users | Yes (for BLE devices) |

---

## Sources

- [ANT vs. Bluetooth Protocol: What to Choose for Fitness Devices](https://stormotion.io/blog/ant-bluetooth/)
- [Comprehensive list of wireless sensors in wearable devices (BLE, BT, ANT+)](https://tryterra.co/blog/comprehensive-list-of-wireless-sensors-in-wearable-devices-ble-bt-ant-645acad09949)
- [BLE Integration into App: How-to Guide for Fitness Devices](https://stormotion.io/blog/how-to-integrate-ble-fitness-devices-into-app/)
- [HealthKit vs Google Fit: Best API for Fitness & Wellness Apps](https://www.diversido.io/blog/how-apples-healthkit-and-google-fit-apis-help-in-health-and-fitness-apps-development)
- [Google Fit API Deprecation: What to Know About Health Connect](https://www.thryve.health/blog/google-fit-api-deprecation-and-the-new-health-connect-by-android-what-thryve-customers-need-to-know)
- [Google Fit Vs. Samsung Health Vs. Apple Health: Which API Should You Use?](https://www.cprime.com/resources/blog/google-fit-vs-samsung-health-vs-apple-health-which-api-should-you-use/)
