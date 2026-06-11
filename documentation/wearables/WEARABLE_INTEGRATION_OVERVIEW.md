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
> has since been **implemented**. Sections 1, 6 and 7 have been updated to reflect
> the current code; the remaining sections retain their original ecosystem research
> and design rationale.

## 1. Current State of Your App

Your BeneFit Flutter app has a **full wearable integration** under
`lib/features/wearable_integration/`:

**Implemented:**
- Extensible sensor framework (`BaseSensor<T>` pattern)
- GPS tracking with real-time streaming
- Session management (manual & continuous modes)
- User biometrics storage (height, weight)
- Offline-first sync architecture
- Bluetooth/BLE integration (`BleDataSource` + `HeartRateSensor`)
- Real-time heart rate monitoring (BLE Heart Rate Service `0x180D`)
- 3rd party health API integration: Health Connect (Android) and Apple
  HealthKit (iOS) via the `health` package, orchestrated by `HealthSyncService`
  and `HealthPlatformProvider`
- Five dedicated database tables (`wearable_devices`, `health_platform_data`,
  `session_biometric_data`, `session_motion_data`, `session_sensor_summary`)
  with matching DAOs

**Not Implemented:**
- Standalone step-counter / power-meter BLE sensors (only `HeartRateSensor`
  exists as a BLE sensor; steps/power arrive via the Health platform APIs)
- ANT+ protocol support
- Google Fit (intentionally skipped in favour of Health Connect)

---

## 2. Wearable Device Types & Connection Methods

### A. Direct Device Connection (Bluetooth BLE)

**BLE (Bluetooth Low Energy)** - The dominant technology in 2025:
- **Market Share:** 648 million Bluetooth wearables shipped in 2024
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

**IMPORTANT UPDATE FOR 2025:** Google Fit API is being **deprecated June 30, 2025**

| Platform | OS | Status | Data Types | Integration Complexity |
|----------|----|---------|-----------|-----------------------|
| **Health Connect** | Android | **New Standard (2025)** | Steps, heart rate, distance, sleep, nutrition, SpO2, VO2 max | Medium |
| **Apple HealthKit** | iOS | Active, no changes | Same as Health Connect + clinical records | Medium |
| **Samsung Health** | Android | Active (migrating to Health Connect) | Same as Health Connect | Medium |
| **Google Fit** | Android | **Deprecated after June 2025** | Steps, heart rate, distance, calories | Don't use |

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
5. **Priority System:** Health APIs as primary, BLE as fallback/real-time enhancement

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

**Testing:**
- `flutter_test` - the only test dependency; tests rely on hand-written mocks
  that extend `BaseSensor` (e.g. `test/mocks/mock_gps_sensor.dart`) rather than
  a mocking package (`mockito`/`mocktail` are **not** dependencies)
- Physical devices recommended for BLE testing

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
