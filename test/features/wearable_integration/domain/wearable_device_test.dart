import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/wearable_integration/domain/wearable_device.dart';
import 'package:benefitflutter/features/wearable_integration/domain/enums.dart';

void main() {
  group('WearableDevice', () {
    final testTime = DateTime(2025, 12, 9, 10, 0);

    group('Constructor', () {
      test('sets createdAt and updatedAt to now if not provided', () {
        final before = DateTime.now();
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );
        final after = DateTime.now();

        expect(device.createdAt.isAfter(before) || device.createdAt.isAtSameMomentAs(before), true);
        expect(device.createdAt.isBefore(after) || device.createdAt.isAtSameMomentAs(after), true);
        expect(device.updatedAt.isAfter(before) || device.updatedAt.isAtSameMomentAs(before), true);
        expect(device.updatedAt.isBefore(after) || device.updatedAt.isAtSameMomentAs(after), true);
      });

      test('uses provided createdAt and updatedAt', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
          createdAt: testTime,
          updatedAt: testTime,
        );

        expect(device.createdAt, testTime);
        expect(device.updatedAt, testTime);
      });
    });

    group('copyWith', () {
      late WearableDevice original;

      setUp(() {
        original = WearableDevice(
          id: 'test-device',
          name: 'Polar H10',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
          lastSyncTime: testTime,
          metadata: {'batteryLevel': 85},
          createdAt: testTime,
          updatedAt: testTime,
        );
      });

      test('creates copy with same values when no params provided', () {
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.type, original.type);
        expect(copy.status, original.status);
      });

      test('updates only specified fields', () {
        final newTime = testTime.add(const Duration(hours: 1));
        final copy = original.copyWith(
          status: ConnectionStatus.disconnected,
          lastSyncTime: newTime,
        );

        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.status, ConnectionStatus.disconnected); // Changed
        expect(copy.lastSyncTime, newTime); // Changed
      });
    });

    group('toJson / fromJson', () {
      test('converts to JSON correctly', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Polar H10',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate, SensorType.heartRateVariability],
          userId: 'user1',
          lastSyncTime: testTime,
          metadata: {'batteryLevel': 85, 'firmwareVersion': '1.0.0'},
          createdAt: testTime,
          updatedAt: testTime,
        );

        final json = device.toJson();

        expect(json['id'], 'test-device');
        expect(json['name'], 'Polar H10');
        expect(json['device_type'], 'heartRateMonitor');
        expect(json['integration_source'], 'ble');
        expect(json['connection_status'], 'connected');
        expect(json['capabilities'], isNotNull);
        expect(json['user_id'], 'user1');
        expect(json['last_sync_time'], testTime.millisecondsSinceEpoch);
        expect(json['metadata'], isNotNull);
        expect(json['created_at'], testTime.millisecondsSinceEpoch);
        expect(json['updated_at'], testTime.millisecondsSinceEpoch);
      });

      test('converts from JSON correctly', () {
        final json = {
          'id': 'test-device',
          'name': 'Polar H10',
          'device_type': 'heartRateMonitor',
          'integration_source': 'ble',
          'connection_status': 'connected',
          'capabilities': '["heartRate","heartRateVariability"]',
          'user_id': 'user1',
          'last_sync_time': testTime.millisecondsSinceEpoch,
          'metadata': '{"batteryLevel":85,"firmwareVersion":"1.0.0"}',
          'created_at': testTime.millisecondsSinceEpoch,
          'updated_at': testTime.millisecondsSinceEpoch,
        };

        final device = WearableDevice.fromJson(json);

        expect(device.id, 'test-device');
        expect(device.name, 'Polar H10');
        expect(device.type, WearableDeviceType.heartRateMonitor);
        expect(device.source, IntegrationSource.ble);
        expect(device.status, ConnectionStatus.connected);
        expect(device.capabilities, [SensorType.heartRate, SensorType.heartRateVariability]);
        expect(device.userId, 'user1');
        expect(device.lastSyncTime, testTime);
        expect(device.metadata, {'batteryLevel': 85, 'firmwareVersion': '1.0.0'});
        expect(device.createdAt, testTime);
        expect(device.updatedAt, testTime);
      });

      test('round-trip conversion works', () {
        final original = WearableDevice(
          id: 'test-device',
          name: 'Polar H10',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
          metadata: {'test': 'data'},
          createdAt: testTime,
          updatedAt: testTime,
        );

        final json = original.toJson();
        final restored = WearableDevice.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.type, original.type);
        expect(restored.source, original.source);
        expect(restored.status, original.status);
        expect(restored.capabilities, original.capabilities);
        expect(restored.userId, original.userId);
      });

      test('handles null optional fields', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
          createdAt: testTime,
          updatedAt: testTime,
        );

        final json = device.toJson();
        expect(json['last_sync_time'], isNull);
        expect(json['metadata'], isNull);

        final restored = WearableDevice.fromJson(json);
        expect(restored.lastSyncTime, isNull);
        expect(restored.metadata, isNull);
      });
    });

    group('Connection Status', () {
      test('isConnected returns true when connected', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        expect(device.isConnected, true);
      });

      test('isConnected returns false when disconnected', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.disconnected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        expect(device.isConnected, false);
      });

      test('isConnected returns false when error', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.error,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        expect(device.isConnected, false);
      });
    });

    group('Capability Checks', () {
      test('supportsHeartRate returns true when capability present', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate, SensorType.steps],
          userId: 'user1',
        );

        expect(device.supportsHeartRate, true);
      });

      test('supportsHeartRate returns false when capability not present', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.fitnessBand,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.steps],
          userId: 'user1',
        );

        expect(device.supportsHeartRate, false);
      });

      test('supportsSteps returns true when capability present', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.fitnessBand,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.steps, SensorType.distance],
          userId: 'user1',
        );

        expect(device.supportsSteps, true);
      });

      test('supportsPower returns true when capability present', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.cyclingSensor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.power, SensorType.cadence],
          userId: 'user1',
        );

        expect(device.supportsPower, true);
      });

      test('supportsCadence returns true when capability present', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.cyclingSensor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.cadence],
          userId: 'user1',
        );

        expect(device.supportsCadence, true);
      });
    });

    group('Metadata Getters', () {
      test('batteryLevel returns value from metadata', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
          metadata: {'batteryLevel': 85},
        );

        expect(device.batteryLevel, 85);
      });

      test('batteryLevel returns null when not in metadata', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        expect(device.batteryLevel, isNull);
      });

      test('firmwareVersion returns value from metadata', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
          metadata: {'firmwareVersion': '1.2.3'},
        );

        expect(device.firmwareVersion, '1.2.3');
      });

      test('firmwareVersion returns null when not in metadata', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        expect(device.firmwareVersion, isNull);
      });

      test('signalStrength returns value for BLE devices', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
          metadata: {'rssi': -65},
        );

        expect(device.signalStrength, -65);
      });

      test('signalStrength returns null for non-BLE devices', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Health Connect',
          type: WearableDeviceType.healthPlatform,
          source: IntegrationSource.healthConnect,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
          metadata: {'rssi': -65}, // Has rssi but not BLE
        );

        expect(device.signalStrength, isNull);
      });
    });

    group('Equality', () {
      test('devices with same id and userId are equal', () {
        final device1 = WearableDevice(
          id: 'test-device',
          name: 'Device 1',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        final device2 = WearableDevice(
          id: 'test-device',
          name: 'Device 2', // Different name
          type: WearableDeviceType.fitnessBand, // Different type
          source: IntegrationSource.ble,
          status: ConnectionStatus.disconnected, // Different status
          capabilities: [SensorType.steps], // Different capabilities
          userId: 'user1',
        );

        expect(device1 == device2, true);
        expect(device1.hashCode, device2.hashCode);
      });

      test('devices with different ids are not equal', () {
        final device1 = WearableDevice(
          id: 'test-device-1',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        final device2 = WearableDevice(
          id: 'test-device-2',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        expect(device1 == device2, false);
      });

      test('devices with different userIds are not equal', () {
        final device1 = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        final device2 = WearableDevice(
          id: 'test-device',
          name: 'Test Device',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user2',
        );

        expect(device1 == device2, false);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final device = WearableDevice(
          id: 'test-device',
          name: 'Polar H10',
          type: WearableDeviceType.heartRateMonitor,
          source: IntegrationSource.ble,
          status: ConnectionStatus.connected,
          capabilities: [SensorType.heartRate],
          userId: 'user1',
        );

        final str = device.toString();
        expect(str, contains('test-device'));
        expect(str, contains('Polar H10'));
        expect(str, contains('Heart Rate Monitor'));
        expect(str, contains('Bluetooth'));
        expect(str, contains('Connected'));
      });
    });
  });
}
