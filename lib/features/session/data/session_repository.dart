import '../domain/session.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/features/wearable_integration/domain/sensor_data_point.dart';

/// Repository interface for session data operations
/// Both MockSessionRepository and ApiSessionRepository implement this
abstract class SessionRepository {
  /// Get all sessions for a user
  Future<List<Session>> getAllSessions({required String userId});

  /// Get sessions filtered by status
  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required SessionStatus status,
  });

  /// Get sessions filtered by activity type
  Future<List<Session>> getSessionsByActivityType({
    required String userId,
    required ActivityType activityType,
  });

  /// Get a single session by ID
  Future<Session> getSessionById(String sessionId);

  /// Create a new session
  Future<Session> createSession(Session session);

  /// Update an existing session
  Future<void> updateSession(Session session);

  /// Atomically persist a completed session and its optional sensor [summary]
  /// in one DB transaction, then sync (outside the transaction).
  Future<void> finalizeSession(
    Session completed, {
    SessionSensorSummary? summary,
  });

  /// Delete a session
  Future<void> deleteSession(String sessionId);

  /// Get sessions in a date range
  Future<List<Session>> getSessionsInDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  });
}
