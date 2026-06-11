import 'package:benefitflutter/core/logging/app_logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:benefitflutter/features/session/domain/activity_entry.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

class ProgressProvider extends ChangeNotifier {
  // ===================== FIELDS =====================

  final SessionRepository _sessionRepository;

  // Dynamic user ID (set via ProxyProvider from UserProvider)
  String? _userId;

  // List of manually entered activities (for persistence)
  final List<ActivityEntry> _manualEntries = [];

  // Combined state: Manual entries + DB entries
  List<ActivityEntry> _combinedActivities = [];

  static const _prefKeyManualEntries = 'manual_entries';

  // UI State
  bool _isLoading = false;
  String? _error;

  // ===================== CONSTRUCTOR =====================

  ProgressProvider(this._sessionRepository) {
    // ⚠️ FIX 1: loadManualEntriesFromPrefs() removed from here.
    // It's now called asynchronously within loadActivities() and awaited.
    loadActivities();

    // 🗑️ OPTIONAL DEBUGGING (For one-time deletion of old data)
    // If you suspect old, faulty data is in storage,
    // TEMPORARILY ADD THIS BLOCK HERE, restart the app,
    // and then REMOVE it again.
    /*
    SharedPreferences.getInstance().then((prefs) {
        prefs.remove(_prefKeyManualEntries);
        AppLogger.d('--- Old manual entries deleted! Restart to fix the problem. ---');
    });
    */
  }

  // ===================== USER ID MANAGEMENT =====================

  /// Updates the user ID and reloads activities when user changes.
  /// Called by ProxyProvider when UserProvider's userId changes.
  void updateUserId(String? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      if (newUserId != null) {
        // User logged in - reload activities for this user
        loadActivities();
      } else {
        // User logged out - clear activities
        _combinedActivities.clear();
        _manualEntries.clear();
        notifyListeners();
      }
    }
  }

  // ===================== GETTERS =====================

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ActivityEntry> get activities => _combinedActivities;
  bool get isEmpty => !_isLoading && _combinedActivities.isEmpty;

  // ===================== C.R.U.D. METHODS FOR MANUAL ENTRIES =====================

  /// Adds a new manual activity, saves it, and updates the list.
  void addActivity(ActivityEntry newActivity) {
    _manualEntries.add(newActivity);

    saveManualEntriesToPrefs();

    _recombineAndSortActivities();

    notifyListeners();
  }

  /// Updates an existing manual activity entry.
  void updateActivity(ActivityEntry updatedEntry) {
    final index = _manualEntries.indexWhere(
      (e) => e.sessionId == updatedEntry.sessionId,
    );

    if (index != -1) {
      _manualEntries[index] = updatedEntry;

      saveManualEntriesToPrefs();

      _recombineAndSortActivities();

      notifyListeners();
    }
  }

  /// Removes an activity (manual or automatic)
  Future<void> removeActivity(ActivityEntry entry) async {
    if (entry.isManual) {
      _manualEntries.removeWhere((e) => e.sessionId == entry.sessionId);
      saveManualEntriesToPrefs();

      _recombineAndSortActivities();
      notifyListeners();
    } else {
      // Assumption: deleteSession method needs the session ID
      await _sessionRepository.deleteSession(entry.sessionId);

      // Reload after deletion
      loadActivities();
    }
  }

  // ===================== CORE LOGIC METHODS =====================

  /// Loads all activities (DB and manual)
  Future<void> loadActivities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ⚠️ FIX 2: First wait for manual entries
      // to ensure _manualEntries is not empty.
      await loadManualEntriesFromPrefs();

      if (_userId == null) {
        // No user logged in - clear activities and return
        _combinedActivities.clear();
        return;
      }
      final dbSessions = await _sessionRepository.getAllSessions(
        userId: _userId!,
      );
      _convertDbAndCombine(dbSessions);
      _error = null;
    } catch (e) {
      _error = 'Error loading sessions: $e';

      // If only DB loading fails, show manual entries.
      _combinedActivities = List.from(_manualEntries);
      _combinedActivities.sort((a, b) => b.startTime.compareTo(a.startTime));
      AppLogger.e('ProgressProvider Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Converts DB sessions, combines with manual entries, and sorts
  void _convertDbAndCombine(List<Session> dbSessions) {
    AppLogger.d(
      'ProgressProvider: Loaded ${dbSessions.length} total sessions from DB',
    );

    // 1. Filter: Only show COMPLETED sessions in Progress screen
    final completedSessions = dbSessions
        .where((session) => session.status == SessionStatus.completed)
        .toList();

    AppLogger.d(
      'ProgressProvider: ${completedSessions.length} completed sessions',
    );

    // 2. Convert database entities (Session) to ActivityEntry models
    List<ActivityEntry> dbEntries = completedSessions.map((session) {
      final duration = session.durationSeconds != null
          ? Duration(seconds: session.durationSeconds!)
          : null;

      final distanceKm = session.distanceMeters != null
          ? session.distanceMeters! / 1000.0
          : null;

      return ActivityEntry(
        distanceKm: distanceKm,
        duration: duration,
        startTime: session.startTime,
        // Assumption: activityType is available in Session class and has a 'name' getter
        activityType: session.activityType.name,
        isManual: false,
        sessionId: session.id,
      );
    }).toList();

    // 3. Combine manual and DB entries
    _combinedActivities = [..._manualEntries, ...dbEntries];

    // Sort by start time (newest first: b before a)
    _combinedActivities.sort((a, b) => b.startTime.compareTo(a.startTime));

    AppLogger.d(
      'ProgressProvider: Total activities to display: ${_combinedActivities.length} (${_manualEntries.length} manual + ${dbEntries.length} DB)',
    );
  }

  /// Updates and sorts the combined list (used after manual CRUD operations)
  void _recombineAndSortActivities() {
    // Filter current DB entries (non-manual ones)
    // We take entries that are NOT manual from the CURRENT _combinedActivities list
    final List<ActivityEntry> dbEntries = _combinedActivities
        .where((e) => !e.isManual)
        .toList();

    // Create new combined list
    _combinedActivities = [..._manualEntries, ...dbEntries];

    // Sort by start time (newest first)
    _combinedActivities.sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  // ===================== PERSISTENCE (SharedPreferences) =====================

  Future<void> saveManualEntriesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _manualEntries.map((e) => e.toPrefString()).toList();
    await prefs.setString(
      ProgressProvider._prefKeyManualEntries,
      jsonList.join(';;'),
    );
  }

  // ⚠️ FIX 3: Changed method to Future<void>.
  Future<void> loadManualEntriesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // await added
    final raw = prefs.getString(ProgressProvider._prefKeyManualEntries) ?? '';

    if (raw.isEmpty) return;

    final items = raw.split(';;');
    _manualEntries.clear();
    for (var item in items) {
      try {
        _manualEntries.add(ActivityEntry.fromPrefString(item));
      } catch (e) {
        // Important: If an error occurs here, it's due to incompatible old data.
        AppLogger.d(
          'Error loading ActivityEntry: $e. Probably incompatible old format.',
        );
      }
    }
  }

  // ===================== STATISTICS METHODS =====================

  /// Calculates summed distance (km) per weekday (Monday=1 to Sunday=7)
  Map<int, double> getDistancePerWeekday() {
    final Map<int, double> distanceMap = {};

    for (final entry in _combinedActivities) {
      if (entry.distanceKm != null && entry.distanceKm! > 0) {
        final int weekday = entry.startTime.weekday;
        final double distance = entry.distanceKm!;

        distanceMap.update(
          weekday,
          (existingDistance) => existingDistance + distance,
          ifAbsent: () => distance,
        );
      }
    }
    return distanceMap;
  }

  /// Calculates summed duration (minutes) per weekday (Monday=1 to Sunday=7)
  Map<int, double> getDurationPerWeekdayMinutes() {
    final Map<int, double> durationMap = {};

    for (final entry in _combinedActivities) {
      if (entry.duration != null && entry.duration!.inSeconds > 0) {
        final int weekday = entry.startTime.weekday;
        final double minutes = entry.duration!.inSeconds / 60.0;

        durationMap.update(
          weekday,
          (existingMinutes) => existingMinutes + minutes,
          ifAbsent: () => minutes,
        );
      }
    }

    return durationMap;
  }

  Map<String, double> getDurationPerMonth() {
    final Map<String, double> durationMap = {};

    for (final entry in _combinedActivities) {
      if (entry.duration != null && entry.duration!.inSeconds > 0) {
        // Format year and month as 'YYYY-MM' (e.g. '2025-12')
        final String yearMonthKey =
            '${entry.startTime.year}-${entry.startTime.month.toString().padLeft(2, '0')}';

        // Convert duration from seconds to minutes (as Double for the chart)
        final double durationMinutes = entry.duration!.inSeconds / 60.0;

        // Sum the duration for this month
        durationMap.update(
          yearMonthKey,
          (existingDuration) => existingDuration + durationMinutes,
          ifAbsent: () => durationMinutes,
        );
      }
    }
    return durationMap;
  }

  Map<int, double> getDistancePerYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final Map<int, double> yearlyDistances = {};

    // Calculate distance for the last 6 years (including current year)
    for (int i = 0; i < 6; i++) {
      final year = currentYear - i;
      double totalDistance = 0.0;

      // Filter activities for the specific year
      final activitiesInYear = activities.where(
        (entry) => entry.startTime.year == year,
      );

      for (var entry in activitiesInYear) {
        totalDistance += entry.distanceKm ?? 0.0;
      }
      yearlyDistances[year] = totalDistance;
    }

    // Must be returned sorted ascending by year (year 1-6)
    final sortedKeys = yearlyDistances.keys.toList()..sort();
    final Map<int, double> result = {};
    int chartKey = 1;
    for (var year in sortedKeys) {
      result[chartKey] = yearlyDistances[year]!;
      chartKey++;
    }
    return result;
  }

  /// Calculates summed distance (km) per month
  Map<String, double> getDistancePerMonth() {
    final Map<String, double> distanceMap = {};

    for (final entry in _combinedActivities) {
      if (entry.distanceKm != null && entry.distanceKm! > 0) {
        final String yearMonthKey =
            '${entry.startTime.year}-${entry.startTime.month.toString().padLeft(2, '0')}';
        final double distance = entry.distanceKm!;

        distanceMap.update(
          yearMonthKey,
          (existingDistance) => existingDistance + distance,
          ifAbsent: () => distance,
        );
      }
    }
    return distanceMap;
  }

  /// Calculates total statistics (Total)
  Map<String, dynamic> getTotalStats() {
    double totalDistanceKm = 0.0;
    int totalDurationSeconds = 0;

    for (final entry in _combinedActivities) {
      totalDistanceKm += entry.distanceKm ?? 0.0;
      totalDurationSeconds += entry.duration?.inSeconds ?? 0;
    }

    return {
      'distanceKm': totalDistanceKm,
      // Convert to hours (as Double for display)
      'durationHours': totalDurationSeconds / 3600.0,
      'durationSeconds': totalDurationSeconds,
      'sessions': _combinedActivities.length,
    };
  }

  // ===================== CLEANUP =====================
}
