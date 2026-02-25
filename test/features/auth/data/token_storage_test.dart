import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:benefitflutter/features/auth/data/token_storage.dart';
import 'package:benefitflutter/features/auth/domain/auth_tokens.dart';

/// Mock implementation of FlutterSecureStorage for testing
class MockFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(_storage);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage.containsKey(key);
  }

  @override
  IOSOptions get iOptions => const IOSOptions();

  @override
  AndroidOptions get aOptions => const AndroidOptions();

  @override
  LinuxOptions get lOptions => const LinuxOptions();

  @override
  WebOptions get webOptions => const WebOptions();

  @override
  MacOsOptions get mOptions => const MacOsOptions();

  @override
  WindowsOptions get wOptions => const WindowsOptions();

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => true;

  @override
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged => null;

  @override
  void registerListener({
    required String key,
    required void Function(String?) listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required void Function(String?) listener,
  }) {}

  @override
  void unregisterAllListenersForKey({required String key}) {}

  @override
  void unregisterAllListeners() {}

  // Helper for tests
  void clear() => _storage.clear();

  // Helper to inject invalid JSON for error testing
  void setRawValue(String key, String value) => _storage[key] = value;
}

void main() {
  group('SecureTokenStorage', () {
    late MockFlutterSecureStorage mockStorage;
    late SecureTokenStorage tokenStorage;
    late AuthTokens testTokens;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      tokenStorage = SecureTokenStorage(storage: mockStorage);
      testTokens = AuthTokens(
        accessToken: 'test-access-token-12345',
        refreshToken: 'test-refresh-token-67890',
        expiresAt: DateTime(2025, 6, 15, 12, 0, 0),
      );
    });

    group('saveTokens', () {
      test('stores tokens as JSON', () async {
        await tokenStorage.saveTokens(testTokens);

        final stored = await mockStorage.read(key: 'auth_tokens');
        expect(stored, isNotNull);

        final decoded = jsonDecode(stored!) as Map<String, dynamic>;
        expect(decoded['accessToken'], equals(testTokens.accessToken));
        expect(decoded['refreshToken'], equals(testTokens.refreshToken));
      });

      test('overwrites existing tokens', () async {
        await tokenStorage.saveTokens(testTokens);

        final newTokens = AuthTokens(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
          expiresAt: DateTime(2026, 1, 1),
        );
        await tokenStorage.saveTokens(newTokens);

        final retrieved = await tokenStorage.getTokens();
        expect(retrieved?.accessToken, equals('new-access-token'));
      });
    });

    group('getTokens', () {
      test('returns null when no tokens stored', () async {
        final tokens = await tokenStorage.getTokens();
        expect(tokens, isNull);
      });

      test('returns stored tokens', () async {
        await tokenStorage.saveTokens(testTokens);

        final retrieved = await tokenStorage.getTokens();

        expect(retrieved, isNotNull);
        expect(retrieved!.accessToken, equals(testTokens.accessToken));
        expect(retrieved.refreshToken, equals(testTokens.refreshToken));
        expect(retrieved.expiresAt, equals(testTokens.expiresAt));
      });

      test('returns null and clears storage on invalid JSON', () async {
        mockStorage.setRawValue('auth_tokens', 'not valid json');

        final tokens = await tokenStorage.getTokens();

        expect(tokens, isNull);
        // Storage should be cleared after error
        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isFalse);
      });

      test('returns null for empty string', () async {
        mockStorage.setRawValue('auth_tokens', '');

        final tokens = await tokenStorage.getTokens();
        expect(tokens, isNull);
      });
    });

    group('clearTokens', () {
      test('removes stored tokens', () async {
        await tokenStorage.saveTokens(testTokens);
        expect(await tokenStorage.hasTokens(), isTrue);

        await tokenStorage.clearTokens();

        expect(await tokenStorage.hasTokens(), isFalse);
        expect(await tokenStorage.getTokens(), isNull);
      });

      test('does not throw when no tokens exist', () async {
        expect(() => tokenStorage.clearTokens(), returnsNormally);
      });
    });

    group('hasTokens', () {
      test('returns false when no tokens stored', () async {
        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isFalse);
      });

      test('returns true when tokens are stored', () async {
        await tokenStorage.saveTokens(testTokens);

        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isTrue);
      });

      test('returns false after clearing tokens', () async {
        await tokenStorage.saveTokens(testTokens);
        await tokenStorage.clearTokens();

        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isFalse);
      });

      test('returns false for empty string value', () async {
        mockStorage.setRawValue('auth_tokens', '');

        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isFalse);
      });
    });

    group('getAccessToken', () {
      test('returns null when no tokens stored', () async {
        final accessToken = await tokenStorage.getAccessToken();
        expect(accessToken, isNull);
      });

      test('returns access token when tokens are stored', () async {
        await tokenStorage.saveTokens(testTokens);

        final accessToken = await tokenStorage.getAccessToken();
        expect(accessToken, equals(testTokens.accessToken));
      });
    });

    group('round-trip', () {
      test('preserves all token data through save and retrieve', () async {
        final originalTokens = AuthTokens(
          accessToken: 'access-with-special-chars-!@#\$%',
          refreshToken: 'refresh-with-unicode-émojis-🎉',
          expiresAt: DateTime(2025, 12, 31, 23, 59, 59),
        );

        await tokenStorage.saveTokens(originalTokens);
        final retrieved = await tokenStorage.getTokens();

        expect(retrieved, isNotNull);
        expect(retrieved!.accessToken, equals(originalTokens.accessToken));
        expect(retrieved.refreshToken, equals(originalTokens.refreshToken));
        expect(retrieved.expiresAt, equals(originalTokens.expiresAt));
      });
    });
  });
}
