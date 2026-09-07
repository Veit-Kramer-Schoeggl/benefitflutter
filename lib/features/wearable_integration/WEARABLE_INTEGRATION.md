---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [WEARABLE_INTEGRATION_OVERVIEW.md](../../../documentation/wearables/WEARABLE_INTEGRATION_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../database/DATABASE.md) | [SENSORS.md](../shared/sensors/SENSORS.md)
>
> **Last verified against code:** 2026-08-28 (branch `feat/phase-2-background-tracking`)
---

# Wearable Integration Architecture

## Table of Contents
1. [Overview](#overview)
2. [Strategic Approach](#strategic-approach)
3. [Architecture Philosophy](#architecture-philosophy)
4. [Component Organization](#component-organization)
5. [Data Flow](#data-flow)
6. [Integration Sources](#integration-sources)
7. [Database Strategy](#database-strategy)
8. [Synchronization Strategy](#synchronization-strategy)
9. [User Experience Flow](#user-experience-flow)
10. [Error Handling Philosophy](#error-handling-philosophy)
11. [Extensibility & Future Growth](#extensibility--future-growth)

---

## Overview

The wearable integration system enables the BeneFit app to collect health and fitness data from various sources including direct Bluetooth connections to wearable devices and platform-level health APIs like Health Connect (Android) and HealthKit (iOS).

### Core Objectives

**Primary Goal**: Enrich user workout sessions with accurate biometric data (heart rate, steps, cadence, etc.) from wearable devices.

**Secondary Goals**:
- Maximize device compatibility without implementing custom protocols for every brand
- Provide real-time biometric feedback during active sessions
- Sync historical health data for comprehensive user profiles
- Maintain functionality when wearables are unavailable (graceful degradation)
- Minimize battery drain and network usage
- Ensure data privacy and user control

### Coverage Strategy

**Target** (design goal, not a measured result): approximately 95% wearable device coverage through a hybrid approach:
- **90%+ coverage** via Health Platform APIs (Health Connect/HealthKit) - covers most smartwatches and fitness trackers that sync with the phone
- **Additional 5%** via direct BLE connections - covers devices like chest strap heart rate monitors that don't sync to health platforms
- **Overlap handling** - Users can connect both types simultaneously without conflicts

See the status table below for what of this is actually reachable in the shipped app today.

### Implementation Status (2026-08-28)

This document describes both the built system and its design intent. Use this table
to tell the two apart before reading the ~900 lines that follow.

| Capability | Status |
|---|---|
| Health platform sync (7-day window) | **Working** when triggered — `syncAll()` runs 6 syncers (health_sync_service.dart:105-116); on Android only 5 yield data (resting HR has no Health Connect permission) |
| Health platform UI: Connect / Sync Now / last-sync label | **Working** (device_connection_screen.dart:240-357) |
| Automatic sync right after a successful connect | **Not reachable** — `connect()` only syncs when `_currentUserId` is set (health_platform_provider.dart:78-79), and the only method that sets it, `initialize()` (:48-49), has no caller in `lib/` |
| BLE scan + pair | **Working per screen instance** (device_pairing_screen.dart:83-146) |
| Live heart rate during a session | **Code complete, not reachable** — no caller passes `heartRateDeviceId` (activity_screen.dart:107) |
| Session HR summary (avg/max/min) | **Working only if live HR runs** (activity_provider.dart:508-538) |
| Paired-device persistence | **Missing** — `wearable_devices` is written by the demo seeder only (seed_service.dart:302-315) |
| Heart-rate zones | **Not implemented** — never computed; UI shows a hard-coded placeholder (session_summary_screen.dart:299-334) |
| Health-platform session enrichment | **Not wired** — `enrichSession()` has no production caller |
| 90-day health-data cleanup | **Not wired** — `cleanupOldData()` has no caller |
| Backend sync + post-sync cleanup | **Stub** — `SessionSyncStrategy.uploadToRemote()` returns `true` without a network call (session_sync_strategy.dart:23-32) |
| BLE auto-reconnect, battery readout | **Not implemented** (ble_data_source.dart:236-241) |

---

## Strategic Approach

### The Hybrid Model

Rather than choosing between direct device integration and health platform APIs, we implement both and let them complement each other.

**Why Hybrid?**

1. **Broad Compatibility**: Health platforms handle the complexity of integrating with hundreds of device types
2. **Real-Time Capability**: Direct BLE connections provide sub-second latency for live heart rate during workouts
3. **Vendor Independence**: Not locked into any single platform or device ecosystem
4. **User Choice**: Users can mix and match devices based on their preferences and needs

### Integration Layers

The system is organized into three integration tiers:

**Tier 1: Health Platform APIs**
- Primary integration method
- Handles 90%+ of users
- Provides historical data (daily steps, resting heart rate, sleep, weight)
- Zero configuration for devices already syncing to phone
- Platform-managed permissions and privacy

**Tier 2: Direct BLE Connections**
- Secondary integration for real-time needs
- Targets specific use cases (live heart rate during sessions)
- Uses standard Bluetooth protocols (GATT services)
- Requires explicit device pairing
- Best for dedicated fitness hardware (chest straps, cycling sensors)

**Tier 3: Manual Entry**
- Fallback for any scenario
- Ensures app functionality without wearables
- User-entered data for sessions without device data
- Maintains data completeness

---

## Architecture Philosophy

### Domain-Driven Design

The architecture follows domain-driven design principles with clear boundaries between concerns.

**Core Principle**: The domain layer knows nothing about implementation details. Whether data comes from Bluetooth, Health Connect, or manual entry is invisible to the business logic.

**Benefits**:
- Adding new integration sources doesn't require changing session logic
- Testing is straightforward with mockable interfaces
- Migration to different platforms or protocols is isolated
- Business rules remain consistent regardless of data source

### Source Agnostic Data Models

All health data, regardless of source, flows through unified domain models:

**WearableDevice**: Represents any connected device (BLE, Health Platform, or virtual)
- Source-agnostic identification
- Capability-based querying (supports heart rate? supports steps?)
- Connection status abstraction
- Metadata flexibility for source-specific details

**SensorDataPoint**: Real-time sensor readings during sessions
- Generic value + timestamp + type structure
- Works for heart rate from BLE or Health Connect
- Extensible to new sensor types
- Consistent regardless of source

**HealthDataPoint**: Historical health platform data
- Background-synced daily metrics
- Session-independent
- Used to enrich user profiles and provide context

### Repository Pattern

We use the repository pattern to abstract data sources behind clean interfaces.

**WearableRepository Interface**:
- Defines operations all sources must support
- Device discovery and connection management
- Historical data retrieval
- Permission handling
- Source-agnostic return types

**Implementations**:
- `HealthConnectSource` implements for Android Health Connect
- `HealthKitSource` implements for iOS HealthKit
- `BleDataSource` implements for Bluetooth devices
- Future sources implement same interface

This pattern means the rest of the app doesn't care where data comes from - it just asks the repository for what it needs.

---

## Component Organization

### Layer Structure

The feature is organized into four distinct layers, each with specific responsibilities.
The feature folder itself holds only two of them (`domain/`, `data/`); the provider and
the UI live outside `lib/features/wearable_integration/` for historical reasons:

#### 1. Domain Layer (`domain/`)

The heart of the feature - pure business logic with no Flutter dependency. The only
external package used is `uuid`, for id generation (`sensor_data_point.dart:2`,
`health_data_type.dart:2`; `wearable_device.dart` needs only `dart:convert`).

**Responsibilities**:
- Define core data models (WearableDevice, SensorDataPoint, HealthDataPoint)
- Define business enums (SensorType, ConnectionStatus, IntegrationSource)
- Specify repository interfaces
- No implementation details, only contracts

**Why Pure?**:
- Domain models can be tested without Flutter framework
- Business logic is portable across platforms
- Changes to implementation don't affect domain
- Clear separation of "what" from "how"

#### 2. Data Layer (`data/`)

Implements the domain contracts with concrete integrations.

**Sub-layers**:

**Sources** (`data/sources/`):
- Platform-specific implementations of WearableRepository
- `HealthConnectSource`: Android Health Connect integration
- `HealthKitSource`: iOS HealthKit integration
- `BleDataSource`: Bluetooth Low Energy device handling
- Maps external data formats to domain models

**Services** (`data/services/`):
- Higher-level orchestration of data sources
- `HealthSyncService`: Manages periodic background sync from health platforms
- Handles batch operations (sync all data types at once)
- Coordinates between sources and storage

**DAOs** (`data/daos/`):
- Database access objects for local storage
- `HealthPlatformDataDao`: Historical health data storage
- `SessionBiometricDataDao`: Real-time biometric readings during sessions
- `SessionMotionDataDao`: Real-time motion data during sessions
- `SessionSensorSummaryDao`: Aggregated session statistics
- `WearableDeviceDao`: Device registry and connection tracking

**Sensors** (`data/sensors/`):
- Real-time data streaming from BLE devices
- `HeartRateSensor`: Connects to standard BLE heart rate monitors
- Parses BLE characteristic data
- Provides clean data streams to the app

#### 3. Provider Layer (`lib/providers/health_platform_provider.dart`)

State management and app-wide access to wearable functionality. This layer lives
outside the feature folder: the single file is `lib/providers/health_platform_provider.dart`.

**HealthPlatformProvider**:
- Connection state (connected, syncing, error)
- Permission management
- Sync operations (manual sync, background sync)
- Last sync timestamp tracking
- Error state management
- Notifies UI of state changes

**Why Provider Pattern?**:
- Single source of truth for connection status
- UI automatically updates when state changes
- Decouples UI from business logic
- Easy to test with mock providers

#### 4. Presentation Layer (`lib/presentation/screens/wearable/`)

User interface components for device management and data display. Also outside the
feature folder; the real files are `device_connection_screen.dart`,
`device_pairing_screen.dart` and `widgets/heart_rate_display.dart`.

**Screens**:
- `DeviceConnectionScreen`: Main hub for all wearable connections
- `DevicePairingScreen`: Guided BLE device pairing flow
- Session integration: Heart rate display widgets in activity screens

**Widgets**:
- Reusable UI components for device lists, connection status, heart rate display
- Self-contained with clear input/output contracts
- Note: only `HeartRateDisplayCompact` is used (activity_screen.dart:284). The full
  `HeartRateDisplay` widget (heart_rate_display.dart:10) has no call site.

### BLE Source Lifecycle & Instance Ownership

**Status: known gap.** This one fact explains most of the "not reachable" rows in the
status table above.

`BleDataSource` keeps *all* pairing and connection state in plain instance fields —
`_discoveredDevices`, `_connectedDevices`, `_heartRateSensors`
(ble_data_source.dart:13-15). Nothing is persisted and nothing is shared.

Today three independent instances exist at runtime, each with its own empty maps:

| Owner | Created at | Sees |
|---|---|---|
| `DevicePairingScreen` | device_pairing_screen.dart:21 | the device the user just paired |
| `DeviceConnectionScreen` | device_connection_screen.dart:31 | nothing — its own map is always empty |
| `ActivityProvider` | activity_provider.dart:108 (no instance injected in main.dart:185-194) | nothing |

Consequences:
- A device paired on the pairing screen is invisible to the connected-devices list
  that the user is returned to (device_connection_screen.dart:50).
- `ActivityProvider.startSession(heartRateDeviceId: …)` would throw
  `Device not connected` from `startStreaming` (ble_data_source.dart:188-191), because
  that instance never paired anything.
- Everything is lost on dispose; nothing is written to `wearable_devices`.

Making live heart rate work end-to-end requires all three of:
1. **One shared `BleDataSource`** — e.g. registered in `main.dart` and injected into
   `ActivityProvider` through its existing `bleDataSource:` constructor seam
   (activity_provider.dart:101-109).
2. **Persistence of paired devices** in `wearable_devices` via `WearableDeviceDao`,
   so pairings survive an app restart.
3. **A UI that passes the paired device id into `startSession()`** — see Flow 2.

---

## Data Flow

Understanding how data moves through the system is key to understanding the architecture.

### Flow 1: Health Platform Background Sync

**Trigger**: User connects Health Connect or periodic background sync

**Path**:
1. User taps "Connect" → `DeviceConnectionScreen._handleHealthPlatformConnect()`
2. Screen checks if Health Connect installed → `HealthPlatformProvider.isHealthConnectInstalled()` (→ `HealthSyncService.isHealthConnectInstalled()`)
3. If not installed → Show dialog with Play Store link
4. If installed → `HealthPlatformProvider.connect()` requests permissions via `HealthSyncService.requestPermissions()` (delegates to the active source's `requestPermissions()`)
5. Platform shows native permission dialog
6. On approval → `HealthPlatformProvider.connect()` triggers `syncAll()` → `HealthSyncService.syncAll()`
7. Service requests data from the source's `getHistoricalData()` for each type (steps, heart rate, distance, etc.)
8. Source calls native Health Connect APIs, fetches last 7 days (`daysBack` default 7)
9. Data mapped from platform format to `HealthDataPoint` domain models
10. Batch inserted to local database via `HealthPlatformDataDao.insertBatch()`
11. Provider updates state → UI shows "Connected" + last sync time

> **userId contract:** both sources hard-code an **empty** `userId` when they build a
> `HealthDataPoint` (health_connect_source.dart:186, healthkit_source.dart:166).
> `HealthSyncService` stamps the real one via `copyWith(userId: userId)` immediately
> before the insert (health_sync_service.dart:144-149). Never insert a source result
> directly — `health_platform_data.user_id` is a `FOREIGN KEY … REFERENCES users(id)`
> (database_helper.dart:409) and foreign keys are enforced per connection
> (`PRAGMA foreign_keys = ON`, database_helper.dart:71-73), so the insert would fail.

**Key Characteristics**:
- Happens in background, doesn't block UI
- All or nothing - if one type fails, others still succeed
- **NOT idempotent today** - every sync re-inserts the whole window under fresh UUIDs
  (see [Data Deduplication](#data-deduplication))
- User-controlled - only syncs when explicitly triggered; the automatic sync after
  `connect()` is currently skipped (see [Trigger Points](#background-sync-philosophy))

### Flow 2: BLE Real-Time Streaming

> **Status (2026-08): the plumbing below exists but is NOT reachable in the shipped app.**
> The only production caller is `activity_screen.dart:107`, which calls
> `provider.startSession()` **without** a device id, so `_heartRateDeviceId` stays null
> (activity_provider.dart:303) and `_startHeartRateTracking()` never runs
> (activity_provider.dart:351-353). Even with an id, `ActivityProvider` constructs its
> *own* `BleDataSource` (activity_provider.dart:108; `main.dart:185-194` injects none)
> whose `_heartRateSensors` map is empty, so `startStreaming` would throw
> `Device not connected` (ble_data_source.dart:188-191). Wiring this up needs
> (a) one shared `BleDataSource` and (b) a UI that passes the paired device id into
> `startSession()` — see [BLE Source Lifecycle & Instance Ownership](#ble-source-lifecycle--instance-ownership).

**Trigger**: User starts a workout session with BLE device connected

**Path**:
1. User starts session → `ActivityProvider.startSession(heartRateDeviceId: 'device-123')`
   — the API supports it (activity_provider.dart:288); no production caller passes an id today
2. Provider calls its private `_startHeartRateTracking()` helper
3. Helper calls `BleDataSource.startStreaming(deviceId, SensorType.heartRate)`
4. `BleDataSource` drives the previously paired `HeartRateSensor` for the device
5. Sensor connects to BLE device via standard Heart Rate Service (UUID: 0x180D)
6. Subscribes to Heart Rate Measurement characteristic (UUID: 0x2A37)
7. BLE device starts sending data ~1 per second
8. Sensor parses binary BLE format → clean BPM integer
9. Provider subscribes via `BleDataSource.getSensorStream(deviceId, SensorType.heartRate)` → emits `SensorDataPoint`
10. `ActivityProvider._onHeartRatePoint()` stores the reading via `SessionBiometricDataDao.insert()`
11. Provider updates `_currentHeartRate` and calls `notifyListeners()` → heart rate display updates live
12. Session ends → `_stopHeartRateTracking()` cancels the subscription and calls `BleDataSource.stopStreaming()`
13. Final statistics computed → saved to `SessionSensorSummaryDao`
14. Detailed readings remain locally until session cleanup (see Flow 4)

**Key Characteristics**:
- Sub-second latency from device to UI
- Streams only during active sessions (battery conscious)
- All readings stored for potential sync later
- Disconnects update the sensor status; automatic reconnection is not yet implemented (planned)
- Graceful degradation - session continues if device disconnects

### Flow 3: Session Enrichment

**Trigger**: User completes a session

**Path** (current implementation — BLE summary):
1. Session ends → `ActivityProvider.stopSession()`
2. Heart rate tracking stopped (`_stopHeartRateTracking()`)
3. `_calculateHeartRateStats()` computes avg / max / min HR from the collected BLE readings
4. Completed `Session` is built with `avgHeartRate`, `maxHeartRate`, `minHeartRate`, `hasWearableData`, `connectedDeviceIds` (activity_provider.dart:508-527)
5. If BLE heart-rate data exists, `_buildSessionSummary()` (activity_provider.dart:1020-1033) creates a `SessionSensorSummary` (avg/max/min HR + `dataSources: ['ble:<deviceId>']`). Session row and summary are then persisted **atomically in one transaction** via `_sessionRepository.finalizeSession(completedSession, summary: summary)` (activity_provider.dart:532-538 → session_repository_impl.dart:111-129), which runs `SessionDao.update` and `SessionSensorSummaryDao.upsert` on the same txn. There is no separate `updateSession()` + `upsert()` call pair and no `_createSessionSummary()` method.
6. Displays complete session summary to user

> **Secondary completion path:** `_completeSessionOnUserChange()` (activity_provider.dart:196-241),
> which runs when the user logs out or switches while a session is active, writes only the
> session row via `updateSession()` (:232) — it persists **no** summary.

> **Note**: Heart-rate zones are dead code today. `heart_rate_zones` is never written
> (`_buildSessionSummary()` sets no zones, activity_provider.dart:1020-1033),
> `HeartRateZone.fromHeartRate()` (heart_rate_display.dart:342) is never called, and the
> only widget that accepts a zone — the full `HeartRateDisplay` (heart_rate_display.dart:10-26)
> — is not used anywhere. The activity screen renders `HeartRateDisplayCompact`
> (activity_screen.dart:284), whose constructor has no zone parameter
> (heart_rate_display.dart:267-273).

**Health-platform enrichment** (capability available, not yet wired into session completion):
- `HealthPlatformProvider.enrichSession(session)` → `HealthSyncService.enrichSession(session)`
- Queries `HealthPlatformDataDao` for the session timeframe (avg heart rate, daily steps, total distance, total calories)
- Returns an enriched `Session` via `copyWith(...)` (it does **not** save a summary or merge BLE data)

**Key Characteristics**:
- Best-effort enrichment - session still valid without wearable data
- Current summaries are built from BLE data; health-platform enrichment is an available-but-unwired capability
- Non-blocking - quick operation that doesn't delay session completion

### Flow 4: Data Cleanup After Sync

**Trigger**: Session data successfully synced to backend

> **Status**: The DAO cleanup primitives below exist, but `SessionSyncStrategy.uploadToRemote()` is currently a stub and does not yet invoke them. The flow describes the intended cleanup pattern once backend sync is wired up.

**Path**:
1. `SessionSyncStrategy` uploads session + GPS + sensor data
2. Backend confirms successful receipt
3. Sync strategy calls cleanup methods on each DAO
4. `SessionBiometricDataDao.deleteBySession(sessionId)` - removes detailed heart rate readings
5. `SessionMotionDataDao.deleteBySession(sessionId)` - removes detailed cadence/power readings
6. GPS points also cleaned up (existing pattern)
7. Summary data in `SessionSensorSummaryDao` remains (permanent record)
8. Session record remains with aggregated stats

**Key Characteristics**:
- Mirrors GPS cleanup pattern (consistency)
- Only deletes after confirmed sync (safety)
- Keeps summaries for offline viewing
- Reduces local storage usage
- Maintains data integrity

---

## Integration Sources

### Health Connect (Android)

**What It Is**: Google's unified health data platform for Android (API 26+)

**Why We Use It**:
- Pre-integrated with most fitness apps and wearables
- Users already trust it (central privacy controls)
- Single API for hundreds of device types
- OS-level permission management
- Handles device communication complexity

**What We Get**:

*Synced today* — `HealthSyncService.syncAll()` calls exactly six syncers, identical on
both platforms (health_sync_service.dart:111-116):
- Daily step counts across all sources
- Historical heart rate data
- Distance traveled
- Active calories burned
- Weight measurements
- Resting heart rate — **but** `RESTING_HEART_RATE` is deliberately absent from the
  Android permission set (health_connect_source.dart:83-93 notes it is unsupported by
  Health Connect), and the failed fetch is swallowed by a `catch` that returns `[]`
  (health_connect_source.dart:178-190). In practice five types land on Android.

*Permission requested but never synced*: blood oxygen and height
(health_connect_source.dart:89-90) — no `syncBloodOxygen()` / height syncer exists.

*Neither requested nor synced*: sleep — it is missing from the permission list
(health_connect_source.dart:83-93) even though `_mapToHealthType` maps it to
`SLEEP_SESSION` (health_connect_source.dart:283-284). Also not available: HRV and
VO2 max (`_mapToHealthType` returns null for VO2 max, :280-282).

**Limitations**:
- Not installed by default (requires user to install from Play Store)
- Some data types not supported (HRV, resting heart rate vary by device)
- Historical only - not suitable for real-time session tracking
- Aggregated data - can't distinguish sources if multiple devices

**Implementation Strategy**:
- Detect if installed before requesting permissions
- Guide user to Play Store if not installed
- Clear error messages if permissions denied
- Offer to open app settings for permission grants
- Request only supported data types (avoid errors)
- Sync conservatively (7 days of history, not entire lifetime)

### HealthKit (iOS)

**What It Is**: Apple's health data platform (iOS 8+)

**Why We Use It**:
- Pre-installed on all iOS devices
- Excellent device compatibility (Apple Watch, etc.)
- Rich data types including HRV and resting heart rate
- Strong privacy model
- Seamless integration

**What We Get**:

In practice, **exactly the same six types as Health Connect** — `HealthSyncService` runs
one platform-agnostic sync loop for both platforms (health_sync_service.dart:111-116).
Resting heart rate does work here, because iOS requests the permission
(healthkit_source.dart:87).

The wider iOS permission set is requested but never used:
- HRV, blood oxygen and workouts are in the request (healthkit_source.dart:80-91)
  but no syncer ever fetches them
- VO2 max maps to `null` in `_mapToHealthType` (healthkit_source.dart:260-262) and
  `workout` falls through to `default: return null` (:265-266), so with the current
  `health` package mapping neither can be fetched at all
- Sleep stages are mappable (`SLEEP_SESSION`, :263-264) but neither permission-requested
  nor synced

**Limitations**:
- iOS only
- Some data requires specific devices (Apple Watch)
- Permission model is strict (good for privacy, requires careful UX)
- **No real-time capability**: `getSensorStream()` returns null and `startStreaming()` /
  `stopStreaming()` are no-ops (healthkit_source.dart:126-144)

**Implementation Strategy** (partly aspirational):
- Same repository interface as Health Connect — **implemented**
- iOS-specific data types can be leveraged — **planned**; the sync loop is shared and
  makes no iOS-specific calls
- More permissive with data type requests (iOS handles unsupported gracefully) —
  **implemented** (10 types requested vs. 7 on Android)
- ~~Better real-time capabilities than Health Connect~~ — **wrong**: HealthKit streaming
  is explicitly unsupported here (healthkit_source.dart:126-144); real-time comes from
  BLE only

**Current Status**: `HealthKitSource` is fully implemented against the `WearableRepository` interface; end-to-end validation on physical iOS hardware is still pending.

### Bluetooth Low Energy (BLE)

**What It Is**: Direct wireless connection to wearable devices using standard Bluetooth protocols

**Why We Use It**:
- Real-time data streaming (sub-second latency)
- Works with devices that don't sync to health platforms
- No internet required
- Direct control over connection
- Standard protocols mean broad compatibility

**What We Get**:
- Live heart rate during sessions (the only BLE sensor type implemented today)
- Cadence from cycling computers (planned)
- Power from smart trainers (planned)
- Speed from foot pods (planned)
- Any BLE sensor following standard GATT services (planned)

**Limitations**:
- Requires explicit pairing
- Battery drain (active connection)
- Connection management complexity
- Limited range (10 meters typically)
- One connection per device (can't share with other apps)

**Implementation Strategy**:
- Standard BLE services only (currently the Heart Rate Service; Cycling Speed and Cadence, etc. are planned)
- No proprietary protocols (avoids per-vendor implementations)
- Active only during sessions (minimize battery impact)
- Auto-reconnect on brief disconnects (planned, not yet implemented)
- Clear connection status indicators
- Graceful degradation if device disconnects

**Supported Devices**:
- Any heart rate monitor supporting standard Heart Rate Service
- Examples: Polar H10, Garmin HRM-Pro, Wahoo TICKR, generic chest straps
- Future: Cycling computers, power meters, foot pods

---

## Database Strategy

### Category-Based Data Separation

We separate wearable data into categories based on data characteristics and lifecycle.

**Rationale**: Different data types have different storage needs, retention policies, and access patterns.

#### Category 1: Device Registry

> **Status: not wired.** The table and `WearableDeviceDao` exist
> (database_helper.dart:309-327), but **no runtime code writes them**. Pairing and
> connection state live only in the in-memory maps of `BleDataSource`
> (ble_data_source.dart:13-15), and the only writer of `wearable_devices` in the whole
> app is the demo seeder (`_seedWearableDevices`, seed_service.dart:302-315).
> "Lifecycle: permanent" below therefore describes the *intent* — in reality device
> pairings are lost as soon as the screen or the app is disposed.

**Table**: `wearable_devices`

**Purpose**: Track all connected devices (BLE and Health Platform)

**Lifecycle**: Permanent (until user disconnects) — *intended; see status note above*

**Contents**:
- Device identification and naming
- Device type and capabilities
- Connection status
- Integration source
- Last sync timestamp
- Metadata (battery level, firmware, signal strength) — *model supports it, never
  populated at runtime*: `_mapToWearableDevice()` passes no metadata
  (ble_data_source.dart:280-298), so the `WearableDevice.batteryLevel` /
  `.signalStrength` getters (wearable_device.dart:142-160) always return null for a
  real device. Only seeded devices carry metadata (seed_data.dart:560, 585).

**Why Separate**: Devices exist independently of sessions. Users may connect a device before ever starting a session.

#### Category 2: Real-Time Biometric Data

**Table**: `session_biometric_data`

**Purpose**: Store detailed biometric readings during active sessions

**Lifecycle**: Temporary (deleted after successful sync)

**Contents**:
- Heart rate readings (BPM) with timestamps
- Heart rate variability (HRV) measurements
- Blood oxygen levels (SpO2)
- Body temperature readings
- Associated with specific session
- Linked to source device

**Why Separate**: High volume, fine-grained data (potentially one reading per second). Storage-intensive but only needed until synced to backend.

**Storage Pattern**: Similar to GPS points - detailed during session, cleaned up after sync.

#### Category 3: Real-Time Motion Data

**Table**: `session_motion_data`

**Purpose**: Store motion-related sensor readings during sessions

**Lifecycle**: Temporary (deleted after successful sync)

**Contents**:
- Cadence (steps per minute, RPM)
- Power output (watts)
- Stride length
- Ground contact time
- Step count (cumulative)
- Associated with specific session
- Linked to source device

**Why Separate**: Different data characteristics from biometrics. Cycling power and running cadence are separate concerns from heart rate.

**Benefits of Separation**:
- Query efficiency (don't mix unrelated data types)
- Can add cycling-specific fields without affecting biometric schema
- Different indexing strategies
- Clearer code organization

#### Category 4: Session Summaries

**Table**: `session_sensor_summary`

**Purpose**: Aggregated statistics computed from detailed readings

**Lifecycle**: Permanent (kept for offline viewing)

**Contents**:
- Average, max, min heart rate for session
- Average HRV
- Heart rate zones (time in each zone)
- Total steps during session
- Average cadence and power
- Total calories burned
- Data source list (which devices contributed)

**Why Separate**: This is the permanent record. Once detailed data is synced and cleaned up, summaries remain for displaying session history offline.

**Compute Timing**: Generated when session ends, before detailed data cleanup.

> **Known schema caveat (latent read failure):** `avg_heart_rate`, `max_heart_rate` and
> `min_heart_rate` are all declared `REAL` (database_helper.dart:380-382), but
> `SessionSensorSummary.fromJson` casts max/min with `as int?`
> (sensor_data_point.dart:266-267) while only avg goes through `as num`. SQLite's REAL
> affinity converts an inserted int to a double, so reading back a summary written by
> `_buildSessionSummary()` (activity_provider.dart:1020-1033) or by the seeder can throw
> a `TypeError`. Today it surfaces as a *silently missing* summary rather than a crash,
> because `SessionSummaryScreen._loadSensorSummary()` swallows the error
> (session_summary_screen.dart:36-46). Fix either side: change the model to
> `(json['max_heart_rate'] as num?)?.round()`, or the columns to `INTEGER`. Note the
> mismatch is local to this table — the same three fields on `sessions` are `INTEGER`
> (database_helper.dart:420-422), which is why the `Session` path is unaffected.

#### Category 5: Health Platform Historical Data

**Table**: `health_platform_data`

**Purpose**: Background-synced health data not tied to specific sessions

**Lifecycle**: unbounded today — a 90-day cleanup primitive exists but nothing calls it
(see Cleanup Strategy below)

**Contents** (as actually written by the sync loop): daily step counts, heart rate,
distance, active calories, weight and resting heart rate — see
[Integration Sources](#integration-sources). Sleep, SpO2 and VO2 max are listed in the
domain enum (`HealthDataType`, health_data_type.dart:6-41) but are never synced, so no
rows of those types are ever created.

**Why Separate**: Completely different lifecycle from session data. This data exists whether or not users do sessions. Used for profile enrichment and overall health trends.

**Cleanup Strategy**: **Status: not wired.** The primitives exist —
`HealthPlatformDataDao.deleteOlderThan(cutoff)` (health_platform_data_dao.dart:249),
`HealthSyncService.cleanupOldData(cutoff)` (health_sync_service.dart:417) and
`HealthPlatformProvider.cleanupOldData()` with its 90-day cutoff
(health_platform_provider.dart:259-266) — but `cleanupOldData()` has **no caller
anywhere in `lib/`**: there is no scheduler, no app-start hook and no periodic task.
Until one is added, `health_platform_data` grows without bound (and, because syncs are
not deduplicated, it grows faster than the data warrants).

### Demo and Seed Data

**Status: seed data only.** `SeedService` writes all five wearable tables when the demo
data set is loaded (seed_service.dart:302-370):

| Table | Seeder | Runtime writer |
|---|---|---|
| `wearable_devices` | `_seedWearableDevices()` (:302) | **none** |
| `session_biometric_data` | `_seedBiometricSensorData()` (:317) | `ActivityProvider._onHeartRatePoint()` (activity_provider.dart:994) — only reachable via the dead BLE path |
| `session_motion_data` | `_seedMotionSensorData()` (:330) | **none** |
| `session_sensor_summary` | `_seedSensorSummaries()` (:343) | `SessionRepositoryImpl.finalizeSession()` (session_repository_impl.dart:111-129) |
| `health_platform_data` | `_seedHealthPlatformData()` (:359) | `HealthSyncService` syncers (health_sync_service.dart:149 etc.) |

Practical consequence for anyone inspecting the app or the database: any device shown in
the wearable UI, any motion/cadence row, and the calories and step values on a session
summary come from the seeder, not from hardware.

### Session Table Extensions

The existing `sessions` table is extended (not replaced) with wearable summary fields:

**New Fields**:
- `avg_heart_rate`, `max_heart_rate`, `min_heart_rate` (integers)
- `avg_heart_rate_variability` (float)
- `total_steps` (integer)
- `avg_cadence` (float)
- `calories_burned` (float)
- `heart_rate_zones` (JSON: {zone1: 300, zone2: 900, ...} in seconds)
- `has_wearable_data` (boolean flag)
- `connected_device_ids` (JSON array of device IDs that contributed)

**Philosophy**: Sessions remain the central entity. Wearable data enhances sessions but doesn't replace core session structure.

### Database Version Migration

The wearable tables are created by `_migrateToV4()` (database_helper.dart:307-435), which
runs in both directions:
- on a **fresh install**, called from `_onCreate` (database_helper.dart:105)
- as the **v3 → v4 step** of `_onUpgrade` (database_helper.dart:188-191)

The current schema version is **12** (`DatabaseHelper.dbVersion`,
database_helper.dart:36); migrations v5…v12 (profile image, identity verification,
password, benefit redemption, continuous tracking, …) run after the wearable step.

**Migration Philosophy**:
- Additive only (no breaking changes to existing tables)
- GPS pattern remains unchanged (proven pattern)
- New tables follow same naming and structure conventions
- `ALTER TABLE sessions ADD COLUMN` for the summary fields (database_helper.dart:419-436)
- Foreign keys are enforced per connection (`PRAGMA foreign_keys = ON` in `_onConfigure`,
  database_helper.dart:71-73), so every `ON DELETE CASCADE` above is live

A pre-v4 database is **upgraded on open**, not supported as-is — there is no code path
that runs the app against a v3 schema.

---

## Synchronization Strategy

### Background Sync Philosophy

> **Status:** aspirational. There is no background sync today — the only sync that runs is
> the user tapping "Sync Now". The philosophy below is the design intent; see
> *Trigger Points* for what actually fires.

Wearable data is intended to sync opportunistically in the background, separate from session sync.

**Why Background?**:
- Health platforms update throughout the day
- Don't want to sync 7 days of data during session end (blocking)
- Better UX (perceived performance)
- Users can trigger manual sync if needed

**Trigger Points**:

*Implemented:*
1. **Manual sync button** — the "Sync Now" button on the Connected Devices screen
   (device_connection_screen.dart:306-357). It reads the user id from `AuthProvider` and
   calls `HealthPlatformProvider.syncAll(userId)`. **This is the only trigger that
   actually runs a sync today.**

*Written but currently dead:*
2. **Initial connection** — `HealthPlatformProvider.connect()` does call `syncAll()` after
   permissions are granted, but only `if (_currentUserId != null)`
   (health_platform_provider.dart:78-79). `_currentUserId` is set exclusively by
   `initialize(userId)` (health_platform_provider.dart:48-49), and `initialize()` has **no
   caller anywhere in `lib/`** — `main.dart` constructs the provider without it
   (main.dart:196). So after a successful connect the initial sync is silently skipped.
   Wiring `initialize()` into app start (or into `DeviceConnectionScreen.initState()`)
   would also restore the connection-status check on launch (`_checkConnectionStatus()`).

*Not implemented:*
3. **App foreground sync** (>4 h since last sync) — `_handleAppResumed()` (main.dart:260-279)
   handles only the app lock and the GPS retry; it never touches `HealthPlatformProvider`.
4. **Periodic background sync** — no WorkManager, no BGTaskScheduler, no timer exists
   anywhere in `lib/`.

Note also that a ">4 h" rule has nothing durable to compare against: `_lastSyncTime` is
provider-only in-memory state (health_platform_provider.dart:15) and is lost on every app
restart.

### Sync Window

Default sync window: **Last 7 days**

**Rationale**:
- Captures recent activity without massive data transfer
- Most users care about recent trends, not entire history
- Faster initial sync (better UX)
- Reduces API calls to health platforms
- Prevents database bloat

**Configurable**: `syncAll(userId, {int daysBack = 7})` (health_sync_service.dart:105)
takes the window as a parameter, but every caller uses the default — there is no setting
and no UI for it.

### Conflict Resolution

When multiple sources provide the same data type (e.g., both BLE and Health Connect have heart rate for a session):

**Priority Rules**:
1. **Direct BLE measurement > Health Platform data** (more accurate, real-time)
2. **Session-linked data > Background synced data** (explicit association)
3. **Newer data > Older data** (when timestamps conflict)

**Implementation** (planned, not yet wired): The intended merge prefers BLE data when available and lets health platform data fill gaps. Currently this merge is not in effect — session summaries are built from BLE data only and `enrichSession()` is not invoked during session completion (see Flow 3).

### Data Deduplication

Health platforms may return duplicate data points (same timestamp, same value).

**Current behaviour: not deduplicated.** `health_platform_data.id` is a UUID primary key
and inserts do use `ConflictAlgorithm.replace` (INSERT OR REPLACE,
health_platform_data_dao.dart:22-35) — but both sources mint a **fresh** `_uuid.v4()` for
every fetched point (health_connect_source.dart:340, healthkit_source.dart:321). The
primary key therefore never collides and the replace clause never fires. Re-syncing the
same 7-day window inserts a complete duplicate set.

This is not cosmetic: the aggregate helpers sum whatever rows they find —
`getDailySteps()` adds up every steps row for the day
(health_platform_data_dao.dart:101-121) and `getTotalCalories()`
(health_platform_data_dao.dart:177) does the same — so each repeated sync inflates the
numbers. With only a manual "Sync Now" button today the blast radius is small, but it
grows with every automatic trigger that gets added.

**Planned fix**: derive a deterministic id (e.g. a hash of `dataType + startTime +
endTime + sourceApp`) so INSERT OR REPLACE can actually dedupe, or delete the window
before re-inserting it.

### Cleanup Strategy

Borrowed from GPS point cleanup pattern (proven reliable):

**Detailed Data** (biometric/motion readings) — **Status: not wired** (the pattern below
is the intent; see Flow 4):
- Stored during session
- Synced to backend with session
- Deleted after confirmed sync
- Strategy: Only delete on confirmed backend receipt
- Survives app crashes (not deleted until safe)

In reality `SessionBiometricDataDao.deleteBySession()` (session_biometric_data_dao.dart:132)
and `SessionMotionDataDao.deleteBySession()` (session_motion_data_dao.dart:132) exist but
have **zero callers in `lib/`**, because `SessionSyncStrategy.uploadToRemote()` never
reaches a backend (session_sync_strategy.dart:23-32).

**Summary Data**:
- Computed when session ends
- Stored permanently
- Never deleted
- Available for offline session viewing

**Health Platform Data** — **Status: not wired.**
- The primitives exist: `HealthPlatformDataDao.deleteOlderThan(cutoff)`
  (health_platform_data_dao.dart:249), `HealthSyncService.cleanupOldData(cutoff)`
  (health_sync_service.dart:417) and `HealthPlatformProvider.cleanupOldData()` with its
  90-day cutoff (health_platform_provider.dart:259-266)
- But `cleanupOldData()` has **no caller anywhere in `lib/`** — no scheduler, no app-start
  hook, no periodic maintenance task
- Consequence: `health_platform_data` grows without bound; the 90-day policy is intent,
  not behaviour

---

## User Experience Flow

### First-Time Connection Flow

**Goal**: Guide users through their first wearable connection with minimal friction.

**Health Platform Connection**:
1. User navigates to Profile → Connected Devices
2. Sees "Health Platform" card with "Connect" button
3. Taps Connect
4. System checks if Health Connect installed (Android)
5. **If not installed**: Dialog explains Health Connect + "Install" button → Opens Play Store
6. **If installed**: Permission dialog appears (native Android dialog)
7. **If permissions granted**: Shows a "Connected" badge and a success snackbar
   (device_connection_screen.dart:269-288, 122-128). The follow-up sync does **not** run —
   see *Trigger Points*
8. **If permissions denied**: Dialog "Connection Failed" with the provider's error text +
   an "Open Settings" button (shown only when the message contains "denied")
9. The card then shows a "Last synced: …" line — but only once a sync has actually run,
   i.e. after the user taps "Sync Now" (device_connection_screen.dart:296-302). Data types
   synced are **not** listed anywhere in the UI

**BLE Device Connection**:
1. User navigates to Profile → Connected Devices
2. Taps the **"Scan for Devices"** button (device_connection_screen.dart:412-413)
3. Guided pairing screen appears
4. Shows Bluetooth permission request if needed
5. Begins scanning for nearby heart rate monitors (15 s timeout, ble_data_source.dart:49-79)
6. Shows discovered devices in a list after the scan completes
7. User taps device to pair
8. Connection attempt with progress indicator
9. The pairing screen shows a success step and pops after 2 s
   (device_pairing_screen.dart:134-140).
   **Known bug — the device does not appear in the connected list.**
   `DeviceConnectionScreen` reloads from its *own* `BleDataSource` instance
   (device_connection_screen.dart:31, 50), which never saw the pairing performed on
   `DevicePairingScreen`'s instance (device_pairing_screen.dart:21). See
   [BLE Source Lifecycle & Instance Ownership](#ble-source-lifecycle--instance-ownership).

### During Session Flow

**With BLE Device** (describes the intended flow — see the Flow 2 status note; steps 2-8
are not reachable today):
1. User starts session
2. **No automatic connect.** The paired device id must be handed to `startSession()`, and
   no UI does this today (activity_screen.dart:107)
3. Shows heart rate display widget at top of activity screen
4. Live BPM updates every second
5. Pulse animation syncs with readings
6. Shows connection status (connected, disconnected)
7. If disconnected → Shows "Disconnected" but session continues
8. Session ends → avg / max / min heart rate are stored. **Heart-rate zones are never
   computed**: `_buildSessionSummary()` sets no `heartRateZones`
   (activity_provider.dart:1020-1033), so `session_sensor_summary.heart_rate_zones`
   stays NULL

**Without Wearable**:
1. User starts session
2. The compact heart-rate pill is rendered **unconditionally** at the top of the activity
   screen and simply shows a grey "--" when no monitor is connected
   (activity_screen.dart:281-289; heart_rate_display.dart:295-320); tapping it navigates
   to `/device-connection`
3. Session functions normally
4. GPS tracking works as before
5. Session saved without biometric data
6. Can still view in session history

### Session History with Wearable Data

**Enhanced Session Summary** — what `SessionSummaryScreen` actually renders:
- Average / max / min heart rate cards (session_summary_screen.dart:202-254), read from
  the `Session` row with the `SessionSensorSummary` as fallback (:220-223)
- Heart-rate zones: **placeholder only.** `_buildHeartRateZones()` returns hard-coded
  strings ("Zone 1 (Fat Burn) 15:30", …) behind a
  `// TODO: Parse and display heart rate zones from JSON`
  (session_summary_screen.dart:299-334). It is shown whenever a zones JSON exists — which,
  since nothing ever writes one, means only for seeded sessions
- Steps and calories rows (session_summary_screen.dart:352-368) — driven entirely by
  `SessionSensorSummary.totalSteps` / `.caloriesBurned`, neither of which
  `_buildSessionSummary()` ever sets (activity_provider.dart:1020-1033). **Seed data
  only**
- **Not implemented**: heart-rate chart, device badges showing data sources

**Without Wearable Data**:
- Traditional session view (GPS map, distance, duration)
- No heart rate section shown
- Everything else works identically

### Settings and Management

**Connected Devices Screen**:
- Health Platform card (connection status, last sync, manual sync button) —
  device_connection_screen.dart:240-357
- List of BLE devices connected *within this screen's own instance* — connection status
  only. Battery level and signal strength are **never shown**:
  `BleDataSource.getBatteryLevel()` is a TODO returning null
  (ble_data_source.dart:236-241), and although `getSignalStrength()` does read RSSI
  (ble_data_source.dart:244-252) nothing in the UI calls it. `_mapToWearableDevice()`
  writes no metadata (ble_data_source.dart:280-298), so
  `WearableDevice.batteryLevel` / `.signalStrength` (wearable_device.dart:142-160) are
  always null for a real device
- Each device can be disconnected individually
- Tapping a device opens a sheet (device_connection_screen.dart:521-552) with **Device
  Info** (type, source, status, capabilities — :554) and **Disconnect**. There is no
  test-connection action

**Permissions Management**:
- Clear messaging when permissions needed
- Direct links to system settings
- Explanation of why each permission needed
- App works without permissions (doesn't block functionality)

---

## Error Handling Philosophy

### Graceful Degradation

Core principle: **Wearable features enhance the app but are never required.**

**Implementation**:
- All wearable functionality is optional
- Sessions work without wearables
- UI adapts (shows/hides widgets based on connection status) — partly: the session summary
  hides its heart-rate card when there is no data (session_summary_screen.dart:84-87), but
  the activity screen's compact heart-rate pill is always rendered and degrades to "--"
  instead of disappearing (activity_screen.dart:281-289)
- No error dialogs during sessions (non-blocking errors)
- Background errors logged but don't interrupt user

### User-Actionable Errors

When errors occur, guide users to resolution:

**Health Connect Not Installed**:
- Dialog "Health Connect Required" with the text *"Health Connect is not installed on your
  device. Would you like to install it from the Play Store?"*
  (device_connection_screen.dart:83-87)
- Action button: **"Install"** (device_connection_screen.dart:109), opens the Play Store
  entry for `com.google.android.apps.healthdata` directly
- The service-thrown variant of the same condition reads *"Health Connect is not
  installed. Please install it from the Play Store to sync health data."*
  (health_sync_service.dart:82-84)
- **No automatic retry** when the user returns to the app — they must tap Connect again

**Permissions Denied**:
- Error message: "Health platform permissions were denied. Please grant permissions in your
  device settings." (health_platform_provider.dart:83-85)
- Action button: **"Open Settings"** (device_connection_screen.dart:142-155) — rendered
  only when the error text contains "denied", which is why the provider's wording matters
- Button opens app settings directly via `openAppSettings()` (permission_handler)
- **No automatic retry** when the user returns to the app

**BLE Device Not Found**:
- Scan times out after 15 seconds (ble_data_source.dart:49-51)
- Shows message: "No heart rate monitors found. Make sure your device is turned on and
  nearby." (device_pairing_screen.dart:107-109)
- Action button: "Scan Again" (device_pairing_screen.dart:353)
- Doesn't block user (can cancel and continue without device)

**Connection Lost During Session** — **Status: not implemented.**
- No user-visible notification is emitted. `HeartRateSensor._handleDisconnection()` only
  flips the sensor status (heart_rate_sensor.dart:186-192), and nothing subscribes to
  `onStatusChanged` (heart_rate_sensor.dart:42) — the only `onStatusChanged` listener in
  the app is `SensorManager`'s for GPS (sensor_manager.dart:70)
- Session continues normally (true — nothing depends on the sensor)
- Automatic reconnection attempts in background (planned, not yet implemented)
- No data loss (partial data still saved)

### Error Recovery

**Automatic Recovery**:
- BLE disconnects → sensor status updated; automatic reconnect with backoff is planned, not yet implemented
- Sync failures → Retry on next sync trigger (in practice: the next time the user taps
  "Sync Now")
- Permission errors → re-checking permissions on app start is **not wired**:
  `HealthPlatformProvider.initialize()` (health_platform_provider.dart:48), which would
  run `_checkConnectionStatus()`, has no caller in `lib/`. The provider therefore starts
  every launch as "disconnected"
- API errors → exponential backoff with max retry limit is planned, not yet implemented

**User-Initiated Recovery**:
- Manual sync button (device_connection_screen.dart:306-357) — the one recovery action
  that exists
- ~~Device reconnect button~~ — does not exist; there is no reconnect affordance in either
  wearable screen
- ~~Clear error state button~~ — does not exist; `HealthPlatformProvider.clearError()`
  (health_platform_provider.dart:284) has no caller in `lib/`

### Error Logging

**Debug Mode**:
- Detailed logs with timestamps and context
- Error stack traces
- State snapshots

**Production**:
- Error messages only (no stack traces)
- Privacy-conscious (no PII in logs)
- Actionable messages

---

## Extensibility & Future Growth

### Adding New Integration Sources

The repository pattern makes adding new sources straightforward.

**Process**:
1. Create new class implementing `WearableRepository`
2. Implement all interface methods for the new source
3. Map source-specific data to domain models
4. Register in dependency injection
5. UI automatically supports new source (source-agnostic)

**Examples of Future Sources**:
- Garmin Connect API (cloud integration)
- Fitbit Web API (cloud integration)
- Strava integration (cross-platform sync)
- Oura Ring API (sleep and readiness data)
- Whoop API (recovery metrics)

**No Changes Required**:
- Domain models remain unchanged
- Database schema unchanged (already generic)
- UI code unchanged (queries through repositories)
- Session logic unchanged

### Adding New Data Types

Current architecture supports new sensor types with minimal changes.

**Process**:
1. Add new value to `SensorType` enum
2. Add display name to enum
3. New sensor data flows through existing `SensorDataPoint` model
4. UI can query by type and display appropriately

**Examples of Future Data Types**:
- Running dynamics (ground contact time, vertical oscillation, stride length)
- Swimming metrics (stroke rate, SWOLF score, pool length)
- Cycling advanced (left/right balance, pedal smoothness, torque effectiveness)
- Environmental (temperature, altitude, humidity)
- Recovery metrics (HRV trends, readiness scores, sleep stages)

### Adding New Device Types

The `WearableDeviceType` enum can be extended.

**Process**:
1. Add new value to enum
2. Define capabilities for device type
3. UI uses capability queries, not device type checks

**Examples**:
- Swimming watches
- Dive computers
- GPS bike computers
- Running dynamics pods
- Body composition scales

**Capability-Driven UI**: UI checks "does this device support heart rate?" not "is this a heart rate monitor?" - More flexible.

### Platform Expansion

> **Not a drop-in today:** `HealthSyncService`'s constructor throws `UnsupportedError` on
> any platform other than Android or iOS (health_sync_service.dart:16-26), and
> `main.dart:196` constructs `HealthPlatformProvider` unconditionally. Any desktop or web
> target needs either a third `WearableRepository` implementation or a null-object source
> before the app will even start.

**Web Support**:
- Repository implementations for Web Bluetooth API
- No domain or UI changes needed
- Same device types, same capabilities
- Progressive enhancement (feature detection)

**Desktop Support** (Windows/Mac/Linux):
- Bluetooth LE on desktop
- Native health API integrations where available
- Same architecture, platform-specific implementations

### Advanced Features

**Future Enhancements Supported by Current Architecture**:

**Real-Time Coaching**:
- Heart rate zone alerts during sessions
- Pace guidance based on heart rate
- Form correction based on running dynamics
- Already have real-time data streams in place

**Training Load & Recovery**:
- HRV-based readiness scores
- Training load calculations from heart rate and duration
- Recovery time recommendations
- Data already being collected

**Social Features**:
- Live workout sharing with real-time heart rate
- Friend comparisons (who has higher avg heart rate)
- Leaderboards with physiological data
- Data ready to be shared via API

**Advanced Analytics**:
- Heart rate drift analysis (fatigue indicator)
- Efficiency metrics (pace vs heart rate)
- Physiological ceiling detection
- All raw data preserved for analysis

**Integration with Challenges**:
- Heart rate targets in challenges
- Intensity-based competition (not just distance)
- Recovery requirements between challenge sessions
- Infrastructure ready

### Testing Strategy

> **What exists today (2026-08-28).** Automated coverage of this feature is thin and
> concentrated in the domain layer:
> - `test/features/wearable_integration/domain/` — `enums_test.dart`,
>   `health_data_type_test.dart`, `wearable_device_test.dart` (pure Dart VM)
> - `test/unit/providers/health_platform_provider_test.dart`, using
>   `FakeHealthSyncService` from `test/helpers/health_fakes.dart` — the real service
>   cannot be constructed on the test host (see the platform note above), so the provider
>   is injected via `HealthPlatformProvider(syncService: …)`
> - `test/features/shared/database/migration_test.dart` — schema/migration checks against
>   `sqflite_common_ffi`
> - `test/widget/screens/activity_screen_test.dart` — asserts the compact heart-rate pill
>   renders
>
> **No tests exist** for `BleDataSource`, `HeartRateSensor`, `HealthConnectSource`,
> `HealthKitSource`, `HealthSyncService` or the five wearable DAOs. The list below is the
> **target** strategy, not a description of the suite.

**Unit Tests**:
- Domain models (already implemented)
- Repository implementations (mockable)
- Data transformation logic
- Business rule validation

**Integration Tests**:
- Source to DAO flows
- Sync orchestration
- Error handling paths
- Session enrichment

**Widget Tests**:
- UI components in isolation
- State-driven rendering
- Error state displays

**End-to-End Tests**:
- Full connection flows
- Session with wearable data
- Sync and cleanup cycles
- Multi-device scenarios

### Performance Considerations

**Database Optimization**:
- Indexes on frequently queried fields (user_id, session_id, timestamps) — implemented in
  `_migrateToV4()` (database_helper.dart:326-417 — 7 indexes across the five tables)
- Batch insertions for sync operations — implemented
  (`HealthPlatformDataDao.insertBatch`, health_platform_data_dao.dart:22-35)
- ~~Cleanup runs in background thread~~ — **no cleanup runs at all**; see
  [Cleanup Strategy](#cleanup-strategy)
- Query result limits to prevent large reads — **planned**

**Memory Management**:
- Sensor streams disposed when sessions end
- Large query results paginated
- Bitmap caching for device icons
- Provider properly disposed

**Battery Optimization**:
- BLE scanning limited to pairing screen only
- Active connections only during sessions
- Background sync throttled (not every minute)
- Location services unchanged (separate concern)

**Network Efficiency** (mostly moot today — there is no backend call to make):
- Health platform data cached locally — implemented
- Sync only deltas where possible — **not implemented**; every sync refetches the full
  7-day window and re-inserts it (see [Data Deduplication](#data-deduplication))
- Retry logic with backoff — **not implemented**
- Offline-first (works without network) — true, but by absence: `SessionSyncStrategy`
  never reaches the network (session_sync_strategy.dart:23-32)

---

## Summary

The wearable integration architecture achieves its goals through:

1. **Hybrid Approach**: Combines health platform breadth with BLE real-time capability
2. **Source Agnostic Design**: Business logic independent of data source
3. **Graceful Degradation**: Full functionality without wearables
4. **User Control**: Explicit connections, clear permissions, actionable errors
5. **Extensibility**: New sources, devices, and data types easily added
6. **Performance**: Efficient storage, smart cleanup, battery-conscious
7. **Privacy**: User-controlled permissions, minimal data retention
8. **Testability**: Clean architecture enables comprehensive testing

The result is a robust, user-friendly system that enhances the fitness tracking experience while maintaining simplicity and reliability.

> **Honest reading of that list (2026-08-28):** points 1, 2, 3, 5 and 7 describe the
> shipped code. Point 6 (performance) and point 8 (testability) describe the architecture's
> *potential* — no cleanup task runs and the feature's data/source layer has no tests. The
> hybrid model itself is currently half-live: the Health-platform arm works, the BLE arm
> does not reach the user. See [Implementation Status](#implementation-status-2026-08-28).
