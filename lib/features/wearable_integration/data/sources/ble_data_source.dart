import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/wearable_device.dart';
import '../../domain/health_data_type.dart';
import '../../domain/enums.dart';
import '../../domain/sensor_data_point.dart';
import '../../domain/repositories/wearable_repository.dart';
import '../sensors/heart_rate_sensor.dart';

/// Data source for BLE (Bluetooth Low Energy) devices
/// Implements WearableRepository to provide direct Bluetooth connections
class BleDataSource implements WearableRepository {
  final Map<String, BluetoothDevice> _discoveredDevices = {};
  final Map<String, WearableDevice> _connectedDevices = {};
  final Map<String, HeartRateSensor> _heartRateSensors = {};

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;

  // Standard Bluetooth SIG UUID for Heart Rate Service
  static final Guid _heartRateServiceUuid = Guid('0000180D-0000-1000-8000-00805f9b34fb');

  @override
  IntegrationSource get source => IntegrationSource.ble;

  // ========================================
  // DEVICE MANAGEMENT
  // ========================================

  @override
  Future<List<WearableDevice>> getAvailableDevices() async {
    if (!await FlutterBluePlus.isSupported) {
      return [];
    }

    // Return list of discovered devices
    return _discoveredDevices.values.map((device) => _mapToWearableDevice(device)).toList();
  }

  @override
  Future<List<WearableDevice>> getConnectedDevices() async {
    return _connectedDevices.values.toList();
  }

  /// Scan for BLE devices with Heart Rate Service
  Future<void> startScanning({Duration timeout = const Duration(seconds: 15)}) async {
    if (_isScanning) return;

    _discoveredDevices.clear();
    _isScanning = true;

    try {
      // Start scanning for devices with Heart Rate Service
      await FlutterBluePlus.startScan(
        withServices: [_heartRateServiceUuid],
        timeout: timeout,
      );

      // Listen for scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          _discoveredDevices[result.device.remoteId.toString()] = result.device;
        }
      });

      // Wait for scan to complete
      await Future.delayed(timeout);
      await stopScanning();
    } catch (e) {
      _isScanning = false;
      rethrow;
    }
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
    } catch (e) {
      _isScanning = false;
    }
  }

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  @override
  Future<void> connectDevice(String deviceId) async {
    // Find device in discovered devices
    final bleDevice = _discoveredDevices[deviceId];
    if (bleDevice == null) {
      throw Exception('Device not found: $deviceId');
    }

    // Create heart rate sensor and connect
    final sensor = HeartRateSensor();
    await sensor.initialize();
    await sensor.connectToDevice(bleDevice);

    // Store sensor and connected device
    _heartRateSensors[deviceId] = sensor;
    _connectedDevices[deviceId] = _mapToWearableDevice(bleDevice, isConnected: true);
  }

  @override
  Future<void> disconnectDevice(String deviceId) async {
    final sensor = _heartRateSensors[deviceId];
    if (sensor != null) {
      await sensor.disconnect();
      _heartRateSensors.remove(deviceId);
    }

    _connectedDevices.remove(deviceId);
  }

  // ========================================
  // PERMISSIONS
  // ========================================

  @override
  Future<bool> requestPermissions() async {
    // flutter_blue_plus handles permissions automatically
    // Check if Bluetooth is supported and enabled
    if (!await FlutterBluePlus.isSupported) {
      return false;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    return adapterState == BluetoothAdapterState.on;
  }

  @override
  Future<bool> hasPermissions() async {
    if (!await FlutterBluePlus.isSupported) {
      return false;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    return adapterState == BluetoothAdapterState.on;
  }

  // ========================================
  // REAL-TIME STREAMING
  // ========================================

  @override
  Stream<SensorDataPoint>? getSensorStream(String deviceId, SensorType type) {
    if (type != SensorType.heartRate) {
      return null; // Only heart rate supported for now
    }

    final sensor = _heartRateSensors[deviceId];
    if (sensor == null) return null;

    // Map heart rate values to SensorDataPoint
    return sensor.onDataStream.map((bpm) => SensorDataPoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: '', // Will be set by caller
      deviceId: deviceId,
      sensorType: SensorType.heartRate,
      value: bpm.toDouble(),
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> startStreaming(String deviceId, SensorType type) async {
    if (type != SensorType.heartRate) {
      throw UnsupportedError('Only heart rate streaming is supported');
    }

    final sensor = _heartRateSensors[deviceId];
    if (sensor == null) {
      throw Exception('Device not connected: $deviceId');
    }

    await sensor.startStreaming();
  }

  @override
  Future<void> stopStreaming(String deviceId, SensorType type) async {
    if (type != SensorType.heartRate) return;

    final sensor = _heartRateSensors[deviceId];
    if (sensor != null) {
      await sensor.stopStreaming();
    }
  }

  // ========================================
  // HISTORICAL DATA (Not supported for BLE)
  // ========================================

  @override
  Future<List<HealthDataPoint>> getHistoricalData(
    HealthDataType type,
    DateTime startTime,
    DateTime endTime,
  ) async {
    // BLE devices don't provide historical data
    return [];
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    // Not applicable for BLE
    return null;
  }

  @override
  Future<void> syncNow() async {
    // No-op for BLE devices
  }

  // ========================================
  // DEVICE INFORMATION
  // ========================================

  @override
  Future<int?> getBatteryLevel(String deviceId) async {
    // TODO: Implement battery service reading if needed
    // Battery Service UUID: 0x180F
    // Battery Level Characteristic UUID: 0x2A19
    return null;
  }

  @override
  Future<int?> getSignalStrength(String deviceId) async {
    final bleDevice = _discoveredDevices[deviceId];
    if (bleDevice == null) return null;

    // Get RSSI (signal strength)
    try {
      final rssi = await bleDevice.readRssi();
      return rssi;
    } catch (e) {
      return null;
    }
  }

  // ========================================
  // LIFECYCLE
  // ========================================

  @override
  Future<void> dispose() async {
    await stopScanning();

    // Disconnect all devices and dispose sensors
    for (var sensor in _heartRateSensors.values) {
      await sensor.dispose();
    }

    _heartRateSensors.clear();
    _connectedDevices.clear();
    _discoveredDevices.clear();
  }

  // ========================================
  // HELPERS
  // ========================================

  /// Map BluetoothDevice to WearableDevice
  WearableDevice _mapToWearableDevice(BluetoothDevice device, {bool isConnected = false}) {
    return WearableDevice(
      id: device.remoteId.toString(),
      userId: '', // Will be set by caller
      name: device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
      type: _inferDeviceType(device),
      source: IntegrationSource.ble,
      status: isConnected ? ConnectionStatus.connected : ConnectionStatus.disconnected,
      capabilities: [SensorType.heartRate], // All devices with HR service support this
    );
  }

  /// Infer device type from name/services
  WearableDeviceType _inferDeviceType(BluetoothDevice device) {
    final name = device.platformName.toLowerCase();

    if (name.contains('polar') || name.contains('h10') || name.contains('h9')) {
      return WearableDeviceType.heartRateMonitor;
    } else if (name.contains('garmin')) {
      return WearableDeviceType.smartwatch;
    } else if (name.contains('fitbit') || name.contains('mi band')) {
      return WearableDeviceType.fitnessBand;
    }

    // Default to heart rate monitor if it has the HR service
    return WearableDeviceType.heartRateMonitor;
  }

  /// Get heart rate sensor for a device
  HeartRateSensor? getSensor(String deviceId) {
    return _heartRateSensors[deviceId];
  }
}
