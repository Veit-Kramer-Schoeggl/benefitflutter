import '../domain/user.dart';
import '../../shared/sync/base_sync_strategy.dart';

/// User-specific sync strategy
///
/// Defines how User entities sync with remote API:
/// - Medium priority (not critical like sessions)
/// - Remote wins in conflicts (server is source of truth)
/// - Can be batched with other updates
class UserSyncStrategy extends BaseSyncStrategy<User> {
  @override
  bool get requiresSync => true;

  @override
  Future<bool> shouldSync(User entity) async {
    // Users should always sync when changed
    return true;
  }

  @override
  Future<bool> uploadToRemote(User entity) async {
    // TODO: Implement API call when PostgREST is ready
    // Example:
    // final response = await apiClient.put('/users/${entity.id}', entity.toJson());
    // return response.statusCode == 200;

    // For now, simulate success (Phase 1: SQLite only)
    return Future.value(true);
  }

  @override
  Future<User> downloadFromRemote(String entityId) async {
    // TODO: Implement API call when PostgREST is ready
    // Example:
    // final response = await apiClient.get('/users/$entityId');
    // return User.fromJson(response.data);

    throw UnimplementedError('PostgREST not yet configured');
  }

  @override
  Future<User> resolveConflict(User local, User remote) async {
    // Strategy: Remote wins (server is source of truth for user data)
    // In the future, could add timestamp comparison if needed
    return remote;
  }

  @override
  Future<void> queueForSync(User entity, String operation) async {
    // TODO: Implement sync queue insertion
    // Example:
    // await syncQueue.add(
    //   entityType: 'user',
    //   entityId: entity.id,
    //   operation: operation,
    //   data: jsonEncode(entity.toJson()),
    // );

    // For now, no-op (Phase 1: SQLite only)
  }

  @override
  Future<void> processQueue() async {
    // TODO: Implement queue processing
    // Example:
    // final pending = await syncQueue.getPending('user');
    // for (final item in pending) {
    //   try {
    //     await uploadToRemote(User.fromJson(jsonDecode(item.data)));
    //     await syncQueue.markComplete(item.id);
    //   } catch (e) {
    //     await syncQueue.incrementRetry(item.id, e.toString());
    //   }
    // }

    // For now, no-op (Phase 1: SQLite only)
  }
}
