import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/features/shared/sensors/gps_sensor.dart';

/// Tests the pure platform/mode branching of [GpsSensor.buildLocationSettings]
/// without invoking Geolocator (WP2 — foreground-service settings).
void main() {
  group('GpsSensor.buildLocationSettings', () {
    test('Android + manual → AndroidSettings with foreground service, 5 m', () {
      final settings = GpsSensor.buildLocationSettings(
        platform: TargetPlatform.android,
        mode: TrackingMode.manual,
      );

      expect(settings, isA<AndroidSettings>());
      final android = settings as AndroidSettings;
      expect(android.foregroundNotificationConfig, isNotNull);
      expect(android.foregroundNotificationConfig!.enableWakeLock, isTrue);
      expect(android.foregroundNotificationConfig!.setOngoing, isTrue);
      expect(android.accuracy, LocationAccuracy.high);
      expect(android.distanceFilter, 5);
    });

    test('Android + continuousDaily → coarser 50 m distance filter', () {
      final settings = GpsSensor.buildLocationSettings(
        platform: TargetPlatform.android,
        mode: TrackingMode.continuousDaily,
      );

      expect(settings, isA<AndroidSettings>());
      expect(settings.distanceFilter, 50);
    });

    test('iOS + manual → AppleSettings with background updates enabled', () {
      final settings = GpsSensor.buildLocationSettings(
        platform: TargetPlatform.iOS,
        mode: TrackingMode.manual,
      );

      expect(settings, isA<AppleSettings>());
      final apple = settings as AppleSettings;
      expect(apple.allowBackgroundLocationUpdates, isTrue);
      expect(apple.pauseLocationUpdatesAutomatically, isFalse);
      expect(apple.showBackgroundLocationIndicator, isTrue);
      expect(apple.activityType, ActivityType.fitness);
      expect(apple.accuracy, LocationAccuracy.high);
      expect(apple.distanceFilter, 5);
    });

    test('other platforms → plain LocationSettings (no FGS/background)', () {
      final settings = GpsSensor.buildLocationSettings(
        platform: TargetPlatform.linux,
        mode: TrackingMode.manual,
      );

      expect(settings, isNot(isA<AndroidSettings>()));
      expect(settings, isNot(isA<AppleSettings>()));
      expect(settings.accuracy, LocationAccuracy.high);
      expect(settings.distanceFilter, 5);
    });
  });
}
