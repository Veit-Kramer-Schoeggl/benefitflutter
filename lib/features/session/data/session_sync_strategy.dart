import '../domain/session.dart';
import '../../shared/sync/base_sync_strategy.dart';
import 'package:benefitflutter/core/enums/session_status.dart';

/// Session-specific sync strategy with complex rules
///
/// Different from User sync:
/// - High priority: Sessions sync immediately when completed
/// - Active sessions DON'T sync (local-only until completed)
/// - Completed sessions trigger benefit calculations
/// - Conflict resolution considers session status
class SessionSyncStrategy extends BaseSyncStrategy<Session> {
  @override
  bool get requiresSync => true;

  @override
  Future<bool> shouldSync(Session entity) async {
    // Only sync completed sessions
    // Active/paused sessions stay local until completed
    return entity.status == SessionStatus.completed;
  }

  @override
  Future<bool> uploadToRemote(Session entity) async {
    // TODO: Implement API call when PostgREST is ready
    // Example:
    // final response = await apiClient.post('/sessions', entity.toJson());
    // return response.statusCode == 201;

    // For now, simulate success (Phase 1: SQLite only)
    return Future.value(true);
  }

  @override
  Future<Session> downloadFromRemote(String entityId) async {
    // TODO: Implement API call when PostgREST is ready
    // Example:
    // final response = await apiClient.get('/sessions/$entityId');
    // return Session.fromJson(response.data);

    throw UnimplementedError('PostgREST not yet configured');
  }

  @override
  Future<Session> resolveConflict(Session local, Session remote) async {
    // Complex conflict resolution based on session status:

    // Case 1: Local session is active/paused - ALWAYS keep local
    // User is currently tracking, local state is authoritative
    if (local.status == SessionStatus.active ||
        local.status == SessionStatus.paused) {
      return local;
    }

    // Case 2: Both completed - keep the one with later endTime
    // Assumes last completed version is correct
    if (local.status == SessionStatus.completed &&
        remote.status == SessionStatus.completed) {
      if (local.endTime != null && remote.endTime != null) {
        return local.endTime!.isAfter(remote.endTime!) ? local : remote;
      }
    }

    // Case 3: Remote is completed but local isn't - take remote
    // Remote has more complete data
    if (remote.status == SessionStatus.completed &&
        local.status != SessionStatus.completed) {
      return remote;
    }

    // Default: Remote wins (server is source of truth)
    return remote;
  }

  @override
  Future<void> queueForSync(Session entity, String operation) async {
    // TODO: Implement sync queue insertion
    // Only queue if session is completed
    if (entity.status == SessionStatus.completed) {
      // Example:
      // await syncQueue.add(
      //   entityType: 'session',
      //   entityId: entity.id,
      //   operation: operation,
      //   data: jsonEncode(entity.toJson()),
      //   priority: 'high', // Sessions are high priority
      // );
    }

    // For now, no-op (Phase 1: SQLite only)
  }

  @override
  Future<void> processQueue() async {
    // TODO: Implement queue processing for sessions
    // Example:
    // final pending = await syncQueue.getPending('session');
    // for (final item in pending) {
    //   final session = Session.fromJson(jsonDecode(item.data));
    //
    //   // Only sync if completed
    //   if (session.status == SessionStatus.completed) {
    //     try {
    //       await uploadToRemote(session);
    //       await syncQueue.markComplete(item.id);
    //
    //       // Trigger benefit calculation after successful sync
    //       await _triggerBenefitCalculation(session);
    //     } catch (e) {
    //       await syncQueue.incrementRetry(item.id, e.toString());
    //     }
    //   }
    // }

    // For now, no-op (Phase 1: SQLite only)
  }

  // Commented out until benefit awarding logic is implemented
  // /// Trigger benefit calculation when session completes
  // /// Called after successful sync of completed session
  // Future<void> _triggerBenefitCalculation(Session session) async {
  //   // Automatic benefit awarding based on session completion
  //   // This is a placeholder - actual logic will be implemented
  //   // when benefit rules are defined (e.g., award after X sessions/distance)
  //
  //   // TODO: Implement benefit awarding logic
  //   // Example:
  //   // final benefitRepo = BenefitRepositoryImpl.create();
  //   // await benefitRepo.checkAndAwardBenefits(session);
  //
  //   // For now, this is called but does nothing
  //   // Will be enhanced with actual benefit rules in future iterations
  // }

  @override
  int get maxRetries => 5; // More retries for important session data

  @override
  int get retryDelaySeconds => 10; // Longer delay between retries
}
