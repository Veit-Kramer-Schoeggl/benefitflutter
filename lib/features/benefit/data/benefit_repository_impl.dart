import '../domain/benefit.dart';
import '../domain/user_benefit.dart';
import 'benefit_repository.dart';
import 'benefit_dao.dart';
import 'benefit_sync_strategy.dart';
import '../../shared/utils/connectivity_service.dart';
import '../domain/benefit_partner.dart';

/// Concrete implementation of BenefitRepository
///
/// Combines:
/// - Local storage (BenefitDao)
/// - Remote sync (BenefitSyncStrategy)
/// - Connectivity (ConnectivityService)
///
/// Simpler than Session: No complex state management
/// Benefits are awarded and synced straightforwardly
class BenefitRepositoryImpl implements BenefitRepository {
  final BenefitDao _dao;
  final BenefitSyncStrategy _syncStrategy;
  final ConnectivityService _connectivity;

  BenefitRepositoryImpl({
    required BenefitDao dao,
    required BenefitSyncStrategy syncStrategy,
    required ConnectivityService connectivity,
  })  : _dao = dao,
        _syncStrategy = syncStrategy,
        _connectivity = connectivity;

  /// Factory constructor with default dependencies
  factory BenefitRepositoryImpl.create() {
    return BenefitRepositoryImpl(
      dao: BenefitDao(),
      syncStrategy: BenefitSyncStrategy(),
      connectivity: ConnectivityService(),
    );
  }

  @override
  Future<List<Benefit>> getAllBenefits() async {
    // Read from local database
    return await _dao.findAllBenefits();
  }

  @override
  Future<List<UserBenefit>> getUserBenefits({required String userId}) async {
    // Read from local database
    return await _dao.findUserBenefits(userId);
  }

  @override
  Future<UserBenefit> awardBenefit({
    required String userId,
    required String benefitId,
    required String sessionId,
  }) async {
    // 1. Create UserBenefit entity
    final userBenefit = UserBenefit(
      id: _generateId(),
      userId: userId,
      benefitId: benefitId,
      sessionId: sessionId,
      earnedAt: DateTime.now(),
    );

    // 2. Insert locally
    await _dao.insertUserBenefit(userBenefit);

    // 3. Sync to remote if online
    final isOnline = await _connectivity.isOnline();
    if (isOnline) {
      try {
        await _syncStrategy.uploadToRemote(userBenefit);
      } catch (e) {
        // If sync fails, queue for later
        await _syncStrategy.queueForSync(userBenefit, 'create');
      }
    } else {
      // Offline: queue for sync when connection returns
      await _syncStrategy.queueForSync(userBenefit, 'create');
    }

    return userBenefit;
  }

  @override
  Future<double> getTotalDiscountEarned({required String userId}) async {
    // Use DAO's JOIN query for efficient calculation
    return await _dao.calculateTotalSavings(userId);
  }

  /// Generate unique ID for UserBenefit
  /// Using timestamp + random for simplicity (replace with UUID in production)
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'ub_${timestamp}_$random';
  }

  @override
  Future<void> redeemBenefit({
    required String userBenefitId,
    required String redemptionCode,
  }) async {

    // 1. Update local DB
    await _dao.redeemUserBenefit(
      userBenefitId,
      redemptionCode,
    );

    // 2. Lade aktualisierte Entity für Sync
    final updated = await _dao.findUserBenefitById(userBenefitId);

    if (updated == null) return;

    // 3. Sync
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      try {
        await _syncStrategy.queueForSync(updated, 'redeem');
      } catch (_) {
        await _syncStrategy.queueForSync(updated, 'redeem');
      }
    } else {
      await _syncStrategy.queueForSync(updated, 'redeem');
    }
  }

  @override
  Future<List<BenefitPartner>> getPartnersForBenefit(String benefitId) async {
    // Phase 1: Hardcoded mock partners

    return [
      BenefitPartner(
        id: 'p1',
        benefitId: benefitId,
        name: 'FitCafe',
        city: 'Graz',
        address: 'Herrengasse 12',
      ),
      BenefitPartner(
        id: 'p2',
        benefitId: benefitId,
        name: 'SportShop Pro',
        city: 'Vienna',
        address: 'Mariahilfer Straße 45',
      ),
    ];
  }
}
