import 'dart:convert';
import 'enums.dart';

/// Represents a connected wearable device (BLE or Health Platform)
class WearableDevice {
  /// Unique identifier (UUID for BLE, platform name for Health APIs)
  final String id;

  /// Display name of the device
  final String name;

  /// Type of device
  final WearableDeviceType type;

  /// Integration source (BLE, Health Connect, HealthKit)
  final IntegrationSource source;

  /// Current connection status
  final ConnectionStatus status;

  /// List of sensor capabilities this device supports
  final List<SensorType> capabilities;

  /// User ID this device belongs to
  final String userId;

  /// Last time data was synced from this device
  final DateTime? lastSyncTime;

  /// Additional metadata (battery level, firmware version, etc.)
  final Map<String, dynamic>? metadata;

  /// When this device was first registered
  final DateTime createdAt;

  /// When this device was last updated
  final DateTime updatedAt;

  WearableDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.source,
    required this.status,
    required this.capabilities,
    required this.userId,
    this.lastSyncTime,
    this.metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create a copy with updated fields
  WearableDevice copyWith({
    String? id,
    String? name,
    WearableDeviceType? type,
    IntegrationSource? source,
    ConnectionStatus? status,
    List<SensorType>? capabilities,
    String? userId,
    DateTime? lastSyncTime,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WearableDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      source: source ?? this.source,
      status: status ?? this.status,
      capabilities: capabilities ?? this.capabilities,
      userId: userId ?? this.userId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'device_type': type.toJson(),
      'integration_source': source.toJson(),
      'connection_status': status.toJson(),
      'capabilities': jsonEncode(capabilities.map((c) => c.toJson()).toList()),
      'user_id': userId,
      'last_sync_time': lastSyncTime?.millisecondsSinceEpoch,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON (database row)
  factory WearableDevice.fromJson(Map<String, dynamic> json) {
    final capabilitiesJson = json['capabilities'] as String;
    final capabilitiesList = (jsonDecode(capabilitiesJson) as List)
        .map((e) => SensorType.fromJson(e as String))
        .toList();

    return WearableDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      type: WearableDeviceType.fromJson(json['device_type'] as String),
      source: IntegrationSource.fromJson(json['integration_source'] as String),
      status: ConnectionStatus.fromJson(json['connection_status'] as String),
      capabilities: capabilitiesList,
      userId: json['user_id'] as String,
      lastSyncTime: json['last_sync_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_sync_time'] as int)
          : null,
      metadata: json['metadata'] != null
          ? jsonDecode(json['metadata'] as String) as Map<String, dynamic>
          : null,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  /// Whether this device is currently connected
  bool get isConnected => status.isConnected;

  /// Whether this device supports heart rate monitoring
  bool get supportsHeartRate =>
      capabilities.contains(SensorType.heartRate);

  /// Whether this device supports step counting
  bool get supportsSteps => capabilities.contains(SensorType.steps);

  /// Whether this device supports power measurement
  bool get supportsPower => capabilities.contains(SensorType.power);

  /// Whether this device supports cadence measurement
  bool get supportsCadence => capabilities.contains(SensorType.cadence);

  /// Get battery level from metadata (if available)
  int? get batteryLevel {
    if (metadata == null) return null;
    final battery = metadata!['batteryLevel'];
    return battery is int ? battery : null;
  }

  /// Get firmware version from metadata (if available)
  String? get firmwareVersion {
    if (metadata == null) return null;
    final firmware = metadata!['firmwareVersion'];
    return firmware is String ? firmware : null;
  }

  /// Get signal strength (RSSI) for BLE devices
  int? get signalStrength {
    if (source != IntegrationSource.ble || metadata == null) return null;
    final rssi = metadata!['rssi'];
    return rssi is int ? rssi : null;
  }

  @override
  String toString() {
    return 'WearableDevice(id: $id, name: $name, type: ${type.displayName}, '
        'source: ${source.displayName}, status: ${status.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WearableDevice &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}
