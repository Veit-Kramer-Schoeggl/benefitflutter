import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

void main() {
  group('Session Formatting', () {
    group('formattedDuration', () {
      test('returns "--" when durationSeconds is null', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.active,
          startTime: DateTime.now(),
          durationSeconds: null,
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '--');
      });

      test('formats seconds only (under 1 minute)', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          durationSeconds: 45,
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '0m');
      });

      test('formats minutes only (no hours)', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.running,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          durationSeconds: 1800, // 30 minutes
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '30m');
      });

      test('formats hours and minutes', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.cycling,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          durationSeconds: 5430, // 1 hour 30 minutes 30 seconds
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '1h 30m');
      });

      test('formats exactly 1 hour', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          durationSeconds: 3600, // 1 hour exactly
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '1h 0m');
      });

      test('formats multiple hours', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.continuousDaily,
          activityType: ActivityType.other,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          durationSeconds: 9000, // 2 hours 30 minutes
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '2h 30m');
      });

      test('formats very long duration', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.continuousDaily,
          activityType: ActivityType.walking,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          durationSeconds: 86400, // 24 hours
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '24h 0m');
      });

      test('formats zero duration', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.running,
          status: SessionStatus.active,
          startTime: DateTime.now(),
          durationSeconds: 0,
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '0m');
      });

      test('ignores seconds in formatting (rounds down)', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          durationSeconds: 3659, // 1h 0m 59s
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '1h 0m'); // Seconds are dropped
      });
    });

    group('formattedDistance', () {
      test('returns "--" when distanceMeters is null', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.active,
          startTime: DateTime.now(),
          distanceMeters: null,
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '--');
      });

      test('formats distance in kilometers with 2 decimals', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.running,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          distanceMeters: 5234.56, // 5.23456 km
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '5.23 km');
      });

      test('formats exactly 1 km', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.cycling,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          distanceMeters: 1000,
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '1.00 km');
      });

      test('formats long distance', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.cycling,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          distanceMeters: 42195, // Marathon distance
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '42.20 km'); // Rounded to 2 decimals
      });

      test('formats very short distance (rounds to 0.00 km)', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          distanceMeters: 50, // 0.05 km
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '0.05 km');
      });

      test('formats zero distance', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.active,
          startTime: DateTime.now(),
          distanceMeters: 0,
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '0.00 km');
      });

      test('rounds to 2 decimal places correctly', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.running,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          distanceMeters: 1234.5678,
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '1.23 km'); // Rounds down
      });

      test('handles very large distances', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.continuousDaily,
          activityType: ActivityType.other,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          distanceMeters: 100000, // 100 km
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '100.00 km');
      });
    });

    group('Edge Cases', () {
      test('handles very long session (multi-day duration)', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.continuousDaily,
          activityType: ActivityType.walking,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          durationSeconds: 172800, // 48 hours (2 days)
        );

        // Act
        final result = session.formattedDuration;

        // Assert
        expect(result, '48h 0m');
      });

      test('handles fractional kilometers correctly', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.running,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          distanceMeters: 1999.99, // Just under 2km
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '2.00 km'); // Rounds to 2.00
      });

      test('handles very small non-zero distance', () {
        // Arrange
        final session = Session(
          id: 'test-1',
          userId: 'user-1',
          trackingMode: TrackingMode.manual,
          activityType: ActivityType.walking,
          status: SessionStatus.completed,
          startTime: DateTime.now(),
          distanceMeters: 1.5, // 1.5 meters
        );

        // Act
        final result = session.formattedDistance;

        // Assert
        expect(result, '0.00 km'); // Rounds to 0.00
      });
    });
  });
}
