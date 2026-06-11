import 'package:flutter_test/flutter_test.dart';
import '../../../mocks/mock_flutter_secure_storage.dart';
import 'package:benefitflutter/features/security/services/rate_limiter_service.dart';
import 'package:benefitflutter/features/security/data/rate_limit_storage.dart';
import 'package:benefitflutter/core/config/security_config.dart';

void main() {
  late MockFlutterSecureStorage mockStorage;
  late RateLimitStorage rateLimitStorage;
  late RateLimiterService rateLimiter;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    rateLimitStorage = RateLimitStorage(storage: mockStorage);
    rateLimiter = RateLimiterService(storage: rateLimitStorage);
  });

  group('RateLimiterService', () {
    group('canAttempt', () {
      test('returns true when no attempts made', () async {
        final result = await rateLimiter.canAttempt();
        expect(result, isTrue);
      });

      test('returns true when under max attempts', () async {
        // Record 4 failed attempts (max is 5)
        for (var i = 0; i < 4; i++) {
          await rateLimiter.recordFailedAttempt();
        }

        final result = await rateLimiter.canAttempt();
        expect(result, isTrue);
      });

      test('returns false when max attempts reached', () async {
        // Record 5 failed attempts (triggers lockout)
        for (var i = 0; i < SecurityConfig.maxLoginAttempts; i++) {
          await rateLimiter.recordFailedAttempt();
        }

        final result = await rateLimiter.canAttempt();
        expect(result, isFalse);
      });
    });

    group('recordFailedAttempt', () {
      test('increments attempt counter', () async {
        await rateLimiter.recordFailedAttempt();
        final remaining = await rateLimiter.getRemainingAttempts();

        expect(remaining, equals(SecurityConfig.maxLoginAttempts - 1));
      });

      test('triggers lockout after max attempts', () async {
        for (var i = 0; i < SecurityConfig.maxLoginAttempts; i++) {
          await rateLimiter.recordFailedAttempt();
        }

        final isLocked = await rateLimiter.isLockedOut();
        expect(isLocked, isTrue);
      });
    });

    group('getRemainingAttempts', () {
      test('returns max attempts when no failures', () async {
        final remaining = await rateLimiter.getRemainingAttempts();
        expect(remaining, equals(SecurityConfig.maxLoginAttempts));
      });

      test('returns correct remaining after failures', () async {
        await rateLimiter.recordFailedAttempt();
        await rateLimiter.recordFailedAttempt();

        final remaining = await rateLimiter.getRemainingAttempts();
        expect(remaining, equals(SecurityConfig.maxLoginAttempts - 2));
      });

      test('returns 0 when locked out', () async {
        for (var i = 0; i < SecurityConfig.maxLoginAttempts; i++) {
          await rateLimiter.recordFailedAttempt();
        }

        final remaining = await rateLimiter.getRemainingAttempts();
        expect(remaining, equals(0));
      });
    });

    group('resetOnSuccess', () {
      test('clears all attempt data', () async {
        // Record some failures
        for (var i = 0; i < 3; i++) {
          await rateLimiter.recordFailedAttempt();
        }

        // Reset on success
        await rateLimiter.resetOnSuccess();

        // Should have full attempts available
        final remaining = await rateLimiter.getRemainingAttempts();
        expect(remaining, equals(SecurityConfig.maxLoginAttempts));
      });

      test('clears lockout', () async {
        // Trigger lockout
        for (var i = 0; i < SecurityConfig.maxLoginAttempts; i++) {
          await rateLimiter.recordFailedAttempt();
        }
        expect(await rateLimiter.isLockedOut(), isTrue);

        // Reset on success
        await rateLimiter.resetOnSuccess();

        // Should no longer be locked
        expect(await rateLimiter.isLockedOut(), isFalse);
        expect(await rateLimiter.canAttempt(), isTrue);
      });
    });

    group('getLockoutRemaining', () {
      test('returns zero duration when not locked', () async {
        final remaining = await rateLimiter.getLockoutRemaining();
        expect(remaining, equals(Duration.zero));
      });

      test('returns positive duration when locked', () async {
        for (var i = 0; i < SecurityConfig.maxLoginAttempts; i++) {
          await rateLimiter.recordFailedAttempt();
        }

        final remaining = await rateLimiter.getLockoutRemaining();
        expect(remaining.inMinutes, greaterThan(0));
        expect(remaining.inMinutes, lessThanOrEqualTo(15));
      });
    });

    group('isLockedOut', () {
      test('returns false when no attempts', () async {
        expect(await rateLimiter.isLockedOut(), isFalse);
      });

      test('returns false when under limit', () async {
        for (var i = 0; i < SecurityConfig.maxLoginAttempts - 1; i++) {
          await rateLimiter.recordFailedAttempt();
        }
        expect(await rateLimiter.isLockedOut(), isFalse);
      });

      test('returns true when max attempts reached', () async {
        for (var i = 0; i < SecurityConfig.maxLoginAttempts; i++) {
          await rateLimiter.recordFailedAttempt();
        }
        expect(await rateLimiter.isLockedOut(), isTrue);
      });
    });
  });

  group('RateLimitState', () {
    test('isLockedOut returns true when lockoutEnd is in future', () {
      final state = RateLimitState(
        attemptCount: 5,
        windowStart: DateTime.now(),
        lockoutEnd: DateTime.now().add(const Duration(minutes: 10)),
      );

      expect(state.isLockedOut, isTrue);
    });

    test('isLockedOut returns false when lockoutEnd is in past', () {
      final state = RateLimitState(
        attemptCount: 5,
        windowStart: DateTime.now(),
        lockoutEnd: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(state.isLockedOut, isFalse);
    });

    test('isLockedOut returns false when lockoutEnd is null', () {
      const state = RateLimitState(
        attemptCount: 3,
        windowStart: null,
        lockoutEnd: null,
      );

      expect(state.isLockedOut, isFalse);
    });

    test('remainingLockout returns positive duration when locked', () {
      final lockoutEnd = DateTime.now().add(const Duration(minutes: 10));
      final state = RateLimitState(
        attemptCount: 5,
        windowStart: DateTime.now(),
        lockoutEnd: lockoutEnd,
      );

      expect(state.remainingLockout.inMinutes, greaterThan(0));
    });

    test('remainingLockout returns zero when not locked', () {
      const state = RateLimitState(
        attemptCount: 3,
        windowStart: null,
        lockoutEnd: null,
      );

      expect(state.remainingLockout, equals(Duration.zero));
    });

    test('copyWith creates new instance with updated values', () {
      const original = RateLimitState(
        attemptCount: 3,
        windowStart: null,
        lockoutEnd: null,
      );

      final updated = original.copyWith(attemptCount: 5);

      expect(updated.attemptCount, equals(5));
      expect(original.attemptCount, equals(3)); // Original unchanged
    });
  });
}
