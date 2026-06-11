import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/features/user/domain/user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late FakeUserRepository repo;
  late FakeAuthService auth;
  late FakeTokenStorage tokens;

  AuthProvider buildProvider() => AuthProvider(
    repository: repo,
    authService: auth,
    tokenStorage: tokens,
    rateLimiter: freshRateLimiter(),
  );

  setUp(() {
    repo = FakeUserRepository();
    auth = FakeAuthService();
    tokens = FakeTokenStorage();
  });

  group('initialize', () {
    test('no stored session → unauthenticated, initialized', () async {
      final provider = buildProvider();

      await provider.initialize();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentUser, isNull);
      expect(provider.isInitialized, isTrue);
      expect(provider.error, isNull);
    });

    test('valid stored tokens → restores session', () async {
      repo.users['user-1'] = userFixture();
      tokens.stored = tokensFixture(userId: 'user-1');
      final provider = buildProvider();

      await provider.initialize();

      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser?.id, 'user-1');
      expect(provider.accessToken, tokens.stored?.accessToken);
    });

    test('expired tokens + successful refresh → restores session', () async {
      repo.users['user-1'] = userFixture();
      tokens.stored = tokensFixture(userId: 'user-1', expired: true);
      auth.refreshSucceeds = true;
      auth.refreshTokens = tokensFixture(userId: 'user-1');
      final provider = buildProvider();

      await provider.initialize();

      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser?.id, 'user-1');
      expect(tokens.stored, auth.refreshTokens);
    });

    test('expired tokens + failed refresh → clears session', () async {
      repo.users['user-1'] = userFixture();
      tokens.stored = tokensFixture(userId: 'user-1', expired: true);
      auth.refreshSucceeds = false;
      final provider = buildProvider();

      await provider.initialize();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentUser, isNull);
      expect(provider.isInitialized, isTrue);
      expect(tokens.stored, isNull);
      expect(tokens.clearCount, greaterThan(0));
    });

    test('is idempotent (guarded by _isInitialized)', () async {
      final provider = buildProvider();
      await provider.initialize();

      // Second call must not touch storage again.
      tokens.stored = tokensFixture(userId: 'user-1');
      repo.users['user-1'] = userFixture();
      await provider.initialize();

      expect(provider.isAuthenticated, isFalse);
    });
  });

  group('login', () {
    test('success → authenticated, tokens persisted', () async {
      repo.users['user-1'] = userFixture();
      auth.loginUserId = 'user-1';
      final provider = buildProvider();

      final ok = await provider.login('alice@example.com', 'pw');

      expect(ok, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.userId, 'user-1');
      expect(tokens.stored, isNotNull);
      expect(provider.error, isNull);
    });

    test('empty email → validation error, no auth', () async {
      final provider = buildProvider();

      final ok = await provider.login('   ', 'pw');

      expect(ok, isFalse);
      expect(provider.error, 'Please enter your email');
      expect(provider.isAuthenticated, isFalse);
    });

    test('empty password → validation error', () async {
      final provider = buildProvider();

      final ok = await provider.login('alice@example.com', '  ');

      expect(ok, isFalse);
      expect(provider.error, 'Please enter your password');
    });

    test('auth service failure → error with remaining attempts', () async {
      auth.loginSucceeds = false;
      final provider = buildProvider();

      final ok = await provider.login('alice@example.com', 'wrong');

      expect(ok, isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.error, contains('attempts remaining'));
    });

    test('user not in repository → clears tokens, friendly error', () async {
      auth.loginUserId = 'ghost';
      repo.throwOnGetById = true;
      final provider = buildProvider();

      final ok = await provider.login('alice@example.com', 'pw');

      expect(ok, isFalse);
      expect(provider.error, 'No account found with this email');
      expect(tokens.stored, isNull);
    });

    test('locks out after max failed attempts', () async {
      auth.loginSucceeds = false;
      final provider = buildProvider();

      // 5 failed attempts (SecurityConfig.maxLoginAttempts) trigger lockout.
      for (var i = 0; i < 5; i++) {
        await provider.login('alice@example.com', 'wrong');
      }
      final ok = await provider.login('alice@example.com', 'wrong');

      expect(ok, isFalse);
      expect(provider.error, contains('Too many login attempts'));
    });
  });

  group('logout', () {
    test('clears user, tokens and notifies server', () async {
      repo.users['user-1'] = userFixture();
      auth.loginUserId = 'user-1';
      final provider = buildProvider();
      await provider.login('alice@example.com', 'pw');

      await provider.logout();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentUser, isNull);
      expect(tokens.stored, isNull);
      expect(auth.logoutCalls, 1);
    });
  });

  group('registration flow', () {
    test('register success stores pending + returns code', () async {
      auth.registerUserId = 'user-2';
      auth.registerVerificationCode = '123456';
      final provider = buildProvider();

      final code = await provider.register(
        name: 'Bob',
        email: 'bob@example.com',
        password: 'pw',
      );

      expect(code, '123456');
      expect(provider.pendingRegistrationUserId, 'user-2');
      expect(provider.pendingVerificationCode, '123456');
    });

    test('register failure → null + error', () async {
      auth.registerSucceeds = false;
      auth.registerError = 'Email already used';
      final provider = buildProvider();

      final code = await provider.register(
        name: 'Bob',
        email: 'bob@example.com',
        password: 'pw',
      );

      expect(code, isNull);
      expect(provider.error, 'Email already used');
    });

    test('verifyEmail without pending registration → error', () async {
      final provider = buildProvider();

      final ok = await provider.verifyEmail('000000');

      expect(ok, isFalse);
      expect(provider.error, 'No pending registration');
    });

    test('register → verify auto-logs in and creates user', () async {
      auth.registerUserId = 'user-2';
      auth.verifyUserId = 'user-2';
      final provider = buildProvider();

      await provider.register(
        name: 'Bob',
        email: 'bob@example.com',
        password: 'pw',
      );
      final ok = await provider.verifyEmail('123456');

      expect(ok, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser?.id, 'user-2');
      expect(repo.createdUser?.id, 'user-2');
      expect(provider.pendingRegistrationUserId, isNull);
    });
  });

  group('password reset flow', () {
    test('request → returns code and stores pending email', () async {
      auth.resetRequestEmail = 'alice@example.com';
      auth.resetRequestCode = '654321';
      final provider = buildProvider();

      final code = await provider.requestPasswordReset('alice@example.com');

      expect(code, '654321');
      expect(provider.pendingResetEmail, 'alice@example.com');
    });

    test('resetPassword without pending → error', () async {
      final provider = buildProvider();

      final ok = await provider.resetPassword(code: '1', newPassword: 'new');

      expect(ok, isFalse);
      expect(provider.error, 'No password reset in progress');
    });

    test('request → reset clears pending', () async {
      final provider = buildProvider();
      await provider.requestPasswordReset('alice@example.com');

      final ok = await provider.resetPassword(
        code: '654321',
        newPassword: 'newpw',
      );

      expect(ok, isTrue);
      expect(provider.pendingResetEmail, isNull);
    });
  });

  group('account deletion flow', () {
    Future<AuthProvider> loggedIn() async {
      repo.users['user-1'] = userFixture();
      auth.loginUserId = 'user-1';
      final provider = buildProvider();
      await provider.login('alice@example.com', 'pw');
      return provider;
    }

    test('request when logged out → error, null', () async {
      final provider = buildProvider();

      final code = await provider.requestAccountDeletion();

      expect(code, isNull);
      expect(provider.error, 'No user logged in');
    });

    test('request → returns code and stores pending email', () async {
      final provider = await loggedIn();

      final code = await provider.requestAccountDeletion();

      expect(code, '111222');
      expect(provider.pendingDeletionEmail, 'alice@example.com');
    });

    test('confirm → deletes from repo and clears session', () async {
      final provider = await loggedIn();
      await provider.requestAccountDeletion();

      final ok = await provider.confirmAccountDeletion('111222');

      expect(ok, isTrue);
      expect(repo.deleteCalled, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentUser, isNull);
    });
  });

  group('changePassword', () {
    Future<AuthProvider> loggedIn() async {
      repo.users['user-1'] = userFixture();
      auth.loginUserId = 'user-1';
      final provider = buildProvider();
      await provider.login('alice@example.com', 'pw');
      return provider;
    }

    test('not logged in → error', () async {
      final provider = buildProvider();

      final ok = await provider.changePassword(
        currentPassword: 'a',
        newPassword: 'b',
      );

      expect(ok, isFalse);
      expect(provider.error, 'No user logged in');
    });

    test('success → updates repo and refreshes hash', () async {
      final provider = await loggedIn();
      auth.changePasswordSucceeds = true;

      final ok = await provider.changePassword(
        currentPassword: 'old',
        newPassword: 'brandNewPw1',
      );

      expect(ok, isTrue);
      expect(repo.updatedUser, isNotNull);
      expect(
        provider.currentUser?.passwordHash,
        repo.updatedUser?.passwordHash,
      );
      expect(provider.currentUser?.passwordHash, isNot('hash-1'));
    });

    test('wrong current password → error, no update', () async {
      final provider = await loggedIn();
      auth.changePasswordSucceeds = false;

      final ok = await provider.changePassword(
        currentPassword: 'wrong',
        newPassword: 'brandNewPw1',
      );

      expect(ok, isFalse);
      expect(provider.error, 'Current password is incorrect');
    });
  });

  group('setCurrentUser / refreshUser', () {
    test('setCurrentUser replaces identity and notifies once', () async {
      repo.users['user-1'] = userFixture();
      auth.loginUserId = 'user-1';
      final provider = buildProvider();
      await provider.login('alice@example.com', 'pw');

      var notifications = 0;
      provider.addListener(() => notifications++);

      final updated = provider.currentUser!.copyWith(displayName: 'Ali');
      provider.setCurrentUser(updated);

      expect(provider.currentUser?.displayName, 'Ali');
      expect(notifications, 1);
    });

    test('setCurrentUser is a no-op when value is unchanged', () async {
      repo.users['user-1'] = userFixture();
      auth.loginUserId = 'user-1';
      final provider = buildProvider();
      await provider.login('alice@example.com', 'pw');
      final current = provider.currentUser!;

      var notifications = 0;
      provider.addListener(() => notifications++);
      provider.setCurrentUser(current);

      expect(notifications, 0);
    });

    test('refreshUser reloads from repository', () async {
      repo.users['user-1'] = userFixture();
      auth.loginUserId = 'user-1';
      final provider = buildProvider();
      await provider.login('alice@example.com', 'pw');

      // Repository now returns an updated record.
      repo.users['user-1'] = userFixture().copyWith(displayName: 'Renamed');
      await provider.refreshUser();

      expect(provider.currentUser?.displayName, 'Renamed');
    });
  });

  group('getters', () {
    test('userId/isAuthenticated reflect lifecycle', () async {
      repo.users['user-1'] = userFixture();
      auth.loginUserId = 'user-1';
      final provider = buildProvider();

      expect(provider.userId, isNull);
      expect(provider.isAuthenticated, isFalse);

      await provider.login('alice@example.com', 'pw');
      expect(provider.userId, 'user-1');
      expect(provider.isAuthenticated, isTrue);

      await provider.logout();
      expect(provider.userId, isNull);
      expect(provider.isAuthenticated, isFalse);
    });

    test('clearError resets error state', () async {
      final provider = buildProvider();
      await provider.login('   ', 'pw'); // sets an error

      expect(provider.hasError, isTrue);
      provider.clearError();
      expect(provider.hasError, isFalse);
      expect(provider.error, isNull);
    });
  });

  // Keep a direct reference to User so the import is always exercised even if
  // the assertions above change shape.
  test('userFixture builds a valid User', () {
    expect(userFixture(), isA<User>());
  });
}
