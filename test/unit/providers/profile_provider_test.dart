import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/providers/profile_provider.dart';
import 'package:benefitflutter/features/user/domain/user_biometrics_reported.dart';
import 'package:benefitflutter/features/user/domain/user_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late FakeUserRepository repo;
  late FakeAuthService auth;
  late FakeTokenStorage tokens;

  /// A ProfileProvider attached to a logged-in AuthProvider (the realistic
  /// ProxyProvider wiring used in main.dart).
  Future<(ProfileProvider, AuthProvider)> buildAttached() async {
    repo.users['user-1'] = userFixture();
    auth.loginUserId = 'user-1';
    final authProvider = AuthProvider(
      repository: repo,
      authService: auth,
      tokenStorage: tokens,
      rateLimiter: freshRateLimiter(),
    );
    await authProvider.login('alice@example.com', 'pw');

    final profile = ProfileProvider(repo)..attachAuth(authProvider);
    return (profile, authProvider);
  }

  setUp(() {
    repo = FakeUserRepository();
    auth = FakeAuthService();
    tokens = FakeTokenStorage();
  });

  group('updateUser', () {
    test('no logged-in user → error, returns false', () async {
      final profile = ProfileProvider(repo); // no auth attached

      final ok = await profile.updateUser(userFixture());

      expect(ok, isFalse);
      expect(profile.error, 'No user logged in');
    });

    test('success → writes repo then syncs AuthProvider identity', () async {
      final (profile, authProvider) = await buildAttached();
      final updated = authProvider.currentUser!.copyWith(displayName: 'Ali');

      final ok = await profile.updateUser(updated);

      expect(ok, isTrue);
      expect(repo.updatedUser?.displayName, 'Ali');
      // AuthProvider remains the single source of identity truth.
      expect(authProvider.currentUser?.displayName, 'Ali');
      expect(profile.error, isNull);
    });

    test('repository failure → error, identity untouched', () async {
      final (profile, authProvider) = await buildAttached();
      final before = authProvider.currentUser;
      repo.throwOnUpdate = true; // force the repo write to fail

      final ok = await profile.updateUser(
        authProvider.currentUser!.copyWith(displayName: 'X'),
      );

      expect(ok, isFalse);
      expect(profile.error, contains('Failed to update profile'));
      expect(authProvider.currentUser, before); // unchanged
    });

    test('toggles isLoading around the operation', () async {
      final (profile, authProvider) = await buildAttached();

      expect(profile.isLoading, isFalse);
      final future = profile.updateUser(
        authProvider.currentUser!.copyWith(displayName: 'Z'),
      );
      // synchronous portion has set loading true before the first await resolves
      await future;
      expect(profile.isLoading, isFalse);
    });
  });

  group('biometrics & preferences passthrough', () {
    test('getLatestBiometrics delegates to repository', () async {
      final bio = UserBiometricsReported(
        id: 'b1',
        userId: 'user-1',
        reportDate: DateTime(2026, 1, 1),
        heightCm: 180,
        weightKg: 75,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      repo.latestBiometrics = bio;
      final profile = ProfileProvider(repo);

      final result = await profile.getLatestBiometrics('user-1');

      expect(result, bio);
    });

    test('getPreferences delegates to repository', () async {
      final prefs = UserPreferences(
        id: 'p1',
        userId: 'user-1',
        defaultLocationCity: 'Vienna',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      repo.preferences = prefs;
      final profile = ProfileProvider(repo);

      final result = await profile.getPreferences('user-1');

      expect(result, prefs);
    });

    test('saveBiometrics / savePreferences delegate to repository', () async {
      final profile = ProfileProvider(repo);
      final bio = UserBiometricsReported(
        id: 'b1',
        userId: 'user-1',
        reportDate: DateTime(2026, 1, 1),
        heightCm: 170,
        weightKg: 60,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final prefs = UserPreferences(
        id: 'p1',
        userId: 'user-1',
        defaultLocationCity: 'Graz',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await profile.saveBiometrics(bio);
      await profile.savePreferences(prefs);

      expect(repo.savedBiometrics, bio);
      expect(repo.savedPreferences, prefs);
    });
  });

  group('error ownership', () {
    test('clearError resets ProfileProvider error independently', () async {
      final profile = ProfileProvider(repo); // no auth → updateUser errors

      await profile.updateUser(userFixture());
      expect(profile.hasError, isTrue);

      profile.clearError();
      expect(profile.hasError, isFalse);
      expect(profile.error, isNull);
    });
  });
}
