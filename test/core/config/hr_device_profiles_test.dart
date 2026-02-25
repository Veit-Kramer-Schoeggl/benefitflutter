import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/core/config/hr_device_profiles.dart';

void main() {
  group('HrDeviceProfiles', () {
    group('identifyDevice - Chest Straps', () {
      test('identifies Polar H10', () {
        expect(
          HrDeviceProfiles.identifyDevice('Polar H10'),
          equals(HrDeviceType.chestStrap),
        );
      });

      test('identifies Polar H9', () {
        expect(
          HrDeviceProfiles.identifyDevice('Polar H9'),
          equals(HrDeviceType.chestStrap),
        );
      });

      test('identifies Garmin HRM-Pro', () {
        expect(
          HrDeviceProfiles.identifyDevice('Garmin HRM-Pro'),
          equals(HrDeviceType.chestStrap),
        );
      });

      test('identifies Wahoo TICKR', () {
        expect(
          HrDeviceProfiles.identifyDevice('TICKR X'),
          equals(HrDeviceType.chestStrap),
        );
      });

      test('identifies Coospo H808', () {
        expect(
          HrDeviceProfiles.identifyDevice('H808S'),
          equals(HrDeviceType.chestStrap),
        );
      });

      test('is case insensitive', () {
        expect(
          HrDeviceProfiles.identifyDevice('POLAR H10'),
          equals(HrDeviceType.chestStrap),
        );
        expect(
          HrDeviceProfiles.identifyDevice('polar h10'),
          equals(HrDeviceType.chestStrap),
        );
      });
    });

    group('identifyDevice - Wrist Watches', () {
      test('identifies Apple Watch', () {
        expect(
          HrDeviceProfiles.identifyDevice('Apple Watch Series 8'),
          equals(HrDeviceType.wristWatch),
        );
      });

      test('identifies Samsung Galaxy Watch', () {
        expect(
          HrDeviceProfiles.identifyDevice('Galaxy Watch 5'),
          equals(HrDeviceType.wristWatch),
        );
      });

      test('identifies Garmin Venu', () {
        expect(
          HrDeviceProfiles.identifyDevice('Garmin Venu 2'),
          equals(HrDeviceType.wristWatch),
        );
      });

      test('identifies Garmin Forerunner', () {
        expect(
          HrDeviceProfiles.identifyDevice('Garmin Forerunner 955'),
          equals(HrDeviceType.wristWatch),
        );
      });

      test('identifies Fitbit Versa', () {
        expect(
          HrDeviceProfiles.identifyDevice('Fitbit Versa 4'),
          equals(HrDeviceType.wristWatch),
        );
      });

      test('identifies Amazfit', () {
        expect(
          HrDeviceProfiles.identifyDevice('Amazfit GTR 4'),
          equals(HrDeviceType.wristWatch),
        );
      });
    });

    group('identifyDevice - Fitness Bands', () {
      test('identifies Mi Band', () {
        expect(
          HrDeviceProfiles.identifyDevice('Mi Band 7'),
          equals(HrDeviceType.wristBand),
        );
      });

      test('identifies Xiaomi Smart Band', () {
        expect(
          HrDeviceProfiles.identifyDevice('Mi Smart Band 8'),
          equals(HrDeviceType.wristBand),
        );
      });

      test('identifies Fitbit Charge', () {
        expect(
          HrDeviceProfiles.identifyDevice('Fitbit Charge 5'),
          equals(HrDeviceType.wristBand),
        );
      });

      test('identifies Huawei Band', () {
        expect(
          HrDeviceProfiles.identifyDevice('Huawei Band 7'),
          equals(HrDeviceType.wristBand),
        );
      });

      test('identifies Honor Band', () {
        expect(
          HrDeviceProfiles.identifyDevice('Honor Band 6'),
          equals(HrDeviceType.wristBand),
        );
      });

      test('identifies Galaxy Fit', () {
        expect(
          HrDeviceProfiles.identifyDevice('Galaxy Fit 2'),
          equals(HrDeviceType.wristBand),
        );
      });
    });

    group('identifyDevice - Unknown', () {
      test('returns unknown for unrecognized devices', () {
        expect(
          HrDeviceProfiles.identifyDevice('Random HR Device'),
          equals(HrDeviceType.unknown),
        );
      });

      test('returns unknown for empty string', () {
        expect(
          HrDeviceProfiles.identifyDevice(''),
          equals(HrDeviceType.unknown),
        );
      });

      test('returns unknown for generic names', () {
        expect(
          HrDeviceProfiles.identifyDevice('Heart Rate Monitor'),
          equals(HrDeviceType.unknown),
        );
      });
    });

    group('getTrustMultiplier', () {
      test('chest strap has highest multiplier', () {
        expect(
          HrDeviceProfiles.getTrustMultiplier(HrDeviceType.chestStrap),
          equals(HrDeviceProfiles.chestStrapMultiplier),
        );
      });

      test('wrist watch returns correct multiplier', () {
        expect(
          HrDeviceProfiles.getTrustMultiplier(HrDeviceType.wristWatch),
          equals(HrDeviceProfiles.wristWatchMultiplier),
        );
      });

      test('wrist band returns correct multiplier', () {
        expect(
          HrDeviceProfiles.getTrustMultiplier(HrDeviceType.wristBand),
          equals(HrDeviceProfiles.wristBandMultiplier),
        );
      });

      test('unknown returns conservative multiplier', () {
        expect(
          HrDeviceProfiles.getTrustMultiplier(HrDeviceType.unknown),
          equals(HrDeviceProfiles.unknownDeviceMultiplier),
        );
      });
    });

    group('Multiplier Values', () {
      test('chest strap has higher multiplier than wrist devices', () {
        expect(
          HrDeviceProfiles.chestStrapMultiplier,
          greaterThan(HrDeviceProfiles.wristWatchMultiplier),
        );
        expect(
          HrDeviceProfiles.chestStrapMultiplier,
          greaterThan(HrDeviceProfiles.wristBandMultiplier),
        );
      });

      test('all multipliers are positive', () {
        expect(HrDeviceProfiles.chestStrapMultiplier, greaterThan(0));
        expect(HrDeviceProfiles.wristWatchMultiplier, greaterThan(0));
        expect(HrDeviceProfiles.wristBandMultiplier, greaterThan(0));
        expect(HrDeviceProfiles.unknownDeviceMultiplier, greaterThan(0));
      });

      test('all multipliers are at most 1.0', () {
        expect(HrDeviceProfiles.chestStrapMultiplier, lessThanOrEqualTo(1.0));
        expect(HrDeviceProfiles.wristWatchMultiplier, lessThanOrEqualTo(1.0));
        expect(HrDeviceProfiles.wristBandMultiplier, lessThanOrEqualTo(1.0));
        expect(HrDeviceProfiles.unknownDeviceMultiplier, lessThanOrEqualTo(1.0));
      });

      test('unknown has lowest multiplier', () {
        expect(
          HrDeviceProfiles.unknownDeviceMultiplier,
          lessThanOrEqualTo(HrDeviceProfiles.wristBandMultiplier),
        );
      });
    });

    group('getMultiplierForDevice', () {
      test('returns chest strap multiplier for Polar H10', () {
        expect(
          HrDeviceProfiles.getMultiplierForDevice('Polar H10'),
          equals(HrDeviceProfiles.chestStrapMultiplier),
        );
      });

      test('returns wrist watch multiplier for Apple Watch', () {
        expect(
          HrDeviceProfiles.getMultiplierForDevice('Apple Watch'),
          equals(HrDeviceProfiles.wristWatchMultiplier),
        );
      });

      test('returns unknown multiplier for unrecognized device', () {
        expect(
          HrDeviceProfiles.getMultiplierForDevice('Unknown Device XYZ'),
          equals(HrDeviceProfiles.unknownDeviceMultiplier),
        );
      });
    });

    group('isChestStrap', () {
      test('returns true for chest strap devices', () {
        expect(HrDeviceProfiles.isChestStrap('Polar H10'), isTrue);
        expect(HrDeviceProfiles.isChestStrap('HRM-Pro'), isTrue);
        expect(HrDeviceProfiles.isChestStrap('TICKR'), isTrue);
      });

      test('returns false for non-chest strap devices', () {
        expect(HrDeviceProfiles.isChestStrap('Apple Watch'), isFalse);
        expect(HrDeviceProfiles.isChestStrap('Mi Band 7'), isFalse);
        expect(HrDeviceProfiles.isChestStrap('Unknown'), isFalse);
      });
    });

    group('Pattern Lists', () {
      test('chest strap patterns are not empty', () {
        expect(HrDeviceProfiles.chestStrapPatterns, isNotEmpty);
      });

      test('wrist watch patterns are not empty', () {
        expect(HrDeviceProfiles.wristWatchPatterns, isNotEmpty);
      });

      test('wrist band patterns are not empty', () {
        expect(HrDeviceProfiles.wristBandPatterns, isNotEmpty);
      });

      test('all patterns are lowercase', () {
        for (final pattern in HrDeviceProfiles.chestStrapPatterns) {
          expect(pattern, equals(pattern.toLowerCase()));
        }
        for (final pattern in HrDeviceProfiles.wristWatchPatterns) {
          expect(pattern, equals(pattern.toLowerCase()));
        }
        for (final pattern in HrDeviceProfiles.wristBandPatterns) {
          expect(pattern, equals(pattern.toLowerCase()));
        }
      });
    });
  });
}
