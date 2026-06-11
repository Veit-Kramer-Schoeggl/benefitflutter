import '../domain/user_benefit.dart';
import '../../shared/sync/base_sync_strategy.dart';

/// Benefit-specific sync strategy
///
/// Simpler than User/Session:
/// - Benefits catalog: Read-only from API (no local changes)
/// - UserBenefits: Write-only to API (award locally, sync to remote)
/// - Low priority: Benefits don't need immediate sync
/// - Simple conflict resolution: Remote wins (benefits are static data)
class BenefitSyncStrategy extends BaseSyncStrategy<UserBenefit> {
  @override
  bool get requiresSync => true;

  @override
  Future<bool> shouldSync(UserBenefit entity) async {
    // UserBenefits should always sync when awarded
    return true;
  }

  @override
  Future<bool> uploadToRemote(UserBenefit entity) async {
    // TODO: Implement API call when PostgREST is ready
    // Example:
    // final response = await apiClient.post('/user_benefits', entity.toJson());
    // return response.statusCode == 201;

    // For now, simulate success (Phase 1: SQLite only)
    return Future.value(true);
  }

  @override
  Future<UserBenefit> downloadFromRemote(String entityId) async {
    // TODO: Implement API call when PostgREST is ready
    // Example:
    // final response = await apiClient.get('/user_benefits/$entityId');
    // return UserBenefit.fromJson(response.data);

    throw UnimplementedError('PostgREST not yet configured');
  }

  @override
  Future<UserBenefit> resolveConflict(
    UserBenefit local,
    UserBenefit remote,
  ) async {
    // Simple strategy: Remote wins
    // UserBenefits are immutable once created, conflicts should be rare
    return remote;
  }

  @override
  Future<void> queueForSync(UserBenefit entity, String operation) async {
    // TODO: Implement sync queue insertion
    // Example:
    // await syncQueue.add(
    //   entityType: 'user_benefit',
    //   entityId: entity.id,
    //   operation: operation,
    //   data: jsonEncode(entity.toJson()),
    //   priority: 'medium', // Benefits are medium priority
    // );

    // For now, no-op (Phase 1: SQLite only)
  }

  @override
  Future<void> processQueue() async {
    // TODO: Implement queue processing for user_benefits
    // Example:
    // final pending = await syncQueue.getPending('user_benefit');
    // for (final item in pending) {
    //   try {
    //     final userBenefit = UserBenefit.fromJson(jsonDecode(item.data));
    //     await uploadToRemote(userBenefit);
    //     await syncQueue.markComplete(item.id);
    //   } catch (e) {
    //     await syncQueue.incrementRetry(item.id, e.toString());
    //   }
    // }

    // For now, no-op (Phase 1: SQLite only)
  }

  @override
  int get maxRetries => 3; // Standard retry count

  @override
  int get retryDelaySeconds => 5; // Standard delay
}
