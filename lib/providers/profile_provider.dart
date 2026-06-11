import 'package:flutter/foundation.dart';
import 'package:benefitflutter/core/logging/app_logger.dart';
import 'package:benefitflutter/features/user/domain/user.dart';
import 'package:benefitflutter/features/user/data/user_repository.dart';
import 'package:benefitflutter/features/user/domain/user_biometrics_reported.dart';
import 'package:benefitflutter/features/user/domain/user_preferences.dart';
import 'package:benefitflutter/providers/auth_provider.dart';

/// Provider for editable profile data (profile fields, biometrics, preferences).
///
/// Identity (current User, userId, tokens) lives in [AuthProvider]. This provider
/// performs profile mutations via the repository and pushes the updated User back
/// into AuthProvider (the single source of truth) via [AuthProvider.setCurrentUser].
/// Wired as `ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>`.
class ProfileProvider extends ChangeNotifier {
  final UserRepository _repository;
  AuthProvider? _auth;

  ProfileProvider(this._repository);

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Called by the ProxyProvider whenever AuthProvider updates.
  void attachAuth(AuthProvider auth) {
    _auth = auth;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<UserBiometricsReported?> getLatestBiometrics(String userId) {
    return _repository.getLatestBiometrics(userId);
  }

  Future<UserPreferences?> getPreferences(String userId) {
    return _repository.getPreferences(userId);
  }

  Future<void> saveBiometrics(UserBiometricsReported biometrics) {
    return _repository.saveBiometrics(biometrics);
  }

  Future<void> savePreferences(UserPreferences prefs) {
    return _repository.savePreferences(prefs);
  }

  /// Update the user profile: persist to the repository (durable) first, then
  /// sync the in-memory identity in AuthProvider. The repository is the source
  /// of truth, so a crash after the write is recovered on next initialize().
  Future<bool> updateUser(User updatedUser) async {
    if (_auth?.currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.updateUser(updatedUser);
      _auth!.setCurrentUser(updatedUser);
      _error = null;
      AppLogger.d('ProfileProvider: Updated user ${updatedUser.name}');
      return true;
    } catch (e) {
      _error = 'Failed to update profile: $e';
      AppLogger.e('ProfileProvider: Update error - $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
