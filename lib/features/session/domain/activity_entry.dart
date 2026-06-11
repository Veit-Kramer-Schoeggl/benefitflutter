import 'package:uuid/uuid.dart';

// Static instance for efficient UUID generation.
// This fixes the 'Invalid constant value' error.
final _uuid = Uuid();

// Data class (Model) for an activity entry.
// Represents a recorded or manually created activity.
class ActivityEntry {
  final String sessionId;
  final double? distanceKm;
  final Duration? duration;
  final DateTime startTime;
  final String activityType;
  final bool isManual;
  final int? calories;

  ActivityEntry({
    String? sessionId,
    this.distanceKm,
    this.duration,
    required this.startTime,
    required this.activityType,
    this.isManual = false,
    this.calories,
  }) : sessionId = sessionId ?? _uuid.v4();

  // ------------------------- Getters for UI -------------------------
  String get formattedDistance {
    if (distanceKm == null) return '--';
    return '${distanceKm!.toStringAsFixed(2)} km';
  }

  // Always displays duration in HH:MM:SS format.
  String get formattedDuration {
    if (duration == null) return '--';
    final totalSeconds = duration!.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    final date = startTime;
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String get formattedCalories {
    if (calories == null) return '--';
    return '${calories!} kcal';
  }

  // ------------------------- Helper Methods for Persistence -------------------------
  // toPrefString saves all 7 fields (including isManual)
  String toPrefString() {
    return [
      sessionId,
      distanceKm?.toString() ?? '0.0',
      duration?.inSeconds.toString() ?? '0',
      startTime.toIso8601String(),
      activityType,
      calories?.toString() ?? '0',
      isManual.toString(),
    ].join('::');
  }

  static ActivityEntry fromPrefString(String prefString) {
    final fields = prefString.split('::');

    // Check for correct length of 7 fields
    if (fields.length != 7) {
      throw FormatException(
        'Invalid format for ActivityEntry (expected: 7 fields, found: ${fields.length})',
      );
    }

    final parsedDistance = double.parse(fields[1]);
    final parsedDurationSeconds = int.parse(fields[2]);
    final parsedCalories = int.parse(fields[5]);

    // Load the boolean status
    final parsedIsManual = fields[6].toLowerCase() == 'true';

    return ActivityEntry(
      sessionId: fields[0],
      distanceKm: parsedDistance > 0.0 ? parsedDistance : null,
      duration: parsedDurationSeconds > 0
          ? Duration(seconds: parsedDurationSeconds)
          : null,
      startTime: DateTime.parse(fields[3]),
      activityType: fields[4],
      isManual: parsedIsManual,
      calories: parsedCalories > 0 ? parsedCalories : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityEntry &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId;

  @override
  int get hashCode => sessionId.hashCode;
}
