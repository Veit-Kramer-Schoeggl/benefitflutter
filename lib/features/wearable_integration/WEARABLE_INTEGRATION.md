---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [WEARABLE_INTEGRATION_OVERVIEW.md](../../../documentation/wearables/WEARABLE_INTEGRATION_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../database/DATABASE.md) | [SENSORS.md](../shared/sensors/SENSORS.md)
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

We achieve approximately 95% wearable device coverage through a hybrid approach:
- **90%+ coverage** via Health Platform APIs (Health Connect/HealthKit) - covers most smartwatches and fitness trackers that sync with the phone
- **Additional 5%** via direct BLE connections - covers devices like chest strap heart rate monitors that don't sync to health platforms
- **Overlap handling** - Users can connect both types simultaneously without conflicts

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

The feature is organized into four distinct layers, each with specific responsibilities:

#### 1. Domain Layer (`domain/`)

The heart of the feature - pure business logic with zero dependencies on Flutter or external packages.

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

#### 3. Provider Layer (`providers/`)

State management and app-wide access to wearable functionality.

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

#### 4. Presentation Layer (`presentation/`)

User interface components for device management and data display.

**Screens**:
- `DeviceConnectionScreen`: Main hub for all wearable connections
- `DevicePairingScreen`: Guided BLE device pairing flow
- Session integration: Heart rate display widgets in activity screens

**Widgets**:
- Reusable UI components for device lists, connection status, heart rate display
- Self-contained with clear input/output contracts

---

## Data Flow

Understanding how data moves through the system is key to understanding the architecture.

### Flow 1: Health Platform Background Sync

**Trigger**: User connects Health Connect or periodic background sync

**Path**:
1. User taps "Connect" → `HealthPlatformProvider.connect()`
2. Provider checks if Health Connect installed → `HealthSyncService.isHealthConnectInstalled()`
3. If not installed → Show dialog with Play Store link
4. If installed → Request permissions via `HealthConnectSource.requestPermissions()`
5. Platform shows native permission dialog
6. On approval → `HealthSyncService.syncAll()` triggered
7. Service requests data from `HealthConnectSource.getHistoricalData()` for each type (steps, heart rate, distance, etc.)
8. Source calls native Health Connect APIs, fetches last 7 days
9. Data mapped from platform format to `HealthDataPoint` domain models
10. Batch inserted to local database via `HealthPlatformDataDao`
11. Provider updates state → UI shows "Connected" + last sync time

**Key Characteristics**:
- Happens in background, doesn't block UI
- All or nothing - if one type fails, others still succeed
- Idempotent - can sync multiple times safely (duplicates handled by database)
- User-controlled - only syncs when explicitly triggered or on connection

### Flow 2: BLE Real-Time Streaming

**Trigger**: User starts a workout session with BLE device connected

**Path**:
1. User starts session → `ActivityProvider.startSession(heartRateDeviceId: 'device-123')`
2. Provider calls `SensorManager.startHeartRateSensor(deviceId)`
3. Sensor manager retrieves device from `WearableDeviceDao`
4. Creates `HeartRateSensor` instance for the device
5. Sensor connects to BLE device via standard Heart Rate Service (UUID: 0x180D)
6. Subscribes to Heart Rate Measurement characteristic (UUID: 0x2A37)
7. BLE device starts sending data ~1 per second
8. Sensor parses binary BLE format → clean BPM integer
9. Emits values on stream → `SensorManager` receives
10. Manager creates `SensorDataPoint` and stores via `SessionBiometricDataDao`
11. Manager broadcasts to UI → heart rate display updates live
12. Session ends → sensor disconnected, streaming stops
13. Final statistics computed → saved to `SessionSensorSummaryDao`
14. Detailed readings marked for cleanup after successful sync

**Key Characteristics**:
- Sub-second latency from device to UI
- Streams only during active sessions (battery conscious)
- All readings stored for potential sync later
- Connection resilient - auto-reconnect on brief disconnects
- Graceful degradation - session continues if device disconnects

### Flow 3: Session Enrichment

**Trigger**: User completes a session

**Path**:
1. Session ends → `ActivityProvider.stopSession()`
2. Provider checks if Health Platform connected
3. If connected → calls `HealthPlatformProvider.enrichSession(session)`
4. Provider calls `HealthSyncService.enrichSession()`
5. Service queries `HealthPlatformDataDao` for data during session timeframe
6. Retrieves average heart rate, step count, distance, calories from health platform data
7. Returns enriched session with additional metrics
8. Provider merges BLE data (if any) with health platform data
9. Computes statistics (avg HR, max HR, heart rate zones, total steps)
10. Saves summary to `SessionSensorSummaryDao`
11. Updates session record with wearable fields populated
12. Displays complete session summary to user

**Key Characteristics**:
- Best-effort enrichment - session still valid without wearable data
- Prefers BLE data for accuracy (direct measurement)
- Falls back to health platform data if BLE unavailable
- Combines both sources when available
- Non-blocking - quick operation that doesn't delay session completion

### Flow 4: Data Cleanup After Sync

**Trigger**: Session data successfully synced to backend

**Path**:
1. `SessionSyncStrategy` uploads session + GPS + sensor data
2. Backend confirms successful receipt
3. Sync strategy calls cleanup methods on each DAO
4. `SessionBiometricDataDao.deleteBySyncedSession(sessionId)` - removes detailed heart rate readings
5. `SessionMotionDataDao.deleteBySyncedSession(sessionId)` - removes detailed cadence/power readings
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
- Daily step counts across all sources
- Historical heart rate data
- Distance traveled
- Active calories burned
- Weight measurements
- Blood oxygen levels
- Sleep data (when available)

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
- Everything Health Connect provides plus more
- Heart rate variability (HRV)
- Resting heart rate
- VO2 max estimates
- Better workout session data
- More granular sleep stages

**Limitations**:
- iOS only
- Some data requires specific devices (Apple Watch)
- Permission model is strict (good for privacy, requires careful UX)

**Implementation Strategy**:
- Same repository interface as Health Connect
- iOS-specific data types can be leveraged
- More permissive with data type requests (iOS handles unsupported gracefully)
- Better real-time capabilities than Health Connect

**Current Status**: Interface defined, implementation pending iOS testing environment

### Bluetooth Low Energy (BLE)

**What It Is**: Direct wireless connection to wearable devices using standard Bluetooth protocols

**Why We Use It**:
- Real-time data streaming (sub-second latency)
- Works with devices that don't sync to health platforms
- No internet required
- Direct control over connection
- Standard protocols mean broad compatibility

**What We Get**:
- Live heart rate during sessions
- Cadence from cycling computers
- Power from smart trainers
- Speed from foot pods
- Any BLE sensor following standard GATT services

**Limitations**:
- Requires explicit pairing
- Battery drain (active connection)
- Connection management complexity
- Limited range (10 meters typically)
- One connection per device (can't share with other apps)

**Implementation Strategy**:
- Standard BLE services only (Heart Rate Service, Cycling Speed and Cadence, etc.)
- No proprietary protocols (avoids per-vendor implementations)
- Active only during sessions (minimize battery impact)
- Auto-reconnect on brief disconnects
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

**Table**: `wearable_devices`

**Purpose**: Track all connected devices (BLE and Health Platform)

**Lifecycle**: Permanent (until user disconnects)

**Contents**:
- Device identification and naming
- Device type and capabilities
- Connection status
- Integration source
- Last sync timestamp
- Metadata (battery level, firmware, signal strength)

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

#### Category 5: Health Platform Historical Data

**Table**: `health_platform_data`

**Purpose**: Background-synced health data not tied to specific sessions

**Lifecycle**: 90-day retention (configurable)

**Contents**:
- Daily step counts
- Resting heart rate trends
- Sleep duration and quality
- Weight measurements
- VO2 max estimates
- Background-synced (not session-specific)

**Why Separate**: Completely different lifecycle from session data. This data exists whether or not users do sessions. Used for profile enrichment and overall health trends.

**Cleanup Strategy**: Automatic deletion of data older than 90 days to prevent unbounded growth.

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

Wearable integration is added via database migration (v3 → v4).

**Migration Philosophy**:
- Additive only (no breaking changes to existing tables)
- GPS pattern remains unchanged (proven pattern)
- New tables follow same naming and structure conventions
- Backward compatible (app still works with v3 database)

---

## Synchronization Strategy

### Background Sync Philosophy

Wearable data syncs opportunistically in the background, separate from session sync.

**Why Background?**:
- Health platforms update throughout the day
- Don't want to sync 7 days of data during session end (blocking)
- Better UX (perceived performance)
- Users can trigger manual sync if needed

**Trigger Points**:
1. Initial connection (immediate sync after permission grant)
2. Manual sync button (user-initiated)
3. App foreground (when app opened, if >4 hours since last sync)
4. Periodic background sync (when platform supports it)

### Sync Window

Default sync window: **Last 7 days**

**Rationale**:
- Captures recent activity without massive data transfer
- Most users care about recent trends, not entire history
- Faster initial sync (better UX)
- Reduces API calls to health platforms
- Prevents database bloat

**Configurable**: Can be adjusted if users request longer history.

### Conflict Resolution

When multiple sources provide the same data type (e.g., both BLE and Health Connect have heart rate for a session):

**Priority Rules**:
1. **Direct BLE measurement > Health Platform data** (more accurate, real-time)
2. **Session-linked data > Background synced data** (explicit association)
3. **Newer data > Older data** (when timestamps conflict)

**Implementation**: During session enrichment, BLE data is preferred if available. Health platform data fills gaps.

### Data Deduplication

Health platforms may return duplicate data points (same timestamp, same value).

**Strategy**:
- Database unique constraint on (user_id, data_type, start_time)
- INSERT OR REPLACE pattern
- Latest sync timestamp preserved

**Benefit**: Multiple syncs are safe (idempotent).

### Cleanup Strategy

Borrowed from GPS point cleanup pattern (proven reliable):

**Detailed Data** (biometric/motion readings):
- Stored during session
- Synced to backend with session
- Deleted after confirmed sync
- Strategy: Only delete on confirmed backend receipt
- Survives app crashes (not deleted until safe)

**Summary Data**:
- Computed when session ends
- Stored permanently
- Never deleted
- Available for offline session viewing

**Health Platform Data**:
- Automatic cleanup of data older than 90 days
- Periodic maintenance task
- Prevents unbounded growth
- User-invisible

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
7. **If permissions granted**: Shows "Connected" + sync progress
8. **If permissions denied**: Dialog explains why needed + "Open Settings" button → Opens app settings
9. Success: Shows last sync time, data types synced

**BLE Device Connection**:
1. User navigates to Profile → Connected Devices
2. Taps "Add BLE Device" button
3. Guided pairing screen appears
4. Shows Bluetooth permission request if needed
5. Begins scanning for nearby heart rate monitors
6. Shows discovered devices in real-time list
7. User taps device to pair
8. Connection attempt with progress indicator
9. Success: Device added to connected list with connection status
10. Can test connection with live heart rate preview

### During Session Flow

**With BLE Device**:
1. User starts session
2. If BLE device recently connected → Automatically connects
3. Shows heart rate display widget at top of activity screen
4. Live BPM updates every second
5. Pulse animation syncs with readings
6. Shows connection status (connected, reconnecting, disconnected)
7. If disconnected → Shows "Reconnecting..." but session continues
8. Session ends → Statistics include heart rate zones

**Without Wearable**:
1. User starts session
2. No wearable widgets shown (clean UI)
3. Session functions normally
4. GPS tracking works as before
5. Session saved without biometric data
6. Can still view in session history

### Session History with Wearable Data

**Enhanced Session Summary**:
- Heart rate chart (if available)
- Average, max, min heart rate displayed
- Heart rate zones breakdown (time in each zone)
- Calories burned estimate
- Steps during session
- Device badges showing data sources

**Without Wearable Data**:
- Traditional session view (GPS map, distance, duration)
- No heart rate section shown
- Everything else works identically

### Settings and Management

**Connected Devices Screen**:
- Health Platform card (connection status, last sync, manual sync button)
- List of BLE devices (connection status, battery level, signal strength)
- Each device can be disconnected individually
- Tapping device shows details and test connection

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
- UI adapts (shows/hides widgets based on connection status)
- No error dialogs during sessions (non-blocking errors)
- Background errors logged but don't interrupt user

### User-Actionable Errors

When errors occur, guide users to resolution:

**Health Connect Not Installed**:
- Error message: "Health Connect is not installed on your device."
- Action button: "Install from Play Store"
- Button opens Play Store directly to Health Connect
- User returns to app → Automatic retry

**Permissions Denied**:
- Error message: "Health platform permissions were denied. Please grant permissions in your device settings."
- Action button: "Open Settings"
- Button opens app settings directly
- User returns to app → Automatic retry

**BLE Device Not Found**:
- Scan times out after 15 seconds
- Shows message: "No heart rate monitors found nearby. Make sure your device is powered on and in pairing mode."
- Action button: "Scan Again"
- Doesn't block user (can cancel and continue without device)

**Connection Lost During Session**:
- Non-intrusive notification: "Heart rate monitor disconnected"
- Small reconnecting indicator
- Session continues normally
- Automatic reconnection attempts in background
- No data loss (partial data still saved)

### Error Recovery

**Automatic Recovery**:
- BLE disconnects → Auto-reconnect attempts (3 tries with exponential backoff)
- Sync failures → Retry on next sync trigger
- Permission errors → Re-check permissions on next app start
- API errors → Exponential backoff with max retry limit

**User-Initiated Recovery**:
- Manual sync button (forces immediate sync attempt)
- Device reconnect button (forces BLE reconnection)
- Clear error state button (dismisses persistent errors)

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
- Indexes on frequently queried fields (user_id, session_id, timestamps)
- Batch insertions for sync operations
- Cleanup runs in background thread
- Query result limits to prevent large reads

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

**Network Efficiency**:
- Health platform data cached locally
- Sync only deltas where possible
- Retry logic with backoff
- Offline-first (works without network)

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
