---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [SENSORS.md](../../lib/features/shared/sensors/SENSORS.md) - Implementation details with code examples
>
> **Related:** [WEARABLE_INTEGRATION Overview](../wearables/WEARABLE_INTEGRATION_OVERVIEW.md) | [DATABASE Overview](../data/DATABASE_OVERVIEW.md)
---

# Sensor Architecture Overview

## Purpose

The sensor system provides a unified framework for accessing device sensors (GPS, accelerometer, heart rate) in the BeneFit app. It abstracts platform differences and provides a consistent interface for all sensor types.

## Key Concepts

### BaseSensor Pattern
All sensors extend a common base class that defines:
- Initialization and cleanup lifecycle
- Data streaming interface
- Error handling patterns
- Permission management

### Sensor Types

| Sensor | Data Provided | Use Case |
|--------|---------------|----------|
| **GPS** | Location, speed, altitude | Track movement and distance |
| **Accelerometer** | Motion data | Activity detection |
| **Heart Rate** | BPM, HRV | Fitness metrics |
| **Step Counter** | Step count | Walking/running stats |

> **Implementation status:** Within the shared sensor framework, only the **GPS** sensor (`GpsSensor`) is currently coordinated by `SensorManager`. A **heart rate** sensor (`HeartRateSensor`, BLE Heart Rate Service `0x180D`) is implemented separately in the `wearable_integration` module and is not coordinated by `SensorManager`. The accelerometer and step counter rows describe the intended scope of the framework; `SensorManager` contains commented-out hooks for these future sensors but does not yet manage them.

## Architecture

```
┌─────────────────────────────────────────┐
│              Session Manager            │
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│              Sensor Manager             │
│    (Coordinates multiple sensors)       │
└──────┬──────────────────────┬───────────┘
       │                      │
       ▼                      ▼
┌─────────────┐        ┌─────────────┐
│ GPS Sensor  │        │  HR Sensor  │
│(BaseSensor) │        │(BaseSensor) │
└─────────────┘        └─────────────┘
       │                      │
       ▼                      ▼
┌─────────────┐        ┌─────────────┐
│   Platform  │        │    BLE      │
│   Location  │        │  Device     │
└─────────────┘        └─────────────┘
```

## Sensor Lifecycle

1. **Initialize**
   - Check hardware/service availability and current permission status
   - Set initial sensor status (permissions are requested later, on session start)
   - Establish connections

2. **Start Streaming**
   - Begin data collection
   - Emit data through stream
   - Handle errors gracefully

3. **Process Data**
   - Filter and validate
   - Transform to app models
   - Store or display

4. **Stop & Cleanup**
   - Stop data collection
   - Release resources
   - Save final state

## GPS Sensor Specifics

The GPS sensor is the primary sensor for tracking:

| Feature | Description |
|---------|-------------|
| **High Accuracy** | Uses `LocationAccuracy.high`; points worse than 50 m accuracy are filtered out |
| **Distance Filter** | Updates every 5 meters moved (`distanceFilter: 5`) |
| **Quality Filtering** | Skips points that fail `meetsQualityRequirements()` (accuracy/age) |
| **Stream-based** | Emits validated `GpsPoint` objects through a broadcast stream |

## Data Flow

```
Platform Sensor
      │
      ▼
 Raw Data Event
      │
      ▼
 Data Validation
      │
      ▼
 Model Conversion
      │
      ▼
 Stream Emission
      │
      ▼
 UI / Storage
```

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Wearable Integration | [WEARABLE_INTEGRATION.md](../../lib/features/wearable_integration/WEARABLE_INTEGRATION.md) | [WEARABLE_INTEGRATION_OVERVIEW](../wearables/WEARABLE_INTEGRATION_OVERVIEW.md) |
| Database Schema | [DATABASE.md](../../database/DATABASE.md) | [DATABASE_OVERVIEW](../data/DATABASE_OVERVIEW.md) |
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](../screens/ACTIVITY_SCREEN_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
