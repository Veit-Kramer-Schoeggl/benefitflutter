// Feature module implementations (SQLite)
import 'package:benefitflutter/features/user/data/user_repository_impl.dart';
import 'package:benefitflutter/features/session/data/session_repository_impl.dart';
import 'package:benefitflutter/features/benefit/data/benefit_repository_impl.dart';

/// Central configuration for repository implementations
/// Uses feature-based SQLite architecture (production ready)
class RepositoryConfig {
  // Feature modules with SQLite are now the default and only implementation
  // Mock repositories have been removed

  /// Get session repository implementation
  static dynamic getSessionRepository() {
    return SessionRepositoryImpl.create();
  }

  /// Get user repository implementation
  static dynamic getUserRepository() {
    return UserRepositoryImpl.create();
  }

  /// Get benefit repository implementation
  static dynamic getBenefitRepository() {
    return BenefitRepositoryImpl.create();
  }
}
