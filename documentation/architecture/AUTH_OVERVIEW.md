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

### UserProvider
Central state management for authentication:
- Manages current user state
- Handles login/logout operations
- Persists session across app restarts
- Propagates user ID to dependent providers

### Token Management
Secure storage and automatic refresh:
- Access tokens for API requests
- Refresh tokens for session renewal
- Automatic token refresh on expiry
- Secure storage using platform-specific mechanisms

### Auth Interceptor
HTTP request handling:
- Attaches Bearer tokens to requests
- Handles 401 unauthorized responses
- Triggers automatic token refresh
- Redirects to login on auth failure

## Security Features

| Feature | Description |
|---------|-------------|
| **Password Hashing** | SHA-256 hashing, never stored as plain text |
| **Token-Based Auth** | JWT tokens with configurable expiry |
| **Secure Storage** | Platform-specific secure credential storage |
| **Auto-Logout** | Session expires after inactivity period |

## Implementation Status

### Completed
- User registration and login
- Password hashing and validation
- Session persistence
- Token storage infrastructure
- Logout with confirmation

### Planned
- Email verification
- Password reset flow
- OAuth integration (Google, Apple)
- Biometric authentication

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Main Routing | [MAIN_AUTH.md](../../lib/MAIN_AUTH.md) | [MAIN_AUTH_OVERVIEW](./MAIN_AUTH_OVERVIEW.md) |
| Auth Widgets | [WIDGETS.md](../../lib/features/auth/widgets/WIDGETS.md) | [AUTH_WIDGETS_OVERVIEW](../widgets/AUTH_WIDGETS_OVERVIEW.md) |
| Database Schema | [DATABASE.md](../../database/DATABASE.md) | [DATABASE_OVERVIEW](../data/DATABASE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
