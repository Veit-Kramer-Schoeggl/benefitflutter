import 'package:benefitflutter/core/utils/password_utils.dart';
import 'package:benefitflutter/features/auth/data/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';

/// DB-backed MockAuthService: when a UserRepository is injected, auth and
/// password mutations go through the durable store instead of in-memory maps.
/// The [FakeUserRepository] models the durable DB; constructing a NEW
/// MockAuthService over the SAME repo models a process restart (the auth
/// service is recreated each app launch, the DB survives).
void main() {
  late FakeUserRepository repo;

  MockAuthService build() => MockAuthService(
    minDelay: Duration.zero,
    maxDelay: Duration.zero,
    userRepository: repo,
  );

  setUp(() {
    repo = FakeUserRepository();
    repo.users['test-user-123'] = userFixture(
      id: 'test-user-123',
      email: 'test@gmail.com',
      passwordHash: PasswordUtils.hashPassword('1234'),
    );
  });

  group('DB-backed login', () {
    test('succeeds with the password stored in the repository', () async {
      final r = await build().login('test@gmail.com', '1234');

      expect(r.success, isTrue);
      expect(r.userId, 'test-user-123');
      expect(r.tokens, isNotNull);
    });

    test('matches email case-insensitively', () async {
      final r = await build().login('TEST@GMAIL.COM', '1234');
      expect(r.success, isTrue);
    });

    test('fails with the wrong password', () async {
      final r = await build().login('test@gmail.com', 'wrong');
      expect(r.success, isFalse);
      expect(r.error, 'Invalid password');
    });

    test('fails for an unknown email', () async {
      final r = await build().login('ghost@gmail.com', '1234');
      expect(r.success, isFalse);
      expect(r.error, contains('No account'));
    });
  });

  group('changePassword durability (the reported bug)', () {
    test(
      'new password works after a simulated restart; old password rejected',
      () async {
        final ok = await build().changePassword(
          userId: 'test-user-123',
          email: 'test@gmail.com',
          currentPassword: '1234',
          newPassword: 'NewPass99',
        );
        expect(ok, isTrue);

        // The durable repository now holds the new hash.
        expect(
          PasswordUtils.verifyPassword(
            'NewPass99',
            repo.users['test-user-123']!.passwordHash,
          ),
          isTrue,
        );

        // Simulate a process restart: brand-new auth service, same durable repo.
        final authB = build();
        expect(
          (await authB.login('test@gmail.com', 'NewPass99')).success,
          isTrue,
        );

        final old = await authB.login('test@gmail.com', '1234');
        expect(old.success, isFalse);
        expect(old.error, 'Invalid password');
      },
    );

    test('wrong current password leaves the stored hash unchanged', () async {
      final ok = await build().changePassword(
        userId: 'test-user-123',
        email: 'test@gmail.com',
        currentPassword: 'wrong',
        newPassword: 'NewPass99',
      );

      expect(ok, isFalse);
      expect(
        PasswordUtils.verifyPassword(
          '1234',
          repo.users['test-user-123']!.passwordHash,
        ),
        isTrue,
      );
    });
  });

  group('resetPassword durability', () {
    test(
      'persists the new password to the repository across restart',
      () async {
        final authA = build();
        final req = await authA.requestPasswordReset('test@gmail.com');
        expect(req.success, isTrue);

        final reset = await authA.resetPassword(
          email: 'test@gmail.com',
          code: req.resetCode!,
          newPassword: 'Reset123',
        );
        expect(reset.success, isTrue);

        final authB = build(); // restart
        expect(
          (await authB.login('test@gmail.com', 'Reset123')).success,
          isTrue,
        );
        expect((await authB.login('test@gmail.com', '1234')).success, isFalse);
      },
    );
  });

  group('account-existence guards use the repository', () {
    test('requestPasswordReset fails for an unknown email', () async {
      final r = await build().requestPasswordReset('ghost@gmail.com');
      expect(r.success, isFalse);
    });

    test('register rejects an email already present in the DB', () async {
      final r = await build().register(
        name: 'X',
        email: 'test@gmail.com',
        password: 'pw',
      );
      expect(r.success, isFalse);
      expect(r.error, contains('already exists'));
    });

    test(
      'checkEmailAvailability: false for existing, true for fresh',
      () async {
        expect(await build().checkEmailAvailability('test@gmail.com'), isFalse);
        expect(await build().checkEmailAvailability('fresh@gmail.com'), isTrue);
      },
    );
  });
}
