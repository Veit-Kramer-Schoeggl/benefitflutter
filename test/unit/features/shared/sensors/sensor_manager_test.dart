import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_manager.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_status.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import '../../../../mocks/mock_gps_sensor.dart';

void main() {
  group('SensorManager', () {
    late SensorManager sensorManager;
    late MockGpsSensor mockGpsSensor;

    setUp(() {
      mockGpsSensor = MockGpsSensor();
      sensorManager = SensorManager(gpsSensor: mockGpsSensor);
    });

    tearDown(() async {
      await sensorManager.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully with available GPS', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);

        // Act
        await sensorManager.initialize();

        // Assert
        expect(sensorManager.isInitialized, true);
        expect(
          sensorManager.sensorStatuses['mock_gps_sensor'],
          SensorStatus.available,
        );
      });

      test('should track GPS as unavailable when hardware missing', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(false);

        // Act
        await sensorManager.initialize();

        // Assert
        expect(sensorManager.isInitialized, true);
        expect(
          sensorManager.sensorStatuses['mock_gps_sensor'],
          SensorStatus.unavailable,
        );
      });

      test('should track GPS as denied when permission not granted', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(false);

        // Act
        await sensorManager.initialize();

        // Assert
        expect(sensorManager.isInitialized, true);
        expect(
          sensorManager.sensorStatuses['mock_gps_sensor'],
          SensorStatus.denied,
        );
      });

      test('should not reinitialize if already initialized', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();
        final firstInitStatus = sensorManager.sensorStatuses['mock_gps_sensor'];

        // Act - try to initialize again
        await sensorManager.initialize();

        // Assert - status should remain the same
        expect(
          sensorManager.sensorStatuses['mock_gps_sensor'],
          equals(firstInitStatus),
        );
      });

      test('should subscribe to GPS status changes', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);

        // Act
        await sensorManager.initialize();
        await mockGpsSensor.startStreaming(sessionId: 'test-123');

        // Give status update time to propagate
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(
          sensorManager.sensorStatuses['mock_gps_sensor'],
          SensorStatus.active,
        );
      });
    });

    group('Permission Management', () {
      test('should check all permissions correctly', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();

        // Act
        final permissions = await sensorManager.checkAllPermissions();

        // Assert
        expect(permissions['gps'], true);
      });

      test('should report denied permissions correctly', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(false);
        await sensorManager.initialize();

        // Act
        final permissions = await sensorManager.checkAllPermissions();

        // Assert
        expect(permissions['gps'], false);
      });

      test('should request all permissions', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();

        // Act
        final results = await sensorManager.requestAllPermissions();

        // Assert
        expect(results['gps'], true);
      });
    });

    group('Session Management', () {
      test('should start session with GPS when available', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();

        // Act
        final results = await sensorManager.startSession(
          sessionId: 'test-session-123',
          activityType: ActivityType.running,
        );

        // Assert
        expect(results['gps'], true);
        expect(mockGpsSensor.isStreaming, true);
        expect(mockGpsSensor.currentSessionId, 'test-session-123');
      });

      test('should fail to start GPS when permissions denied', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(false);
        await sensorManager.initialize();

        // Act
        final results = await sensorManager.startSession(
          sessionId: 'test-session-123',
          activityType: ActivityType.running,
        );

        // Assert
        expect(results['gps'], false);
        expect(mockGpsSensor.isStreaming, false);
      });

      test('should stop all sensors on session stop', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();
        await sensorManager.startSession(
          sessionId: 'test-session-123',
          activityType: ActivityType.running,
        );

        // Act
        await sensorManager.stopSession();

        // Assert
        expect(mockGpsSensor.isStreaming, false);
      });

      test('should throw if not initialized before starting session', () async {
        // Act & Assert
        expect(
          () => sensorManager.startSession(
            sessionId: 'test-session-123',
            activityType: ActivityType.running,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Sensor Access', () {
      test('should provide access to GPS sensor', () async {
        // Arrange & Act
        final gpsSensor = sensorManager.gpsSensor;

        // Assert
        expect(gpsSensor, isNotNull);
        expect(gpsSensor.sensorId, 'mock_gps_sensor');
      });
    });

    group('Status Tracking', () {
      test('should return immutable sensor statuses map', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();

        // Act
        final statuses = sensorManager.sensorStatuses;

        // Assert - should not be able to modify the returned map
        expect(
          () => statuses['mock_gps_sensor'] = SensorStatus.error,
          throwsA(anything),
        );
      });

      test('should update statuses when sensor status changes', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();

        // Act - simulate status change
        await mockGpsSensor.startStreaming(sessionId: 'test-123');

        // Give status update time to propagate
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(
          sensorManager.sensorStatuses['mock_gps_sensor'],
          SensorStatus.active,
        );
      });
    });

    group('Lifecycle', () {
      test('should dispose all sensors properly', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();
        await sensorManager.startSession(
          sessionId: 'test-session-123',
          activityType: ActivityType.running,
        );

        // Act
        await sensorManager.dispose();

        // Assert - sensor should no longer be initialized
        expect(sensorManager.isInitialized, false);
      });

      test('should handle multiple dispose calls gracefully', () async {
        // Arrange
        mockGpsSensor.setHardwareAvailable(true);
        mockGpsSensor.setPermissionGranted(true);
        await sensorManager.initialize();

        // Act & Assert - should not throw
        await sensorManager.dispose();
        await sensorManager.dispose();

        expect(sensorManager.isInitialized, false);
      });
    });
  });
}
