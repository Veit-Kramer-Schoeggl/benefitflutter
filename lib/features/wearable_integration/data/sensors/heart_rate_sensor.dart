import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:benefitflutter/features/shared/sensors/base_sensor.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_status.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_exception.dart';

/// BLE Heart Rate Sensor
/// Connects to Bluetooth Low Energy heart rate monitors using standard Heart Rate Service
/// Standard Heart Rate Service UUID: 0x180D
/// Heart Rate Measurement Characteristic UUID: 0x2A37
class HeartRateSensor extends BaseSensor<int> {
  // Standard Bluetooth SIG UUIDs for Heart Rate Service
  static final Guid _heartRateServiceUuid = Guid('0000180D-0000-1000-8000-00805f9b34fb');
  static final Guid _heartRateMeasurementUuid = Guid('00002A37-0000-1000-8000-00805f9b34fb');

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _heartRateCharacteristic;

  final StreamController<SensorStatus> _statusController = StreamController<SensorStatus>.broadcast();
  final StreamController<int> _dataController = StreamController<int>.broadcast();

  SensorStatus _status = SensorStatus.unavailable;
  StreamSubscription<List<int>>? _characteristicSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  @override
  String get sensorId => 'heart_rate_sensor';

  @override
  String get sensorName => 'Heart Rate Monitor';

  @override
  SensorStatus get status => _status;

  @override
  Stream<SensorStatus> get onStatusChanged => _statusController.stream;

  @override
  Stream<int> get onDataStream => _dataController.stream;

  // ========================================
  // INITIALIZATION
  // ========================================

  @override
  Future<bool> initialize() async {
    try {
      // Check if Bluetooth is supported on device
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        _updateStatus(SensorStatus.unavailable);
        return false;
      }

      // Check Bluetooth adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _updateStatus(SensorStatus.unavailable);
        return false;
      }

      _updateStatus(SensorStatus.available);
      return true;
    } catch (e) {
      _updateStatus(SensorStatus.error);
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    // Permissions are handled by flutter_blue_plus automatically
    // when scanning or connecting
    return true;
  }

  @override
  Future<bool> isAvailable() async {
    return await FlutterBluePlus.isSupported;
  }

  @override
  Future<bool> hasPermission() async {
    // flutter_blue_plus handles permissions internally
    return true;
  }

  // ========================================
  // CONNECTION
  // ========================================

  /// Connect to a specific heart rate monitor device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Disconnect any existing device first
      if (_connectedDevice != null) {
        await disconnect();
      }

      _connectedDevice = device;

      // Listen to connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15), license: License.free);

      // Discover services
      final services = await device.discoverServices();

      // Find Heart Rate Service
      BluetoothService? heartRateService;
      for (var service in services) {
        if (service.uuid == _heartRateServiceUuid) {
          heartRateService = service;
          break;
        }
      }

      if (heartRateService == null) {
        throw SensorException(
          sensorId: sensorId,
          message: 'Heart Rate Service not found on device',
          type: SensorExceptionType.initializationFailed,
        );
      }

      // Find Heart Rate Measurement Characteristic
      for (var characteristic in heartRateService.characteristics) {
        if (characteristic.uuid == _heartRateMeasurementUuid) {
          _heartRateCharacteristic = characteristic;
          break;
        }
      }

      if (_heartRateCharacteristic == null) {
        throw SensorException(
          sensorId: sensorId,
          message: 'Heart Rate Measurement characteristic not found',
          type: SensorExceptionType.initializationFailed,
        );
      }

      _updateStatus(SensorStatus.available);
    } catch (e) {
      _updateStatus(SensorStatus.error);
      await disconnect();
      throw SensorException(
        sensorId: sensorId,
        message: 'Failed to connect to device: $e',
        type: SensorExceptionType.initializationFailed,
      );
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }

    _heartRateCharacteristic = null;
    _updateStatus(SensorStatus.available);
  }

  void _handleDisconnection() {
    _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    _connectedDevice = null;
    _heartRateCharacteristic = null;
    _updateStatus(SensorStatus.available);
  }

  // ========================================
  // STREAMING
  // ========================================

  @override
  Future<void> startStreaming({String? sessionId}) async {
    if (_heartRateCharacteristic == null) {
      throw SensorException(
        sensorId: sensorId,
        message: 'Not connected to a heart rate monitor',
        type: SensorExceptionType.streamingFailed,
      );
    }

    try {
      // Enable notifications
      await _heartRateCharacteristic!.setNotifyValue(true);

      // Subscribe to characteristic value updates
      _characteristicSubscription = _heartRateCharacteristic!.lastValueStream.listen(
        (value) {
          final heartRate = _parseHeartRate(value);
          if (heartRate != null) {
            _dataController.add(heartRate);
          }
        },
        onError: (error) {
          _updateStatus(SensorStatus.error);
        },
      );

      _updateStatus(SensorStatus.active);
    } catch (e) {
      throw SensorException(
        sensorId: sensorId,
        message: 'Failed to start heart rate streaming: $e',
        type: SensorExceptionType.streamingFailed,
      );
    }
  }

  @override
  Future<void> stopStreaming() async {
    if (_heartRateCharacteristic != null) {
      try {
        await _heartRateCharacteristic!.setNotifyValue(false);
      } catch (e) {
        // Ignore errors when stopping
      }
    }

    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;

    // If still connected to device, return to available state
    // Otherwise stay at current status
    if (_connectedDevice != null) {
      _updateStatus(SensorStatus.available);
    }
  }

  // ========================================
  // HEART RATE PARSING
  // ========================================

  /// Parse heart rate value from BLE characteristic data
  /// Follows Bluetooth Heart Rate Measurement specification
  int? _parseHeartRate(List<int> value) {
    if (value.isEmpty) return null;

    // First byte contains flags
    final flags = value[0];

    // Bit 0: Heart Rate Value Format
    // 0 = UINT8, 1 = UINT16
    final isUint16 = (flags & 0x01) != 0;

    int heartRate;
    if (isUint16) {
      // Heart rate is 16-bit value (little-endian)
      if (value.length < 3) return null;
      heartRate = value[1] | (value[2] << 8);
    } else {
      // Heart rate is 8-bit value
      if (value.length < 2) return null;
      heartRate = value[1];
    }

    // Sanity check (typical human heart rate range)
    if (heartRate < 30 || heartRate > 250) return null;

    return heartRate;
  }

  // ========================================
  // STATUS MANAGEMENT
  // ========================================

  void _updateStatus(SensorStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
    }
  }

  // ========================================
  // DISPOSAL
  // ========================================

  @override
  Future<void> dispose() async {
    await stopStreaming();
    await disconnect();
    await _statusController.close();
    await _dataController.close();
  }

  // ========================================
  // DEVICE INFO
  // ========================================

  /// Get currently connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Check if connected to a device
  bool get isConnected => _connectedDevice != null;

  /// Get connected device name
  String? get connectedDeviceName => _connectedDevice?.platformName;

  /// Get connected device ID
  String? get connectedDeviceId => _connectedDevice?.remoteId.toString();
}
