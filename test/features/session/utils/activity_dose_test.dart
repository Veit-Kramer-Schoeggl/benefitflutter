import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/session/domain/activity_entry.dart';
import 'package:benefitflutter/features/session/utils/activity_dose.dart';

/// Entry of [minutes] active time; with the default 60 minutes the distance in
/// km equals the average speed in km/h.
ActivityEntry entry(String type, {double? km, int? minutes = 60}) {
  return ActivityEntry(
    activityType: type,
    distanceKm: km,
    duration: minutes == null ? null : Duration(minutes: minutes),
    startTime: DateTime(2026, 10, 5, 8),
  );
}

void main() {
  group('ActivityDose', () {
    group('metForEntry speed rule (recorded sessions, manual entries)', () {
      test('7.0 km/h up to 25 km/h counts as running (9.0)', () {
        expect(ActivityDose.metForEntry(entry('running', km: 7.0)), 9.0);
        expect(ActivityDose.metForEntry(entry('running', km: 12.0)), 9.0);
        expect(ActivityDose.metForEntry(entry('running', km: 25.0)), 9.0);
      });

      test('2.0 to below 7.0 km/h counts as walking (4.0)', () {
        expect(ActivityDose.metForEntry(entry('running', km: 2.0)), 4.0);
        expect(ActivityDose.metForEntry(entry('running', km: 6.99)), 4.0);
      });

      test('below 2.0 km/h is stationary / GPS drift (0)', () {
        expect(ActivityDose.metForEntry(entry('running', km: 1.99)), 0.0);
        expect(ActivityDose.metForEntry(entry('running', km: 0.3)), 0.0);
      });

      test('above 25 km/h is a vehicle (0)', () {
        expect(ActivityDose.metForEntry(entry('running', km: 25.1)), 0.0);
        expect(ActivityDose.metForEntry(entry('running', km: 80.0)), 0.0);
      });

      test('without distance counts as walking (4.0)', () {
        expect(ActivityDose.metForEntry(entry('running')), 4.0);
        expect(ActivityDose.metForEntry(entry('running', km: 0.0)), 4.0);
        expect(ActivityDose.metForEntry(entry('Manual Entry')), 4.0);
      });

      test(
        'applies to trailRunning, other, Manual Entry and unknown types',
        () {
          for (final type in [
            'trailRunning',
            'other',
            'Manual Entry',
            'skateboarding',
          ]) {
            expect(ActivityDose.metForEntry(entry(type, km: 10.0)), 9.0);
            expect(ActivityDose.metForEntry(entry(type, km: 4.0)), 4.0);
            expect(ActivityDose.metForEntry(entry(type, km: 1.0)), 0.0);
          }
        },
      );
    });

    group('metForEntry explicit types', () {
      test('walking and hiking count 4.0 at any speed', () {
        expect(ActivityDose.metForEntry(entry('walking', km: 10.0)), 4.0);
        expect(ActivityDose.metForEntry(entry('walking')), 4.0);
        expect(ActivityDose.metForEntry(entry('hiking', km: 1.0)), 4.0);
      });

      test('cycling counts 6.8, but 0 above 40 km/h', () {
        expect(ActivityDose.metForEntry(entry('cycling', km: 20.0)), 6.8);
        expect(ActivityDose.metForEntry(entry('cycling', km: 40.0)), 6.8);
        expect(ActivityDose.metForEntry(entry('cycling')), 6.8);
        expect(ActivityDose.metForEntry(entry('cycling', km: 40.5)), 0.0);
      });

      test('other sports count as moderate (4.5)', () {
        for (final type in [
          'swimming',
          'strengthTraining',
          'yoga',
          'dancing',
          'martialArts',
          'teamSports',
        ]) {
          expect(ActivityDose.metForEntry(entry(type)), 4.5, reason: type);
        }
      });
    });

    group('metHoursForEntry', () {
      test('is MET x active hours', () {
        // 5 km in 30 min = 10 km/h -> running 9.0 x 0.5 h
        expect(
          ActivityDose.metHoursForEntry(entry('running', km: 5, minutes: 30)),
          4.5,
        );
        // 6 km in 90 min = 4 km/h -> walking 4.0 x 1.5 h
        expect(
          ActivityDose.metHoursForEntry(entry('running', km: 6, minutes: 90)),
          6.0,
        );
      });

      test('is 0 without an active duration', () {
        expect(
          ActivityDose.metHoursForEntry(entry('running', km: 5, minutes: null)),
          0.0,
        );
        expect(
          ActivityDose.metHoursForEntry(entry('walking', minutes: 0)),
          0.0,
        );
      });
    });

    group('estimateGainMonths', () {
      test('returns no number below 2 MET-hours', () {
        for (final sex in ModelSex.values) {
          expect(ActivityDose.estimateGainMonths(0.0, sex), isNull);
          expect(ActivityDose.estimateGainMonths(1.99, sex), isNull);
        }
      });

      test('returns the women and men rows at the support points', () {
        expect(ActivityDose.estimateGainMonths(2.0, ModelSex.male), (
          months: 8,
          low: 3,
          high: 12,
          capped: false,
        ));
        expect(ActivityDose.estimateGainMonths(2.0, ModelSex.female), (
          months: 5,
          low: 2,
          high: 10,
          capped: false,
        ));
        expect(ActivityDose.estimateGainMonths(11.25, ModelSex.male), (
          months: 18,
          low: 12,
          high: 32,
          capped: false,
        ));
        expect(ActivityDose.estimateGainMonths(11.25, ModelSex.female), (
          months: 15,
          low: 9,
          high: 29,
          capped: false,
        ));
        expect(ActivityDose.estimateGainMonths(18.75, ModelSex.male), (
          months: 25,
          low: 16,
          high: 46,
          capped: false,
        ));
        expect(ActivityDose.estimateGainMonths(22.5, ModelSex.female), (
          months: 25,
          low: 14,
          high: 56,
          capped: false,
        ));
      });

      test('interpolates linearly between support points', () {
        // 10.0 lies 4/9 of the way from 9 to 11.25
        // men 16.9 (11.4-28.7), women 13.3 (8.4-26.2)
        expect(ActivityDose.estimateGainMonths(10.0, ModelSex.male), (
          months: 17,
          low: 11,
          high: 29,
          capped: false,
        ));
        expect(ActivityDose.estimateGainMonths(10.0, ModelSex.female), (
          months: 13,
          low: 8,
          high: 26,
          capped: false,
        ));
      });

      test('rounds to whole months, halves away from zero', () {
        // 3.0 is halfway between 2 and 4: men 9.5 (4.5-13.5)
        expect(ActivityDose.estimateGainMonths(3.0, ModelSex.male), (
          months: 10,
          low: 5,
          high: 14,
          capped: false,
        ));
        // women 6.0 (3.5-11.0)
        expect(ActivityDose.estimateGainMonths(3.0, ModelSex.female), (
          months: 6,
          low: 4,
          high: 11,
          capped: false,
        ));
      });

      test('caps the dose at twice the recommendation (22.5)', () {
        for (final dose in [22.6, 25.0, 30.0, 100.0]) {
          // The 25 and 30 support points are never read
          expect(ActivityDose.estimateGainMonths(dose, ModelSex.male), (
            months: 28,
            low: 18,
            high: 54,
            capped: true,
          ));
          expect(ActivityDose.estimateGainMonths(dose, ModelSex.female), (
            months: 25,
            low: 14,
            high: 56,
            capped: true,
          ));
        }
      });
    });

    test('modelSexForGender maps only male and female to a row', () {
      expect(ActivityDose.modelSexForGender('male'), ModelSex.male);
      expect(ActivityDose.modelSexForGender('female'), ModelSex.female);
      expect(ActivityDose.modelSexForGender('other'), isNull);
      expect(ActivityDose.modelSexForGender(null), isNull);
    });
  });
}
