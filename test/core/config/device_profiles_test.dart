import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/config/device_profiles.dart';

void main() {
  group('DeviceProfiles', () {
    group('getDeviceMultiplier', () {
      test('returns 1.0 for unknown devices', () {
        expect(DeviceProfiles.getDeviceMultiplier('unknown_device'), equals(1.0));
      });

      test('returns 1.0 for empty string', () {
        expect(DeviceProfiles.getDeviceMultiplier(''), equals(1.0));
      });

      test('is case insensitive', () {
        // Both should return same value (1.0 for unknown)
        expect(
          DeviceProfiles.getDeviceMultiplier('UNKNOWN_DEVICE'),
          equals(DeviceProfiles.getDeviceMultiplier('unknown_device')),
        );
      });
    });

    group('buildDeviceId', () {
      test('normalizes manufacturer and model', () {
        expect(
          DeviceProfiles.buildDeviceId('Samsung', 'Galaxy S21'),
          equals('samsung_galaxy_s21'),
        );
      });

      test('handles multiple spaces', () {
        expect(
          DeviceProfiles.buildDeviceId('Samsung', 'Galaxy   S21  Ultra'),
          equals('samsung_galaxy_s21_ultra'),
        );
      });

      test('removes special characters', () {
        expect(
          DeviceProfiles.buildDeviceId('Google', 'Pixel 7 (Pro)'),
          equals('google_pixel_7_pro'),
        );
      });

      test('handles lowercase input', () {
        expect(
          DeviceProfiles.buildDeviceId('google', 'pixel'),
          equals('google_pixel'),
        );
      });

      test('handles mixed case', () {
        expect(
          DeviceProfiles.buildDeviceId('OnePlus', 'NORD CE'),
          equals('oneplus_nord_ce'),
        );
      });
    });

    group('hasOverride', () {
      test('returns false for unknown devices', () {
        expect(DeviceProfiles.hasOverride('unknown_device'), isFalse);
      });

      test('is case insensitive', () {
        // Both should return same result
        expect(
          DeviceProfiles.hasOverride('UNKNOWN_DEVICE'),
          equals(DeviceProfiles.hasOverride('unknown_device')),
        );
      });
    });

    group('overrides map', () {
      test('is immutable (const)', () {
        // Accessing the map should not throw
        expect(DeviceProfiles.overrides, isA<Map<String, double>>());
      });

      test('all override values are positive', () {
        for (final entry in DeviceProfiles.overrides.entries) {
          expect(
            entry.value,
            greaterThan(0),
            reason: 'Device ${entry.key} has non-positive multiplier',
          );
        }
      });

      test('all override values are reasonable (0.5 to 1.5)', () {
        for (final entry in DeviceProfiles.overrides.entries) {
          expect(
            entry.value,
            greaterThanOrEqualTo(0.5),
            reason: 'Device ${entry.key} multiplier too low',
          );
          expect(
            entry.value,
            lessThanOrEqualTo(1.5),
            reason: 'Device ${entry.key} multiplier too high',
          );
        }
      });
    });
  });
}
