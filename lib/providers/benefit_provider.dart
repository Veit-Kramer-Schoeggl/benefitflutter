import 'package:flutter/foundation.dart';
import 'package:benefitflutter/features/benefit/data/benefit_repository.dart';
import 'package:benefitflutter/features/benefit/domain/benefit.dart';
import 'package:benefitflutter/features/benefit/domain/user_benefit.dart';
import 'package:benefitflutter/features/benefit/domain/benefit_view_model.dart';
import 'package:benefitflutter/features/benefit/domain/benefit_partner.dart';

/// Provider for Benefit screen state management
/// Manages loading, error, and data states for benefits
/// Extends ChangeNotifier to automatically notify UI of state changes
class BenefitProvider extends ChangeNotifier {
  final BenefitRepository _repository;

  BenefitProvider(this._repository);

  // ===== STATE VARIABLES =====

  /// Currently authenticated user
  String? _currentUserId;

  /// Loading state (initial fetch)
  bool _isLoading = false;

  /// Refreshing state (pull-to-refresh)
  bool _isRefreshing = false;

  /// Error message (null if no error)
  String? _error;

  /// List of user's earned benefits
  List<UserBenefit> _userBenefits = [];

  /// List of all available benefits (metadata)
  List<Benefit> _benefits = [];

  /// List of all BeneFit partners
  List<BenefitPartner> _partners = [];
  bool _isLoadingPartners = false;

  /// Total savings earned by user
  double _totalSavings = 0.0;

  // ===== GETTERS =====

  /// Is currently loading (initial fetch)
  bool get isLoading => _isLoading;

  /// Is currently refreshing (pull-to-refresh)
  bool get isRefreshing => _isRefreshing;

  /// Current error message
  String? get error => _error;

  /// Total savings amount
  double get totalSavings => _totalSavings;

  /// Has an error occurred
  bool get hasError => _error != null;

  /// Has the user earned any benefits
  bool get hasEarnedBenefits => _userBenefits.isNotEmpty;

  /// Is in empty state (not loading and no benefits)
  bool get isEmpty => !_isLoading && _userBenefits.isEmpty;

  List<BenefitPartner> get partners => _partners;

  bool get isLoadingPartners => _isLoadingPartners;

  /// Combined view models (joins UserBenefit + Benefit data)
  /// This is what the UI consumes
  List<BenefitViewModel> get earnedBenefits {
    return _userBenefits.map((userBenefit) {
      // Find the matching benefit metadata
      final benefit = _benefits.firstWhere(
        (b) => b.id == userBenefit.benefitId,
        orElse: () => Benefit(
          id: 'unknown',
          title: 'Unknown Benefit',
          description: 'Benefit details not found',
          discountAmount: 0.0,
        ),
      );

      return BenefitViewModel(userBenefit: userBenefit, benefit: benefit);
    }).toList();
  }

  // ===== METHODS =====

  /// Fetch benefits for the first time
  /// Shows loading spinner while fetching
  Future<void> fetchBenefits() async {
    if (_currentUserId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners(); // Trigger UI rebuild to show loading

    try {
      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        _repository.getUserBenefits(userId: _currentUserId!),
        _repository.getAllBenefits(),
        _repository.getTotalDiscountEarned(userId: _currentUserId!),
      ]);

      // Update state with fetched data
      _userBenefits = results[0] as List<UserBenefit>;
      _benefits = results[1] as List<Benefit>;
      _totalSavings = results[2] as double;
      _error = null;
    } catch (e) {
      // Handle error
      _error = 'Failed to load benefits: ${e.toString()}';
      _userBenefits = [];
      _benefits = [];
      _totalSavings = 0.0;
    } finally {
      _isLoading = false;
      notifyListeners(); // Trigger UI rebuild with new state
    }
  }

  /// Refresh benefits (pull-to-refresh)
  /// Keeps existing data visible while refreshing
  Future<void> refresh() async {
    if (_currentUserId == null) return;
    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getUserBenefits(userId: _currentUserId!),
        _repository.getAllBenefits(),
        _repository.getTotalDiscountEarned(userId: _currentUserId!),
      ]);

      _userBenefits = results[0] as List<UserBenefit>;
      _benefits = results[1] as List<Benefit>;
      _totalSavings = results[2] as double;
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh: ${e.toString()}';
      // Keep existing data on refresh error
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Retry after error
  Future<void> retry() => fetchBenefits();

  Future<void> redeemBenefit({required String userBenefitId}) async {
    if (_currentUserId == null) return;
    try {
      final code = _generateRedemptionCode();
      await _repository.redeemBenefit(
        userBenefitId: userBenefitId,
        redemptionCode: code,
      );

      // Refresh state after redemption
      await fetchBenefits();
    } catch (e) {
      _error = 'Failed to redeem benefit';
      notifyListeners();
    }
  }

  String _generateRedemptionCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = (timestamp % 100000).toString().padLeft(5, '0');
    return 'BF$randomPart';
  }

  Future<void> loadPartners(String benefitId) async {
    _isLoadingPartners = true;
    notifyListeners();

    try {
      _partners = await _repository.getPartnersForBenefit(benefitId);
    } catch (_) {
      _partners = [];
    } finally {
      _isLoadingPartners = false;
      notifyListeners();
    }
  }

  /// Called by ProxyProvider when userId changes
  void updateUserId(String? userId) {
    // Prevent unnecessary reloads
    if (_currentUserId == userId) return;

    _currentUserId = userId;

    // If user logs out → reset state
    if (userId == null) {
      _userBenefits = [];
      _benefits = [];
      _partners = [];
      _totalSavings = 0.0;
      _error = null;
      notifyListeners();
      return;
    }

    // If user logs in → load benefits
    fetchBenefits();
  }
}
