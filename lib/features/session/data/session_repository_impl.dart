import '../domain/session.dart';
import 'session_repository.dart';
import 'session_dao.dart';
import 'session_sync_strategy.dart';
import '../../shared/utils/connectivity_service.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

/// Concrete implementation of SessionRepository
///
/// Combines:
/// - Local storage (SessionDao)
/// - Remote sync (SessionSyncStrategy)
/// - Connectivity (ConnectivityService)
///
/// Different sync behavior than User:
/// - Active sessions stay local (no sync)
/// - Completed sessions sync immediately (high priority)
/// - Triggers benefit calculation on completion
class SessionRepositoryImpl implements SessionRepository {
  final SessionDao _dao;
  final SessionSyncStrategy _syncStrategy;
  final ConnectivityService _connectivity;

  SessionRepositoryImpl({
    required SessionDao dao,
    required SessionSyncStrategy syncStrategy,
    required ConnectivityService connectivity,
  })  : _dao = dao,
        _syncStrategy = syncStrategy,
        _connectivity = connectivity;

  /// Factory constructor with default dependencies
  factory SessionRepositoryImpl.create() {
    return SessionRepositoryImpl(
      dao: SessionDao(),
      syncStrategy: SessionSyncStrategy(),
      connectivity: ConnectivityService(),
    );
  }

  @override
  Future<List<Session>> getAllSessions({required String userId}) async {
    // Read from local database
    return await _dao.findByUserId(userId);
  }

  @override
  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required SessionStatus status,
  }) async {
    return await _dao.findByStatus(userId, status);
  }

  @override
  Future<List<Session>> getSessionsByActivityType({
    required String userId,
    required ActivityType activityType,
  }) async {
    return await _dao.findByActivityType(userId, activityType);
  }

  @override
  Future<Session> getSessionById(String sessionId) async {
    final session = await _dao.findById(sessionId);

    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }

    return session;
  }

  @override
  Future<Session> createSession(Session session) async {
    // 1. Insert locally
    await _dao.insert(session);

    // 2. Active sessions DON'T sync yet
    // They'll sync when completed
    if (session.status == SessionStatus.completed) {
      await _syncCompletedSession(session);
    }

    return session;
  }

  @override
  Future<void> updateSession(Session session) async {
    // 1. Update locally first
    await _dao.update(session);

    // 2. Different sync behavior based on status
    if (session.status == SessionStatus.completed) {
      // Completed sessions: immediate high-priority sync
      await _syncCompletedSession(session);
    } else {
      // Active/paused sessions: stay local, no sync yet
      // Will sync when they transition to completed
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _dao.delete(sessionId);

    // TODO: Queue deletion for sync when online
    // For now, just delete locally
  }

  @override
  Future<List<Session>> getSessionsInDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await _dao.findByDateRange(userId, startDate, endDate);
  }

  /// Sync completed session to remote
  /// High priority: Completed sessions trigger benefits
  Future<void> _syncCompletedSession(Session session) async {
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      try {
        final success = await _syncStrategy.uploadToRemote(session);
        if (!success) {
          // Failed: queue for later
          await _syncStrategy.queueForSync(session, 'update');
        }
      } catch (e) {
        // Error: queue for later
        await _syncStrategy.queueForSync(session, 'update');
      }
    } else {
      // Offline: queue for sync when connection returns
      await _syncStrategy.queueForSync(session, 'update');
    }
  }
}
