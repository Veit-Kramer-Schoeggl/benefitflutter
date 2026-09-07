# Security Implementation

> **Documentation Type:** TECHNICAL (Implementation Details)
>
> **Related:** [AUTH.md](../../../AUTH.md) | [SecurityConfig](../../core/config/security_config.dart)
>
> **Status as of:** 2026-08-28 · **Branch:** `feat/phase-2-background-tracking` · every claim below re-verified against the code.

## Sprint 6: Security Hardening

### Implemented Features

1. **Rate Limiting (Client-Side)**
   - 5 login attempts allowed
   - 15-minute lockout after max attempts
   - Persists across app restarts
   - Rolling 15-minute attempt window: attempts older than `SecurityConfig.attemptWindowDuration`
     stop counting and the stored state is cleared (`rate_limiter_service.dart:35-38, 146-158`).
     Four failures followed by >15 minutes of idling therefore restore all 5 attempts.
   - Wired into `AuthProvider.login` (`auth_provider.dart:207-216, 242-252, 286`) and surfaced
     by the login screen countdown (`login_screen.dart:48-71, 105-112`)
   - Files: `rate_limiter_service.dart`, `rate_limit_storage.dart`

2. **Biometric Authentication / App Lock**
   - Optional fingerprint/Face ID for app unlock; `AppLockScreen` overlays every route via the
     `MaterialApp.router` builder (`main.dart:299-308`)
   - 2-minute lock delay after backgrounding (`app_lock_provider.dart:93-107`)
   - Also locks at cold start when the last successful unlock is older than the same 2-minute
     delay (`app_lock_provider.dart:193-215`, called from a post-frame callback in `main.dart:221-223`)
   - Skips lock while a session is tracking **or paused** (`main.dart:270`, `app_lock_provider.dart:75-78`)
   - After 3 failed biometric attempts (`SecurityConfig.maxBiometricAttempts`) or a
     `PermanentlyLockedOut` platform error (`biometric_service.dart:180-181`), the overlay falls
     back to `onPasswordRequired` — which performs a **full logout** and routes to `/login`
     (`app_lock_provider.dart:136-141, 149-152`, `main.dart:281-289`). This is a sign-out, not the
     in-place "re-login with password" that `SecurityConfig`'s own comment implies.
   - **Known gap:** locking is gated on `isBiometricEnabled()` only. The separate `appLockEnabled`
     preference (`security_preferences.dart:60-68`) is written by `BiometricService`
     (`biometric_service.dart:219, 237-243`) but **never read** by `AppLockProvider` — a standalone
     "App Lock" settings toggle would have no effect today.
   - Files: `biometric_service.dart`, `security_preferences.dart`, `app_lock_provider.dart`, `app_lock_screen.dart`

3. **Certificate Pinning** — **built, not yet wired**
   - Fail-closed SHA-256 fingerprint validation (`certificate_pinning.dart:55-91`), installed by
     `ApiClient` when `SecurityConfig.enableCertificatePinning` is true (`api_client.dart:48-53`)
   - **Not active today:** `ApiClient` is never constructed anywhere in `lib/`, and
     `_pinnedFingerprints` still holds two `PLACEHOLDER_...` strings (`certificate_pinning.dart:31-36`).
     No request the app makes is pinned, because the app makes no HTTP requests at all.
   - Disabled in debug by default; overridable with `--dart-define CERT_PINNING`
   - Files: `certificate_pinning.dart`, `api_client.dart`

4. **Session Timeout** — **Stub**
   - `SessionTimeoutService.isEnabled` returns `false` (`session_timeout_service.dart:96`);
     `recordActivity` / `startMonitoring` / `stopMonitoring` / `extendSession` only
     `debugPrint('... NOT IMPLEMENTED')` (`:99-120`) and `dispose()` is empty (`:123-125`)
   - The class has **zero call sites** anywhere in `lib/`; `SecurityConfig.sessionTimeout` (30 min)
     and `sessionTimeoutWarning` (5 min) are defined but never read
   - Deferred to avoid interrupting activity tracking
   - File: `session_timeout_service.dart`

---

## Security Audit Results

### API Authentication

> **Status: designed, not wired.** `main.dart:126-129` wires `SecureTokenStorage` +
> `MockAuthService`; no networking code runs in the app. `AuthInterceptor` and `ApiClient` have
> zero call sites outside their own files, and `package:dio` is imported only by
> `api_client.dart` and `auth_interceptor.dart`. Re-audit these boxes when `RealAuthService` lands.

- [~] Bearer token attachment implemented in `auth_interceptor.dart:60-64` (never executed)
- [~] 401 → refresh + retry implemented in `auth_interceptor.dart:74-106` (never executed)
- [~] Auth endpoints excluded via the `excludedPaths` default `['/auth/login', '/auth/register']`
  (`auth_interceptor.dart:30`) — note that `/auth/refresh` is **not** in that list

### Data Encryption
- [x] Auth tokens stored via `flutter_secure_storage`
  - Android: custom AES ciphers (flutter_secure_storage 10/11). The deprecated
    `encryptedSharedPreferences` flag has been removed from `AndroidOptions`; the
    plugin auto-migrates existing data to the custom cipher implementation.
  - iOS: Keychain with first_unlock_this_device accessibility
- [x] Rate limit state stored securely (`rate_limit_storage.dart`)
- [x] Biometric preferences stored securely (`security_preferences.dart`)

### Password Security
- [x] Passwords hashed with SHA-256 before storage (`PasswordUtils.hashPassword`)
- [x] Plain-text passwords never stored
- [x] Authentication verifies against the durable SQLite users table:
  `MockAuthService` (when given a `UserRepository`) looks up the user via
  `UserRepository.getUserByEmail` (→ `UserDao.findByEmail`, `email = ? COLLATE
  NOCASE`) and checks the candidate with `PasswordUtils.verifyPassword`. Password
  changes, resets, and registrations are written to the DB, so they survive a
  process restart.
- [x] Password validation enforces minimum requirements:
  - 8+ characters
  - 1 uppercase letter
  - 1 lowercase letter
  - 1 number

### Hardcoded Values Review
| Item | Location | Status | Notes |
|------|----------|--------|-------|
| API Base URL | `app_config.dart` | Configurable | `SecurityConfig.apiBaseUrl` delegates to `AppConfig.apiBaseUrl`, read from `--dart-define API_BASE_URL` (see `config/dev.json`, `config/staging.json`, `config/prod.example.json`); falls back to dev/prod by build mode |
| Test Credentials | `auth_service.dart`, `seed_data.dart` | Acceptable | In-memory fallback in mock service for development; DB-backed auth is used in production |
| Certificate Fingerprints | `certificate_pinning.dart` | Placeholder | Replace before production |

### Logging
- [x] App-wide logging goes through `AppLogger` (`lib/core/logging/app_logger.dart`, 121 call
  sites in `lib/`, initialised in `main.dart:35`): release builds use `ProductionFilter` +
  `Level.warning`, so debug/info messages are dropped (`app_logger.dart:26-33`)
- [x] Every message passes through `AppLogger.redact()`, which strips emails, bearer tokens,
  `password|secret|token|api_key|dsn|authorization` key/value pairs and coordinates with 5+
  decimals (`app_logger.dart:54-75`)
- [x] Token values not logged directly (no log statement in `lib/` interpolates an access or
  refresh token)
- [x] Verification, reset and deletion codes are never logged in any build mode —
  `auth_provider.dart:752` logs `'Password reset requested (reset code issued)'` without the
  value. Codes reach the UI only through the `_MockCodeHint` dev box
  (`verification_code_field.dart:218-245`).
- [ ] 58 raw `debugPrint()` calls remain in 16 files (incl. `biometric_service.dart`,
  `certificate_pinning.dart`, `session_timeout_service.dart`, `gps_sensor.dart`).
  **`debugPrint` is _not_ stripped in release builds** — migrate these to `AppLogger`.

### Static Analysis Gates
- [x] `strict-casts: true` enabled in `analysis_options.yaml`
- [x] CI runs `dart analyze --fatal-infos lib` (infos fail the build) plus a
  `dart format` check, tests, and a debug APK build (`.github/workflows/ci.yml`)
- Current state (2026-08-28): `dart analyze --fatal-infos lib` clean · 823 tests passing ·
  `flutter build apk --debug` succeeds · **the `dart format --set-exit-if-changed` gate is RED**
  (3 files introduced by the WP3/WP5 commits) — run `dart format .` before merging.

---

## Production Checklist

Before deploying to production:

- [ ] Replace mock `AuthService` with real backend implementation
- [ ] Update certificate fingerprints in `certificate_pinning.dart`
- [x] Test credential hints gated behind `kDebugMode` (`login_screen.dart:513`) — the seeded test
  accounts only exist when seeding runs (`AppConfig.seedEnabled`)
- [ ] Consider upgrading password hashing to bcrypt/Argon2 on backend
- [ ] Enable session timeout after continuous tracking is finalized
- [ ] Migrate the remaining 58 `debugPrint` calls (16 files) to `AppLogger` — `debugPrint` is not
  stripped in release builds and bypasses `AppLogger.redact()`
- [ ] Gate or remove the `_MockCodeHint` box: `showMockCodeHint: true` is passed
  **unconditionally** (not behind `kDebugMode`) in `profile_screen.dart:1262`,
  `reset_password_screen.dart:238` and `email_verification_screen.dart:123`. Harmless while codes
  come from `MockAuthService`, but it must not survive a real verification backend.

---

## File Structure

```
lib/features/security/
├── data/
│   ├── rate_limit_storage.dart    # Persistent storage for rate limiting
│   └── security_preferences.dart  # Biometric/app lock preferences
├── services/
│   ├── rate_limiter_service.dart     # Login attempt rate limiting
│   ├── biometric_service.dart        # Biometric authentication wrapper
│   └── session_timeout_service.dart  # Stub: session timeout (no call sites)
└── SECURITY.md                       # This file

lib/core/config/
├── app_config.dart                   # Build-time defines (API_BASE_URL, CERT_PINNING,
│                                     #   SEED_ENABLED, HTTP_LOGGING, SENTRY_DSN)
└── security_config.dart              # Centralized security configuration

lib/core/logging/
└── app_logger.dart                   # Release-filtered, redacting logger

lib/core/network/
├── certificate_pinning.dart          # SSL certificate pinning (placeholder fingerprints)
├── api_client.dart                   # Dio wrapper — NOT instantiated anywhere
└── auth_interceptor.dart             # Bearer/refresh interceptor — NOT instantiated anywhere

lib/providers/
└── app_lock_provider.dart            # App lock state management

lib/presentation/screens/security/
└── app_lock_screen.dart              # Biometric unlock screen

config/
├── dev.json                          # --dart-define-from-file inputs
├── staging.json
└── prod.example.json
```

---

## Configuration

Most security settings live in `lib/core/config/security_config.dart`. The two
deployment-dependent ones delegate to `lib/core/config/app_config.dart`, which reads
`--dart-define-from-file` (see `config/dev.json`, `config/staging.json`, `config/prod.example.json`).

```dart
SecurityConfig.maxLoginAttempts         // 5 attempts
SecurityConfig.lockoutDuration          // 15 minutes
SecurityConfig.attemptWindowDuration    // 15 minutes rolling window
SecurityConfig.enableRateLimiting       // true
SecurityConfig.biometricLockDelay       // 2 minutes
SecurityConfig.maxBiometricAttempts     // 3 attempts
SecurityConfig.enableBiometricAuth      // true
SecurityConfig.sessionTimeout           // 30 minutes (stub — defined but never read)
SecurityConfig.sessionTimeoutWarning    // 5 minutes  (stub — defined but never read)
SecurityConfig.apiBaseUrl               // → AppConfig.apiBaseUrl (API_BASE_URL define)
SecurityConfig.enableCertificatePinning // → AppConfig (CERT_PINNING define; default !kDebugMode)
```
