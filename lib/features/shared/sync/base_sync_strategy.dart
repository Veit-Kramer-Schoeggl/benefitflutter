/// Abstract base class for entity-specific sync strategies
///
/// Each feature module can implement custom sync logic:
/// - Users: Immediate sync for profile changes
/// - Sessions: Queue for batch upload when online
/// - Benefits: Read-only, no local changes to sync
///
/// This allows fine-grained control over sync behavior per entity type
abstract class BaseSyncStrategy<T> {
  /// Check if this entity should be synced to remote
  ///
  /// Returns true if:
  /// - Entity has local changes
  /// - Entity meets sync criteria (e.g., session is completed)
  /// - Network is available (checked by caller)
  Future<bool> shouldSync(T entity);

  /// Upload local entity to remote API
  ///
  /// Returns true if sync succeeded, false otherwise
  /// Throws exception on network/API errors
  Future<bool> uploadToRemote(T entity);

  /// Download remote entity and merge with local
  ///
  /// Handles conflict resolution based on strategy:
  /// - Remote wins (default for read-only data)
  /// - Local wins (for user preferences)
  /// - Last write wins (timestamp-based)
  /// - Custom merge logic
  Future<T> downloadFromRemote(String entityId);

  /// Resolve conflicts when both local and remote changed
  ///
  /// Default implementation: remote wins (can be overridden)
  Future<T> resolveConflict(T local, T remote) async {
    // Default strategy: remote wins
    return remote;
  }

  /// Queue entity for later sync when offline
  ///
  /// Adds to sync_queue table with operation type (create/update/delete)
  Future<void> queueForSync(T entity, String operation);

  /// Process queued entities for this type
  ///
  /// Called when network becomes available
  /// Processes all pending operations in order
  Future<void> processQueue();

  /// Determine if this entity type requires sync
  ///
  /// Some entities are read-only from API (e.g., benefits catalog)
  /// Others need bidirectional sync (e.g., user profile, sessions)
  bool get requiresSync;

  /// Maximum retry attempts for failed syncs
  int get maxRetries => 3;

  /// Delay between retry attempts (in seconds)
  int get retryDelaySeconds => 5;
}

/// Sync operation types
enum SyncOperation {
  create,
  update,
  delete;

  String toJson() => name;

  static SyncOperation fromJson(String json) {
    return SyncOperation.values.firstWhere((e) => e.name == json);
  }
}

/// Sync result status
enum SyncStatus {
  success,
  failure,
  pending,
  conflict;

  String toJson() => name;

  static SyncStatus fromJson(String json) {
    return SyncStatus.values.firstWhere((e) => e.name == json);
  }
}
