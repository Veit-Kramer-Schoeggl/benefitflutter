import '../domain/user.dart';
import '../domain/user_biometrics_reported.dart';
import '../domain/user_preferences.dart';
import 'user_repository.dart';
import 'user_dao.dart';
import 'user_biometrics_dao.dart';
import 'user_preferences_dao.dart';
import 'user_sync_strategy.dart';
import '../../shared/utils/connectivity_service.dart';

/// Concrete implementation of UserRepository
///
/// Combines:
/// - Local storage (UserDao, UserBiometricsDao, UserPreferencesDao)
/// - Remote sync (UserSyncStrategy)
/// - Connectivity (ConnectivityService)
///
/// Local-first architecture: All operations save locally first,
/// then sync to remote when online
class UserRepositoryImpl implements UserRepository {
  final UserDao _dao;
  final UserBiometricsDao _biometricsDao;
  final UserPreferencesDao _preferencesDao;
  final UserSyncStrategy _syncStrategy;
  final ConnectivityService _connectivity;

  UserRepositoryImpl({
    required UserDao dao,
    required UserBiometricsDao biometricsDao,
    required UserPreferencesDao preferencesDao,
    required UserSyncStrategy syncStrategy,
    required ConnectivityService connectivity,
  }) : _dao = dao,
       _biometricsDao = biometricsDao,
       _preferencesDao = preferencesDao,
       _syncStrategy = syncStrategy,
       _connectivity = connectivity;

  /// Factory constructor with default dependencies
  factory UserRepositoryImpl.create() {
    return UserRepositoryImpl(
      dao: UserDao(),
      biometricsDao: UserBiometricsDao(),
      preferencesDao: UserPreferencesDao(),
      syncStrategy: UserSyncStrategy(),
      connectivity: ConnectivityService(),
    );
  }

  @override
  Future<User> getUserById(String userId) async {
    // Read from local database
    final user = await _dao.findById(userId);

    if (user == null) {
      throw Exception('User not found: $userId');
    }

    // Background sync if online (don't await, fire and forget)
    _syncInBackground(user);

    return user;
  }

  @override
  Future<User> getCurrentUser() async {
    // For MVP: Single user app, return first user
    final user = await _dao.findFirst();

    if (user == null) {
      throw Exception('No user found. Please create a user first.');
    }

    return user;
  }

  @override
  Future<void> updateUser(User user) async {
    // 1. Save locally first (local-first architecture)
    await _dao.update(user);

    // 2. Sync to remote if online
    final isOnline = await _connectivity.isOnline();
    if (isOnline) {
      try {
        await _syncStrategy.uploadToRemote(user);
      } catch (e) {
        // If sync fails, queue for later
        await _syncStrategy.queueForSync(user, 'update');
      }
    } else {
      // Offline: queue for sync when connection returns
      await _syncStrategy.queueForSync(user, 'update');
    }
  }

  @override
  Future<User> createUser(User user) async {
    // 1. Insert locally
    await _dao.insert(user);

    // 2. Sync to remote if online
    final isOnline = await _connectivity.isOnline();
    if (isOnline) {
      try {
        await _syncStrategy.uploadToRemote(user);
      } catch (e) {
        // If sync fails, queue for later
        await _syncStrategy.queueForSync(user, 'create');
      }
    } else {
      // Offline: queue for sync when connection returns
      await _syncStrategy.queueForSync(user, 'create');
    }

    return user;
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = await getCurrentUser();

    await _biometricsDao.deleteByUserId(user.id);
    await _preferencesDao.deleteByUserId(user.id);
    await _dao.delete(user.id);
  }

  /// Background sync (fire and forget)
  Future<void> _syncInBackground(User user) async {
    try {
      final isOnline = await _connectivity.isOnline();
      if (isOnline && await _syncStrategy.shouldSync(user)) {
        await _syncStrategy.uploadToRemote(user);
      }
    } catch (e) {
      // Silent fail - background sync is best-effort
    }
  }

  // ========================================
  // BIOMETRICS (v3)
  // ========================================

  @override
  Future<UserBiometricsReported?> getLatestBiometrics(String userId) async {
    return await _biometricsDao.findLatestByUserId(userId);
  }

  @override
  Future<List<UserBiometricsReported>> getBiometricsHistory(
    String userId,
  ) async {
    return await _biometricsDao.findAllByUserId(userId);
  }

  @override
  Future<void> saveBiometrics(UserBiometricsReported biometrics) async {
    // 1. Save locally first (local-first architecture)
    final existing = await _biometricsDao.findByUserIdAndDate(
      biometrics.userId,
      biometrics.reportDate,
    );

    if (existing != null) {
      // Update existing entry
      await _biometricsDao.update(biometrics);
    } else {
      // Insert new entry
      await _biometricsDao.insert(biometrics);
    }

    // 2. Sync to remote if online (sync queue for biometrics will be added later)
    // For now, biometrics are local-only
  }

  // ========================================
  // PREFERENCES (v3)
  // ========================================

  @override
  Future<UserPreferences?> getPreferences(String userId) async {
    return await _preferencesDao.findByUserId(userId);
  }

  @override
  Future<void> savePreferences(UserPreferences preferences) async {
    // 1. Save locally first (local-first architecture)
    final existing = await _preferencesDao.findByUserId(preferences.userId);

    if (existing != null) {
      // Update existing preferences
      await _preferencesDao.update(preferences);
    } else {
      // Insert new preferences
      await _preferencesDao.insert(preferences);
    }

    // 2. Sync to remote if online (sync queue for preferences will be added later)
    // For now, preferences are local-only
  }
}
