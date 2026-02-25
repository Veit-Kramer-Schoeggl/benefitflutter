/// Utility class for converting between Dart types and SQLite-compatible types
///
/// SQLite stores DateTime as INTEGER (milliseconds since epoch)
/// API uses ISO 8601 strings
/// This converter handles both formats transparently
class SqliteTypeConverters {
  /// Convert DateTime to SQLite INTEGER (milliseconds since epoch)
  static int dateTimeToSqlite(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch;
  }

  /// Convert SQLite INTEGER to DateTime
  static DateTime dateTimeFromSqlite(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  /// Convert nullable DateTime to nullable SQLite INTEGER
  static int? nullableDateTimeToSqlite(DateTime? dateTime) {
    return dateTime?.millisecondsSinceEpoch;
  }

  /// Convert nullable SQLite INTEGER to nullable DateTime
  static DateTime? nullableDateTimeFromSqlite(int? milliseconds) {
    return milliseconds != null
        ? DateTime.fromMillisecondsSinceEpoch(milliseconds)
        : null;
  }

  /// Parse DateTime from JSON (handles both ISO 8601 string and integer)
  ///
  /// API responses use ISO 8601 strings: "2024-03-15T10:30:00.000Z"
  /// SQLite stores as integers: 1710497400000
  static DateTime dateTimeFromJson(dynamic json) {
    if (json is String) {
      return DateTime.parse(json);
    } else if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    } else {
      throw ArgumentError('Invalid DateTime format: $json');
    }
  }

  /// Parse nullable DateTime from JSON
  static DateTime? nullableDateTimeFromJson(dynamic json) {
    if (json == null) return null;
    return dateTimeFromJson(json);
  }

  /// Convert enum to SQLite TEXT (using toJson())
  static String enumToSqlite<T>(T enumValue) {
    // Assumes enum has toJson() method returning String
    return (enumValue as dynamic).toJson() as String;
  }

  /// Convert SQLite TEXT to enum (using fromJson())
  static T enumFromSqlite<T>(String value, T Function(String) fromJson) {
    return fromJson(value);
  }

  /// Convert nullable enum to nullable SQLite TEXT
  static String? nullableEnumToSqlite<T>(T? enumValue) {
    return enumValue != null ? enumToSqlite(enumValue) : null;
  }

  /// Convert nullable SQLite TEXT to nullable enum
  static T? nullableEnumFromSqlite<T>(
    String? value,
    T Function(String) fromJson,
  ) {
    return value != null ? fromJson(value) : null;
  }

  /// Convert boolean to SQLite INTEGER (0 or 1)
  static int boolToSqlite(bool value) {
    return value ? 1 : 0;
  }

  /// Convert SQLite INTEGER to boolean
  static bool boolFromSqlite(int value) {
    return value == 1;
  }

  /// Convert nullable boolean to nullable SQLite INTEGER
  static int? nullableBoolToSqlite(bool? value) {
    return value != null ? boolToSqlite(value) : null;
  }

  /// Convert nullable SQLite INTEGER to nullable boolean
  static bool? nullableBoolFromSqlite(int? value) {
    return value != null ? boolFromSqlite(value) : null;
  }
}
