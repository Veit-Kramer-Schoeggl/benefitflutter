import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/features/session/data/gps_point_dao.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/features/wearable_integration/domain/sensor_data_point.dart';

/// In-memory [SessionRepository] for tests. Shared by activity/progress tests
/// and the routed widget-test harness.
class MockSessionRepository implements SessionRepository {
  final List<Session> _sessions = [];

  /// Pre-seed sessions synchronously (used by the harness before provider
  /// wiring, since [getAllSessions] has no delay seam to seed against later).
  void seedSessions(List<Session> sessions) => _sessions.addAll(sessions);

  @override
  Future<Session> createSession(Session session) async {
    _sessions.add(session);
    return session;
  }

  @override
  Future<void> updateSession(Session session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = session;
    }
  }

  @override
  Future<void> finalizeSession(
    Session completed, {
    SessionSensorSummary? summary,
  }) async {
    await updateSession(completed);
  }

  @override
  Future<List<Session>> getAllSessions({required String userId}) async {
    return _sessions.where((s) => s.userId == userId).toList();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<Session> getSessionById(String sessionId) async {
    return _sessions.firstWhere((s) => s.id == sessionId);
  }

  @override
  Future<List<Session>> getSessionsByActivityType({
    required String userId,
    required ActivityType activityType,
  }) async {
    return _sessions
        .where((s) => s.userId == userId && s.activityType == activityType)
        .toList();
  }

  @override
  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required SessionStatus status,
  }) async {
    return _sessions
        .where((s) => s.userId == userId && s.status == status)
        .toList();
  }

  @override
  Future<List<Session>> getSessionsInDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _sessions
        .where(
          (s) =>
              s.userId == userId &&
              s.startTime.isAfter(startDate) &&
              s.startTime.isBefore(endDate),
        )
        .toList();
  }
}

/// Records GPS DAO writes without touching the database. Live tracking goes
/// through [insertBatch]; [insert] is recorded too so tests can assert it is
/// never used once batching is in place.
class FakeGpsPointDao extends GpsPointDao {
  int insertCalls = 0;
  final List<List<GpsPoint>> batches = [];
  final List<GpsPoint> persisted = [];

  @override
  Future<void> insert(GpsPoint point) async {
    insertCalls++;
    persisted.add(point);
  }

  @override
  Future<void> insertBatch(List<GpsPoint> points) async {
    batches.add(List<GpsPoint>.of(points));
    persisted.addAll(points);
  }
}
