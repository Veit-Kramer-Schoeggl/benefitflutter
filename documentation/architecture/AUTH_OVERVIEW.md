---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [AUTH.md](../../AUTH.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [MAIN_AUTH Overview](./MAIN_AUTH_OVERVIEW.md)
---

# Authentication System Overview

## Purpose

The BeneFit authentication system provides secure user login, registration, session management, and password handling. It's built with a JWT-based architecture ready for backend integration.

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
Secure storage and automatic refresh:
- Access tokens for API requests
- Refresh tokens for session renewal
- Automatic token refresh on expiry
- Secure storage using platform-specific mechanisms

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
| **Password Hashing** | SHA-256 hashing, never stored as plain text |
| **Token-Based Auth** | JWT tokens with configurable expiry |
| **Secure Storage** | Platform-specific secure credential storage |
| **Rate Limiting** | Login lockout after 5 failed attempts within a 15-minute window |
| **Biometric App-Lock** | Biometric unlock after backgrounding (Face ID / Fingerprint / Iris) |

## Implementation Status

### Completed
- User registration and login
- Email verification (verification code, auto-login on success)
- Password reset flow (request code + reset, deep-link support)
- Password hashing and validation
- Session persistence
- Token storage infrastructure
- Logout with confirmation
- Rate limiting (login lockout) and biometric app-lock
- Account deletion (request + confirm with code)

### Planned
- OAuth integration (Google, Apple)
- Session inactivity timeout (`SessionTimeoutService` is currently a stub / not implemented)

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Main Routing | [MAIN_AUTH.md](../../lib/MAIN_AUTH.md) | [MAIN_AUTH_OVERVIEW](./MAIN_AUTH_OVERVIEW.md) |
| Auth Widgets | [WIDGETS.md](../../lib/features/auth/widgets/WIDGETS.md) | [AUTH_WIDGETS_OVERVIEW](../widgets/AUTH_WIDGETS_OVERVIEW.md) |
| Database Schema | [DATABASE.md](../../database/DATABASE.md) | [DATABASE_OVERVIEW](../data/DATABASE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
