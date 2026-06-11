import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/wearable_integration/domain/enums.dart';

void main() {
  group('IntegrationSource', () {
    test('toJson returns correct string', () {
      expect(IntegrationSource.ble.toJson(), 'ble');
      expect(IntegrationSource.healthConnect.toJson(), 'healthConnect');
      expect(IntegrationSource.healthKit.toJson(), 'healthKit');
      expect(IntegrationSource.manual.toJson(), 'manual');
    });

    test('fromJson creates correct enum', () {
      expect(IntegrationSource.fromJson('ble'), IntegrationSource.ble);
      expect(
        IntegrationSource.fromJson('healthConnect'),
        IntegrationSource.healthConnect,
      );
      expect(
        IntegrationSource.fromJson('healthKit'),
        IntegrationSource.healthKit,
      );
      expect(IntegrationSource.fromJson('manual'), IntegrationSource.manual);
    });

    test('fromJson returns manual for unknown value', () {
      expect(IntegrationSource.fromJson('unknown'), IntegrationSource.manual);
    });

    test('displayName returns correct string', () {
      expect(IntegrationSource.ble.displayName, 'Bluetooth');
      expect(IntegrationSource.healthConnect.displayName, 'Health Connect');
      expect(IntegrationSource.healthKit.displayName, 'Apple Health');
      expect(IntegrationSource.manual.displayName, 'Manual');
    });
  });

  group('WearableDeviceType', () {
    test('toJson returns correct string', () {
      expect(WearableDeviceType.heartRateMonitor.toJson(), 'heartRateMonitor');
      expect(WearableDeviceType.fitnessBand.toJson(), 'fitnessBand');
      expect(WearableDeviceType.smartwatch.toJson(), 'smartwatch');
    });

    test('fromJson creates correct enum', () {
      expect(
        WearableDeviceType.fromJson('heartRateMonitor'),
        WearableDeviceType.heartRateMonitor,
      );
      expect(
        WearableDeviceType.fromJson('fitnessBand'),
        WearableDeviceType.fitnessBand,
      );
      expect(
        WearableDeviceType.fromJson('smartwatch'),
        WearableDeviceType.smartwatch,
      );
    });

    test('fromJson returns unknown for invalid value', () {
      expect(
        WearableDeviceType.fromJson('invalid'),
        WearableDeviceType.unknown,
      );
    });

    test('displayName returns correct string', () {
      expect(
        WearableDeviceType.heartRateMonitor.displayName,
        'Heart Rate Monitor',
      );
      expect(WearableDeviceType.smartwatch.displayName, 'Smartwatch');
    });
  });

  group('SensorType', () {
    test('toJson returns correct string', () {
      expect(SensorType.heartRate.toJson(), 'heartRate');
      expect(SensorType.steps.toJson(), 'steps');
      expect(SensorType.cadence.toJson(), 'cadence');
    });

    test('fromJson creates correct enum', () {
      expect(SensorType.fromJson('heartRate'), SensorType.heartRate);
      expect(SensorType.fromJson('steps'), SensorType.steps);
      expect(SensorType.fromJson('cadence'), SensorType.cadence);
    });

    test('fromJson throws for unknown value', () {
      expect(() => SensorType.fromJson('invalid'), throwsArgumentError);
    });

    test('displayName returns correct string', () {
      expect(SensorType.heartRate.displayName, 'Heart Rate');
      expect(SensorType.steps.displayName, 'Steps');
      expect(SensorType.cadence.displayName, 'Cadence');
    });

    test('unit returns correct string', () {
      expect(SensorType.heartRate.unit, 'BPM');
      expect(SensorType.steps.unit, 'steps');
      expect(SensorType.power.unit, 'W');
      expect(SensorType.distance.unit, 'm');
    });

    test('isBiometric identifies biometric sensors correctly', () {
      expect(SensorType.heartRate.isBiometric, true);
      expect(SensorType.heartRateVariability.isBiometric, true);
      expect(SensorType.bloodOxygen.isBiometric, true);
      expect(SensorType.temperature.isBiometric, true);

      expect(SensorType.steps.isBiometric, false);
      expect(SensorType.cadence.isBiometric, false);
      expect(SensorType.power.isBiometric, false);
    });

    test('isMotion identifies motion sensors correctly', () {
      expect(SensorType.cadence.isMotion, true);
      expect(SensorType.power.isMotion, true);
      expect(SensorType.steps.isMotion, true);
      expect(SensorType.strideLength.isMotion, true);

      expect(SensorType.heartRate.isMotion, false);
      expect(SensorType.bloodOxygen.isMotion, false);
    });
  });

  group('ConnectionStatus', () {
    test('toJson returns correct string', () {
      expect(ConnectionStatus.disconnected.toJson(), 'disconnected');
      expect(ConnectionStatus.connected.toJson(), 'connected');
      expect(ConnectionStatus.error.toJson(), 'error');
    });

    test('fromJson creates correct enum', () {
      expect(
        ConnectionStatus.fromJson('disconnected'),
        ConnectionStatus.disconnected,
      );
      expect(
        ConnectionStatus.fromJson('connected'),
        ConnectionStatus.connected,
      );
      expect(ConnectionStatus.fromJson('error'), ConnectionStatus.error);
    });

    test('fromJson returns disconnected for unknown value', () {
      expect(
        ConnectionStatus.fromJson('unknown'),
        ConnectionStatus.disconnected,
      );
    });

    test('displayName returns correct string', () {
      expect(ConnectionStatus.disconnected.displayName, 'Disconnected');
      expect(ConnectionStatus.connected.displayName, 'Connected');
      expect(ConnectionStatus.scanning.displayName, 'Scanning...');
      expect(ConnectionStatus.connecting.displayName, 'Connecting...');
    });

    test('isConnected returns correct value', () {
      expect(ConnectionStatus.connected.isConnected, true);
      expect(ConnectionStatus.disconnected.isConnected, false);
      expect(ConnectionStatus.error.isConnected, false);
    });

    test('isTransitioning returns correct value', () {
      expect(ConnectionStatus.scanning.isTransitioning, true);
      expect(ConnectionStatus.connecting.isTransitioning, true);
      expect(ConnectionStatus.connected.isTransitioning, false);
      expect(ConnectionStatus.disconnected.isTransitioning, false);
    });
  });
}
