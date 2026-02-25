/// Integration source for wearable devices and health data
enum IntegrationSource {
  /// Direct Bluetooth Low Energy connection
  ble,

  /// Android Health Connect API
  healthConnect,

  /// iOS HealthKit API
  healthKit,

  /// Manual entry by user
  manual;

  /// Convert to string for database storage
  String toJson() => name;

  /// Create from string
  static IntegrationSource fromJson(String json) {
    return IntegrationSource.values.firstWhere(
      (e) => e.name == json,
      orElse: () => IntegrationSource.manual,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case IntegrationSource.ble:
        return 'Bluetooth';
      case IntegrationSource.healthConnect:
        return 'Health Connect';
      case IntegrationSource.healthKit:
        return 'Apple Health';
      case IntegrationSource.manual:
        return 'Manual';
    }
  }
}

/// Type of wearable device
enum WearableDeviceType {
  /// Dedicated heart rate monitor (e.g., Polar H10, Garmin HRM-Pro)
  heartRateMonitor,

  /// Fitness band (e.g., Fitbit, Xiaomi Mi Band)
  fitnessBand,

  /// Smartwatch (e.g., Apple Watch, Garmin, Samsung Galaxy Watch)
  smartwatch,

  /// Cycling sensor (cadence, power meter, speed)
  cyclingSensor,

  /// Running pod (cadence, ground contact time)
  runningPod,

  /// Smart scale (weight, body fat, BMI)
  smartScale,

  /// Health platform integration (Health Connect / HealthKit)
  healthPlatform,

  /// Unknown or unrecognized device
  unknown;

  /// Convert to string for database storage
  String toJson() => name;

  /// Create from string
  static WearableDeviceType fromJson(String json) {
    return WearableDeviceType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => WearableDeviceType.unknown,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case WearableDeviceType.heartRateMonitor:
        return 'Heart Rate Monitor';
      case WearableDeviceType.fitnessBand:
        return 'Fitness Band';
      case WearableDeviceType.smartwatch:
        return 'Smartwatch';
      case WearableDeviceType.cyclingSensor:
        return 'Cycling Sensor';
      case WearableDeviceType.runningPod:
        return 'Running Pod';
      case WearableDeviceType.smartScale:
        return 'Smart Scale';
      case WearableDeviceType.healthPlatform:
        return 'Health Platform';
      case WearableDeviceType.unknown:
        return 'Unknown Device';
    }
  }
}

/// Type of sensor data
enum SensorType {
  /// Heart rate in beats per minute (BPM)
  heartRate,

  /// Heart rate variability in milliseconds
  heartRateVariability,

  /// Step count
  steps,

  /// Cadence (steps/min for running, RPM for cycling)
  cadence,

  /// Power in watts (cycling, rowing)
  power,

  /// Speed in meters per second
  speed,

  /// Distance in meters
  distance,

  /// Elevation in meters
  elevation,

  /// Blood oxygen saturation (SpO2) in percentage
  bloodOxygen,

  /// Temperature in celsius
  temperature,

  /// Calories burned
  calories,

  /// Stride length in meters
  strideLength;

  /// Convert to string for database storage
  String toJson() => name;

  /// Create from string
  static SensorType fromJson(String json) {
    return SensorType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => throw ArgumentError('Unknown sensor type: $json'),
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case SensorType.heartRate:
        return 'Heart Rate';
      case SensorType.heartRateVariability:
        return 'Heart Rate Variability';
      case SensorType.steps:
        return 'Steps';
      case SensorType.cadence:
        return 'Cadence';
      case SensorType.power:
        return 'Power';
      case SensorType.speed:
        return 'Speed';
      case SensorType.distance:
        return 'Distance';
      case SensorType.elevation:
        return 'Elevation';
      case SensorType.bloodOxygen:
        return 'Blood Oxygen';
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.calories:
        return 'Calories';
      case SensorType.strideLength:
        return 'Stride Length';
    }
  }

  /// Unit of measurement for this sensor type
  String get unit {
    switch (this) {
      case SensorType.heartRate:
        return 'BPM';
      case SensorType.heartRateVariability:
        return 'ms';
      case SensorType.steps:
        return 'steps';
      case SensorType.cadence:
        return 'RPM';
      case SensorType.power:
        return 'W';
      case SensorType.speed:
        return 'm/s';
      case SensorType.distance:
        return 'm';
      case SensorType.elevation:
        return 'm';
      case SensorType.bloodOxygen:
        return '%';
      case SensorType.temperature:
        return '°C';
      case SensorType.calories:
        return 'kcal';
      case SensorType.strideLength:
        return 'm';
    }
  }

  /// Whether this is a biometric sensor (vs motion sensor)
  bool get isBiometric {
    return this == SensorType.heartRate ||
        this == SensorType.heartRateVariability ||
        this == SensorType.bloodOxygen ||
        this == SensorType.temperature;
  }

  /// Whether this is a motion sensor (vs biometric sensor)
  bool get isMotion {
    return this == SensorType.cadence ||
        this == SensorType.power ||
        this == SensorType.steps ||
        this == SensorType.strideLength;
  }
}

/// Connection status of a wearable device
enum ConnectionStatus {
  /// Device is disconnected
  disconnected,

  /// Scanning for devices
  scanning,

  /// Connecting to device
  connecting,

  /// Device is connected and ready
  connected,

  /// Connection error occurred
  error;

  /// Convert to string for database storage
  String toJson() => name;

  /// Create from string
  static ConnectionStatus fromJson(String json) {
    return ConnectionStatus.values.firstWhere(
      (e) => e.name == json,
      orElse: () => ConnectionStatus.disconnected,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.scanning:
        return 'Scanning...';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  /// Whether the device is currently connected
  bool get isConnected => this == ConnectionStatus.connected;

  /// Whether the device is in a transitioning state
  bool get isTransitioning =>
      this == ConnectionStatus.scanning || this == ConnectionStatus.connecting;
}
