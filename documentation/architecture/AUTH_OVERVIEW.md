---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [AUTH.md](../../AUTH.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [MAIN_AUTH Overview](./MAIN_AUTH_OVERVIEW.md)
---

# Authentication System Overview

## Purpose

The BeneFit authentication system provides user login, registration, session management, and password handling. It is built as a **JWT-shaped architecture prepared for backend integration** — the shipped app has no networked backend: `MockAuthService` issues mock tokens and validates credentials against the local SQLite user store.

## Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Authentication Flow                       │
│                                                              │
│   App Start                                                  │
│      │                                                       │
│      ▼                                                       │
│   Splash Screen                                              │
│      │                                                       │
│      ├── Check stored session ──► Found? ──► Home Screen    │
│      │                              │                        │
│      │                              No                       │
│      │                              │                        │
│      └──────────────────────────────┴──► Login Screen       │
│                                              │               │
│                                              ▼               │
│                                         Enter credentials    │
│                                              │               │
│                                              ▼               │
│                                         Validate + Login     │
│                                              │               │
│                                              ▼               │
│                                         Store tokens         │
│                                              │               │
│                                              ▼               │
│                                         Home Screen          │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### AuthProvider
Central state management for authentication and identity (the single source of identity truth):
- Manages current user state and `userId`
- Handles login/logout operations and all auth/account flows
- Persists session across app restarts
- Propagates user ID to dependent providers

> Editable profile data (name/biometrics/preferences) is owned by a separate `ProfileProvider`, which
> persists changes to the repository and then calls `AuthProvider.setCurrentUser(...)` to sync the
> in-memory identity. (`AuthProvider` + `ProfileProvider` replaced the former monolithic `UserProvider`.)

### Token Management
Secure storage and (limited) automatic refresh:
- Access tokens for API requests — mock format `mock::{type}::{userId}::{random}`
  (`MockAuthService._generateMockToken`, lib/features/auth/data/auth_service.dart:201-208)
- Refresh tokens for session renewal, 1-hour default expiry (`MockAuthService.tokenExpiry`,
  auth_service.dart:170)
- Automatic token refresh **on app start only** — `AuthProvider.initialize()` refreshes expired tokens
  during session restore (lib/providers/auth_provider.dart:136-156). In-session refresh is implemented
  but unreachable: `AuthProvider.refreshSession()` (auth_provider.dart:351) has no call site, and the
  5-minute `AuthTokens.needsRefresh` window (lib/features/auth/domain/auth_tokens.dart:20-21) is read
  only by the unwired `AuthInterceptor` — see the note below
- Secure storage using platform-specific mechanisms (`SecureTokenStorage`, single `auth_tokens` key,
  iOS `first_unlock_this_device`, lib/features/auth/data/token_storage.dart:28-50)

### Auth Interceptor
HTTP request handling (forward-looking infrastructure for a networked backend):
- Attaches Bearer tokens to requests
- Handles 401 unauthorized responses
- Triggers automatic token refresh
- Redirects to login on auth failure

> **Note:** `AuthInterceptor` exists under `core/network/` but is **not yet wired**
> into the live app — it is not instantiated or attached to `ApiClient`. The
> shipped app authenticates via `MockAuthService`, which validates credentials
> against the durable SQLite user store (`UserRepository` → `UserDao.findByEmail`
> + `PasswordUtils`), so registrations/password changes survive restarts.

## Security Features

| Feature | Description |
|---------|-------------|
| **Password Hashing** | SHA-256 hex digest via `PasswordUtils.hashPassword` (lib/core/utils/password_utils.dart:9-13); never stored as plain text. **Known limitation:** unsalted and single-round — acceptable for the local mock backend, must become server-side bcrypt/Argon2 before a real backend goes live |
| **Password Policy** | Min. 8 characters, ≥1 uppercase, ≥1 lowercase, ≥1 digit (`PasswordValidator`, lib/features/auth/utils/password_validator.dart:14-47). Enforced on registration, password reset and change-password — **not** on login, which is why the seeded `1234` test accounts still sign in |
| **Token-Based Auth** | Mock JWT-style tokens with a 1-hour expiry; `isExpired` / `needsRefresh` (5-min pre-expiry) on `AuthTokens` |
| **Secure Storage** | `flutter_secure_storage` 10.0.0 — Android Keystore-backed, iOS Keychain `first_unlock_this_device` (token_storage.dart:37-44, rate_limit_storage.dart:21-28) |
| **Rate Limiting** | Login lockout after 5 failed attempts within a 15-minute rolling window, 15-minute lockout, persisted across restarts (`SecurityConfig` lines 29/37/45, `RateLimiterService`, `RateLimitStorage`) |
| **Biometric App-Lock** | Biometric unlock after 2 minutes backgrounded (Face ID / Fingerprint / Iris) — `SecurityConfig.biometricLockDelay` (security_config.dart:61), `BiometricService`, `AppLockProvider`, wired in lib/main.dart |
| **Certificate Pinning** | SHA-256 pinning for `api.benefit.app` / `dev-api.benefit.app`, release-only via `SecurityConfig.enableCertificatePinning` (lib/core/network/certificate_pinning.dart:31-42). ⚠️ **Inert today:** the fingerprints are still `PLACEHOLDER_*` constants and `ApiClient` is never instantiated |

## Implementation Status

> Verified against branch `feat/phase-2-background-tracking` on 2026-08-28.

### Completed
- User registration and login
- Email verification (verification code, auto-login on success)
- Password reset flow (request code + reset, deep-link support)
- Password hashing and validation
- Session persistence
- Change password for the logged-in user (current-password verification + DB hash update,
  `AuthProvider.changePassword`, lib/providers/auth_provider.dart:829-876)
- Profile editing (display name, gender, email with a mock verification dialog, profile photo)
  via `ProfileProvider.updateUser`
- Token storage infrastructure
- Logout with confirmation
- Rate limiting (login lockout) and biometric app-lock
- Account deletion (request + confirm with code)

### Planned / not yet built
- OAuth integration (Google, Apple) — **not started**
- Session inactivity timeout — **stub**: `SessionTimeoutService.isEnabled` returns `false` (line 96) and
  every method is a placeholder — four `debugPrint`-only stubs plus an empty `dispose`
  (lib/features/security/services/session_timeout_service.dart:92-125)
- In-session token refresh — **not wired**: `AuthInterceptor` and `ApiClient` are never instantiated,
  so `refreshSession()` / `needsRefresh` have no live caller
- Certificate pinning against a real host — **inert**: placeholder fingerprints, no `ApiClient` instance
- Terms & conditions consent checkbox on registration — **not implemented**
- Resend verification code — **not implemented** (the user must restart registration)
- Session management UI (active devices, "sign out everywhere") — **not implemented**

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Main Routing | [MAIN_AUTH.md](../../lib/MAIN_AUTH.md) | [MAIN_AUTH_OVERVIEW](./MAIN_AUTH_OVERVIEW.md) |
| Auth Widgets | [WIDGETS.md](../../lib/features/auth/widgets/WIDGETS.md) | [AUTH_WIDGETS_OVERVIEW](../widgets/AUTH_WIDGETS_OVERVIEW.md) |
| Database Schema | [DATABASE.md](../../database/DATABASE.md) | [DATABASE_OVERVIEW](../data/DATABASE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
