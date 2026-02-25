import '../enums.dart';
import '../wearable_device.dart';
import '../sensor_data_point.dart';
import '../health_data_type.dart';

/// Abstract repository that all data sources (BLE, Health Connect, HealthKit) implement
/// This defines the contract for wearable device integration
abstract class WearableRepository {
  /// Get integration source type
  IntegrationSource get source;

  // ==================== Device Management ====================

  /// Get list of available devices (discovered or registered)
  /// - For BLE: Returns devices found during scanning
  /// - For Health APIs: Returns a virtual device representing the platform
  Future<List<WearableDevice>> getAvailableDevices();

  /// Get list of currently connected devices
  Future<List<WearableDevice>> getConnectedDevices();

  /// Connect to a specific device
  /// - For BLE: Establishes Bluetooth connection
  /// - For Health APIs: No-op (always "connected" if permissions granted)
  /// Throws exception if device not found or connection fails
  Future<void> connectDevice(String deviceId);

  /// Disconnect from a device
  /// - For BLE: Closes Bluetooth connection
  /// - For Health APIs: No-op
  Future<void> disconnectDevice(String deviceId);

  // ==================== Permission Handling ====================

  /// Request necessary permissions for this integration source
  /// - For BLE: Bluetooth + Location permissions
  /// - For Health APIs: Health data access permissions
  /// Returns true if all permissions granted
  Future<bool> requestPermissions();

  /// Check if all necessary permissions are granted
  Future<bool> hasPermissions();

  // ==================== Real-Time Streaming (BLE) ====================

  /// Get real-time sensor data stream from a connected device
  /// - For BLE: Returns stream of sensor readings as they arrive
  /// - For Health APIs: Returns null (no real-time streaming)
  ///
  /// Used during active sessions for real-time heart rate, cadence, etc.
  Stream<SensorDataPoint>? getSensorStream(String deviceId, SensorType type);

  /// Start streaming sensor data from a device
  /// - For BLE: Enables notifications on BLE characteristics
  /// - For Health APIs: No-op
  Future<void> startStreaming(String deviceId, SensorType type);

  /// Stop streaming sensor data from a device
  /// - For BLE: Disables notifications on BLE characteristics
  /// - For Health APIs: No-op
  Future<void> stopStreaming(String deviceId, SensorType type);

  // ==================== Historical Data (Health APIs) ====================

  /// Get historical health data for a date range
  /// - For BLE: Returns empty list (no historical data)
  /// - For Health APIs: Fetches data from Health Connect/HealthKit
  ///
  /// Used for background sync and enriching session data
  Future<List<HealthDataPoint>> getHistoricalData(
    HealthDataType type,
    DateTime startTime,
    DateTime endTime,
  );

  /// Get last sync time for historical data
  /// Returns null if never synced
  Future<DateTime?> getLastSyncTime();

  /// Trigger immediate sync of historical data
  /// - For BLE: No-op
  /// - For Health APIs: Fetches latest data from platform
  Future<void> syncNow();

  // ==================== Device Information ====================

  /// Get battery level for a device (if supported)
  /// Returns null if not supported or not available
  Future<int?> getBatteryLevel(String deviceId);

  /// Get signal strength for a device (if applicable)
  /// For BLE: Returns RSSI value
  /// For Health APIs: Returns null
  Future<int?> getSignalStrength(String deviceId);

  /// Cleanup and dispose resources
  /// Called when repository is no longer needed
  Future<void> dispose();
}
