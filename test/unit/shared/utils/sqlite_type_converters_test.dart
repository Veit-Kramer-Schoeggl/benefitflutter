import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/shared/utils/sqlite_type_converters.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';

void main() {
  group('SqliteTypeConverters', () {
    group('DateTime Conversions', () {
      test('dateTimeToSqlite converts DateTime to milliseconds', () {
        // Arrange
        final dateTime = DateTime(2024, 3, 15, 10, 30, 45);

        // Act
        final result = SqliteTypeConverters.dateTimeToSqlite(dateTime);

        // Assert
        expect(result, dateTime.millisecondsSinceEpoch);
        expect(result, isA<int>());
      });

      test('dateTimeFromSqlite converts milliseconds to DateTime', () {
        // Arrange
        final milliseconds = 1710497445000; // March 15, 2024, 10:30:45 UTC

        // Act
        final result = SqliteTypeConverters.dateTimeFromSqlite(milliseconds);

        // Assert
        expect(result, isA<DateTime>());
        expect(result.millisecondsSinceEpoch, milliseconds);
      });

      test('dateTimeToSqlite and dateTimeFromSqlite are reversible', () {
        // Arrange
        final original = DateTime(2024, 6, 20, 14, 25, 30);

        // Act
        final milliseconds = SqliteTypeConverters.dateTimeToSqlite(original);
        final result = SqliteTypeConverters.dateTimeFromSqlite(milliseconds);

        // Assert
        expect(result, original);
      });

      test('nullableDateTimeToSqlite handles non-null DateTime', () {
        // Arrange
        final dateTime = DateTime(2024, 1, 1);

        // Act
        final result = SqliteTypeConverters.nullableDateTimeToSqlite(dateTime);

        // Assert
        expect(result, dateTime.millisecondsSinceEpoch);
      });

      test('nullableDateTimeToSqlite handles null DateTime', () {
        // Act
        final result = SqliteTypeConverters.nullableDateTimeToSqlite(null);

        // Assert
        expect(result, isNull);
      });

      test('nullableDateTimeFromSqlite handles non-null milliseconds', () {
        // Arrange
        final milliseconds = 1704067200000; // Jan 1, 2024

        // Act
        final result =
            SqliteTypeConverters.nullableDateTimeFromSqlite(milliseconds);

        // Assert
        expect(result, isNotNull);
        expect(result!.millisecondsSinceEpoch, milliseconds);
      });

      test('nullableDateTimeFromSqlite handles null milliseconds', () {
        // Act
        final result = SqliteTypeConverters.nullableDateTimeFromSqlite(null);

        // Assert
        expect(result, isNull);
      });

      test('dateTimeFromJson parses ISO 8601 string', () {
        // Arrange
        const isoString = '2024-03-15T10:30:45.000Z';

        // Act
        final result = SqliteTypeConverters.dateTimeFromJson(isoString);

        // Assert
        expect(result, isA<DateTime>());
        expect(result.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
      });

      test('dateTimeFromJson parses integer milliseconds', () {
        // Arrange
        const milliseconds = 1710497445000;

        // Act
        final result = SqliteTypeConverters.dateTimeFromJson(milliseconds);

        // Assert
        expect(result, isA<DateTime>());
        expect(result.millisecondsSinceEpoch, milliseconds);
      });

      test('dateTimeFromJson throws on invalid input type', () {
        // Act & Assert
        expect(
          () => SqliteTypeConverters.dateTimeFromJson(123.45),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('dateTimeFromJson throws on invalid string format', () {
        // Act & Assert
        expect(
          () => SqliteTypeConverters.dateTimeFromJson('invalid-date'),
          throwsA(isA<FormatException>()),
        );
      });

      test('nullableDateTimeFromJson handles non-null ISO string', () {
        // Arrange
        const isoString = '2024-06-01T12:00:00.000Z';

        // Act
        final result = SqliteTypeConverters.nullableDateTimeFromJson(isoString);

        // Assert
        expect(result, isNotNull);
      });

      test('nullableDateTimeFromJson handles null', () {
        // Act
        final result = SqliteTypeConverters.nullableDateTimeFromJson(null);

        // Assert
        expect(result, isNull);
      });
    });

    group('Enum Conversions', () {
      test('enumToSqlite converts enum to string', () {
        // Arrange
        const activityType = ActivityType.walking;

        // Act
        final result = SqliteTypeConverters.enumToSqlite(activityType);

        // Assert
        expect(result, 'walking');
        expect(result, isA<String>());
      });

      test('enumFromSqlite converts string to enum', () {
        // Arrange
        const value = 'running';

        // Act
        final result = SqliteTypeConverters.enumFromSqlite(
          value,
          ActivityType.fromJson,
        );

        // Assert
        expect(result, ActivityType.running);
      });

      test('enumToSqlite and enumFromSqlite are reversible', () {
        // Arrange
        const original = ActivityType.cycling;

        // Act
        final string = SqliteTypeConverters.enumToSqlite(original);
        final result = SqliteTypeConverters.enumFromSqlite(
          string,
          ActivityType.fromJson,
        );

        // Assert
        expect(result, original);
      });

      test('nullableEnumToSqlite handles non-null enum', () {
        // Arrange
        const activityType = ActivityType.other;

        // Act
        final result = SqliteTypeConverters.nullableEnumToSqlite(activityType);

        // Assert
        expect(result, 'other');
      });

      test('nullableEnumToSqlite handles null enum', () {
        // Act
        final result =
            SqliteTypeConverters.nullableEnumToSqlite<ActivityType>(null);

        // Assert
        expect(result, isNull);
      });

      test('nullableEnumFromSqlite handles non-null string', () {
        // Arrange
        const value = 'walking';

        // Act
        final result = SqliteTypeConverters.nullableEnumFromSqlite(
          value,
          ActivityType.fromJson,
        );

        // Assert
        expect(result, ActivityType.walking);
      });

      test('nullableEnumFromSqlite handles null string', () {
        // Act
        final result = SqliteTypeConverters.nullableEnumFromSqlite<ActivityType>(
          null,
          ActivityType.fromJson,
        );

        // Assert
        expect(result, isNull);
      });
    });

    group('Boolean Conversions', () {
      test('boolToSqlite converts true to 1', () {
        // Act
        final result = SqliteTypeConverters.boolToSqlite(true);

        // Assert
        expect(result, 1);
      });

      test('boolToSqlite converts false to 0', () {
        // Act
        final result = SqliteTypeConverters.boolToSqlite(false);

        // Assert
        expect(result, 0);
      });

      test('boolFromSqlite converts 1 to true', () {
        // Act
        final result = SqliteTypeConverters.boolFromSqlite(1);

        // Assert
        expect(result, isTrue);
      });

      test('boolFromSqlite converts 0 to false', () {
        // Act
        final result = SqliteTypeConverters.boolFromSqlite(0);

        // Assert
        expect(result, isFalse);
      });

      test('boolToSqlite and boolFromSqlite are reversible for true', () {
        // Arrange
        const original = true;

        // Act
        final integer = SqliteTypeConverters.boolToSqlite(original);
        final result = SqliteTypeConverters.boolFromSqlite(integer);

        // Assert
        expect(result, original);
      });

      test('boolToSqlite and boolFromSqlite are reversible for false', () {
        // Arrange
        const original = false;

        // Act
        final integer = SqliteTypeConverters.boolToSqlite(original);
        final result = SqliteTypeConverters.boolFromSqlite(integer);

        // Assert
        expect(result, original);
      });

      test('nullableBoolToSqlite handles non-null true', () {
        // Act
        final result = SqliteTypeConverters.nullableBoolToSqlite(true);

        // Assert
        expect(result, 1);
      });

      test('nullableBoolToSqlite handles non-null false', () {
        // Act
        final result = SqliteTypeConverters.nullableBoolToSqlite(false);

        // Assert
        expect(result, 0);
      });

      test('nullableBoolToSqlite handles null', () {
        // Act
        final result = SqliteTypeConverters.nullableBoolToSqlite(null);

        // Assert
        expect(result, isNull);
      });

      test('nullableBoolFromSqlite handles non-null 1', () {
        // Act
        final result = SqliteTypeConverters.nullableBoolFromSqlite(1);

        // Assert
        expect(result, isTrue);
      });

      test('nullableBoolFromSqlite handles non-null 0', () {
        // Act
        final result = SqliteTypeConverters.nullableBoolFromSqlite(0);

        // Assert
        expect(result, isFalse);
      });

      test('nullableBoolFromSqlite handles null', () {
        // Act
        final result = SqliteTypeConverters.nullableBoolFromSqlite(null);

        // Assert
        expect(result, isNull);
      });
    });

    group('Edge Cases', () {
      test('handles epoch time (Jan 1, 1970)', () {
        // Arrange
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);

        // Act
        final milliseconds = SqliteTypeConverters.dateTimeToSqlite(epoch);
        final result = SqliteTypeConverters.dateTimeFromSqlite(milliseconds);

        // Assert
        expect(milliseconds, 0);
        expect(result, epoch);
      });

      test('handles far future dates', () {
        // Arrange
        final future = DateTime(2100, 12, 31, 23, 59, 59);

        // Act
        final milliseconds = SqliteTypeConverters.dateTimeToSqlite(future);
        final result = SqliteTypeConverters.dateTimeFromSqlite(milliseconds);

        // Assert
        expect(result, future);
      });

      test('handles microseconds precision loss', () {
        // Arrange
        final original = DateTime(2024, 3, 15, 10, 30, 45, 123, 456);

        // Act
        final milliseconds = SqliteTypeConverters.dateTimeToSqlite(original);
        final result = SqliteTypeConverters.dateTimeFromSqlite(milliseconds);

        // Assert - Microseconds are lost in SQLite conversion
        expect(result.year, original.year);
        expect(result.month, original.month);
        expect(result.day, original.day);
        expect(result.hour, original.hour);
        expect(result.minute, original.minute);
        expect(result.second, original.second);
        expect(result.millisecond, original.millisecond);
        // Microseconds are NOT preserved (SQLite limitation)
      });
    });
  });
}
