# Security Implementation

> **Documentation Type:** TECHNICAL (Implementation Details)
>
> **Related:** [AUTH.md](../../../AUTH.md) | [SecurityConfig](../../../core/config/security_config.dart)

## Sprint 6: Security Hardening

### Implemented Features

1. **Rate Limiting (Client-Side)**
   - 5 login attempts allowed
   - 15-minute lockout after max attempts
   - Persists across app restarts
   - Files: `rate_limiter_service.dart`, `rate_limit_storage.dart`

2. **Biometric Authentication**
   - Optional fingerprint/Face ID for app unlock
   - 2-minute lock delay after backgrounding
   - Skips lock during active tracking sessions
   - Files: `biometric_service.dart`, `security_preferences.dart`, `app_lock_provider.dart`

3. **Certificate Pinning**
   - Pins SSL certificates for API calls
   - Prevents MITM attacks
   - Disabled in debug mode for development
   - Files: `certificate_pinning.dart`, `api_client.dart`

4. **Session Timeout** (TODO)
   - Placeholder created
   - Deferred to avoid interrupting activity tracking
   - File: `session_timeout_service.dart`

---

## Security Audit Results

### API Authentication
- [x] Bearer token attached to all API requests via `auth_interceptor.dart`
- [x] 401 responses handled with automatic token refresh
- [x] Auth endpoints excluded from auth requirement

### Data Encryption
- [x] Auth tokens stored via `flutter_secure_storage`
  - Android: EncryptedSharedPreferences
  - iOS: Keychain with first_unlock_this_device accessibility
- [x] Rate limit state stored securely
- [x] Biometric preferences stored securely

### Password Security
- [x] Passwords hashed with SHA-256 before storage
- [x] Plain-text passwords never stored
- [x] Password validation enforces minimum requirements:
  - 8+ characters
  - 1 uppercase letter
  - 1 lowercase letter
  - 1 number

### Hardcoded Values Review
| Item | Location | Status | Notes |
|------|----------|--------|-------|
| API Base URL | `security_config.dart` | Fixed | Moved to centralized config |
| Test Credentials | `auth_service.dart`, `seed_data.dart` | Acceptable | Mock service for development |
| Certificate Fingerprints | `certificate_pinning.dart` | Placeholder | Replace before production |

### Debug Logging
- [x] All sensitive data logging uses `debugPrint()` which is compiled out in release
- [x] Token values not logged directly
- [x] Verification codes only logged in debug mode

---

## Production Checklist

Before deploying to production:

- [ ] Replace mock `AuthService` with real backend implementation
- [ ] Update certificate fingerprints in `certificate_pinning.dart`
- [ ] Remove test credential hints from `login_screen.dart`
- [ ] Consider upgrading password hashing to bcrypt/Argon2 on backend
- [ ] Enable session timeout after continuous tracking is finalized
- [ ] Review and remove any remaining `debugPrint` statements containing sensitive data

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
│   └── session_timeout_service.dart  # TODO: Session timeout (placeholder)
└── SECURITY.md                       # This file

lib/core/config/
└── security_config.dart              # Centralized security configuration

lib/core/network/
└── certificate_pinning.dart          # SSL certificate pinning

lib/providers/
└── app_lock_provider.dart            # App lock state management

lib/presentation/screens/security/
└── app_lock_screen.dart              # Biometric unlock screen
```

---

## Configuration

All security settings are centralized in `lib/core/config/security_config.dart`:

```dart
SecurityConfig.maxLoginAttempts        // 5 attempts
SecurityConfig.lockoutDuration         // 15 minutes
SecurityConfig.biometricLockDelay      // 2 minutes
SecurityConfig.maxBiometricAttempts    // 3 attempts
SecurityConfig.enableCertificatePinning // true in release, false in debug
SecurityConfig.sessionTimeout          // 30 minutes (TODO)
```
