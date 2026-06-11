---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [AUTH_OVERVIEW.md](documentation/architecture/AUTH_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](database/DATABASE.md) | [MAIN_AUTH.md](lib/MAIN_AUTH.md) | [Auth Widgets](lib/features/auth/widgets/WIDGETS.md)
---

# Authentication Implementation Roadmap

> **Routing note:** Sprint task lists below mention Navigator-1.0 named routes
> (e.g. "add `/register` route") — these reflect the plan at the time. Routing has
> since migrated to **go_router** (`lib/core/router/app_router.dart`,
> `MaterialApp.router`); the auth gate is now a central `redirect`, not the splash
> screen navigating imperatively. See the updated "Current State" checklist below.

## Current State (as of Sprint 1)

### Completed
- [x] **AuthProvider** - Centralized auth/identity state management with ChangeNotifier (split out of the former `UserProvider`; editable profile data now lives in `ProfileProvider`)
- [x] **Session persistence** - JWT tokens stored securely via `TokenStorage` (flutter_secure_storage) and restored across app restarts
- [x] **Login screen** - Email/password form with validation and error display
- [x] **Splash screen** - Pure loader that calls `AuthProvider.initialize()`; the central go_router redirect routes to login or home once initialized
- [x] **Routing (go_router)** - Route tree + central auth redirect in `lib/core/router/app_router.dart`; `main.dart` uses `MaterialApp.router`. Replaced the original Navigator-1.0 named-routes map (`/`, `/login`, `/home`). Home is a `StatefulShellRoute.indexedStack` (`/home/{community,progress,activity,benefit,profile}`, default Activity)
- [x] **Logout** - ProfileScreen has logout button with confirmation dialog
- [x] **ProxyProvider pattern** - Configured in main.dart for dependent providers
- [x] **ActivityProvider** - Has `updateUserId()` method for dynamic user ID

### Known Issues (Bugs to Fix First)
- [x] **ProgressProvider** - ~~Still hardcoded `'test-user-123'` on line 116~~ → Fixed with dynamic `_userId`
- [x] **ProgressProvider** - ~~Missing `updateUserId()` method~~ → Added method

### Test Credentials (MVP)

**User 1 (Male, Dev):**
- Email: `test@gmail.com`
- Password: `1234`
- User ID: `test-user-123`
- Name: Test Developer

**User 2 (Female, Sarah):**
- Email: `test2@gmail.com`
- Password: `1234`
- User ID: `test-user-321`
- Name: Sarah Runner

---

## Sprint 0: Bug Fixes ✅ COMPLETED
**Effort:** 1-2 hours | **Priority:** Critical

Fixed the incomplete implementation from Sprint 1.

### Tasks
1. **Add `updateUserId()` method to ProgressProvider**
   - Add `String? _userId` field
   - Add `updateUserId(String? newUserId)` method
   - Replace hardcoded `'test-user-123'` with `_userId ?? 'test-user-123'` fallback

2. **Verify ProxyProvider integration**
   - Ensure ProgressProvider reloads activities when userId changes
   - Test login → activities load with correct user
   - Test logout → activities clear

### Files to Modify
- `lib/providers/progress_provider.dart`

### Success Criteria
- No hardcoded user IDs in production code (except fallback)
- ProxyProvider correctly passes userId to ProgressProvider
- Activities load/clear correctly on login/logout

---

## Sprint 1: Backend Authentication Foundation ✅ COMPLETED
**Effort:** 8-12 hours | **Priority:** High

Replaced MVP hardcoded credentials with proper JWT authentication architecture.

### Completed Tasks
1. ✅ **Created Auth Service** (`lib/features/auth/data/auth_service.dart`)
   - Interface + MockAuthService implementation
   - Mock backend simulates real auth flow

2. ✅ **Token Management**
   - `lib/features/auth/data/token_storage.dart` - Secure storage wrapper
   - `lib/features/auth/domain/auth_tokens.dart` - Token model with expiry logic
   - Auto-refresh support via `needsRefresh` getter

3. ✅ **Updated AuthProvider**
   - Now uses AuthService + TokenStorage (no hardcoded credentials)
   - `refreshSession()` method for token refresh
   - `handleAuthFailure()` for interceptor callbacks

4. ✅ **Added Auth Interceptor** (`lib/core/network/auth_interceptor.dart`)
   - Attaches Bearer token to requests
   - Handles 401 responses with auto-refresh
   - Triggers logout on refresh failure

5. ✅ **Added API Client** (`lib/core/network/api_client.dart`)
   - Configured Dio instance with timeouts
   - Debug logging in development mode

### New Files Created
- `lib/features/auth/domain/auth_tokens.dart` - Token model
- `lib/features/auth/domain/auth_result.dart` - Auth result model
- `lib/features/auth/data/auth_service.dart` - Interface + mock
- `lib/features/auth/data/token_storage.dart` - Secure storage
- `lib/core/network/api_client.dart` - Dio HTTP client
- `lib/core/network/auth_interceptor.dart` - Bearer token interceptor

### Unit Tests (72 tests)
- `test/features/auth/domain/auth_tokens_test.dart` - 21 tests
- `test/features/auth/domain/auth_result_test.dart` - 15 tests
- `test/features/auth/data/auth_service_test.dart` - 22 tests
- `test/features/auth/data/token_storage_test.dart` - 14 tests

### Dependencies to Add
```yaml
dependencies:
  dio: ^5.0.0
  flutter_secure_storage: ^9.0.0
```

### Success Criteria
- Login validates against real backend API
- JWT tokens stored securely
- Tokens auto-refresh before expiration
- 401 errors handled gracefully

---

## Sprint 2: User Registration ✅ COMPLETED
**Effort:** 4-6 hours | **Priority:** High

Allows new users to create accounts.

### Tasks
1. **Create Registration Screen**
   - `lib/presentation/screens/auth/register_screen.dart`
   - Form fields: name, email, password, confirm password
   - Password strength indicator
   - Terms & conditions checkbox

2. **Add Registration API**
   - `POST /auth/register` endpoint integration
   - Handle duplicate email errors
   - Email validation (format check)

3. **Email Verification (Optional)**
   - Send verification email after registration
   - Verification screen with code input
   - Resend verification email option

4. **Update Login Screen**
   - Add "Create Account" link to registration screen
   - Add "Forgot Password?" link (placeholder for Sprint 4)

5. **Update Navigation**
   - Add `/register` route
   - Navigation flow: login ↔ register

### New Files
- `lib/presentation/screens/auth/register_screen.dart`
- `lib/presentation/screens/auth/email_verification_screen.dart` (optional)

### Success Criteria
- Users can create new accounts
- Duplicate email handled with clear error message
- Auto-login after successful registration
- Proper navigation between login and register

---

## Sprint 3: Password Recovery ✅ COMPLETED
**Effort:** 3-4 hours | **Priority:** Medium

Allows users to reset forgotten passwords.

### Tasks
1. **Forgot Password Screen**
   - `lib/presentation/screens/auth/forgot_password_screen.dart`
   - Email input form
   - "Check your email" confirmation

2. **Reset Password Screen**
   - `lib/presentation/screens/auth/reset_password_screen.dart`
   - Deep link handling for reset links
   - New password + confirm password form

3. **Backend Integration**
   - `POST /auth/forgot-password` - send reset email
   - `POST /auth/reset-password` - set new password with token

4. **Deep Link Setup**
   - Configure app to handle `benefit://reset-password?token=xxx`
   - Parse token from deep link and navigate to reset screen

### New Files
- `lib/presentation/screens/auth/forgot_password_screen.dart`
- `lib/presentation/screens/auth/reset_password_screen.dart`

### Success Criteria
- Users can request password reset via email
- Reset link opens app directly to reset screen
- Password successfully changed with valid token
- Expired/invalid tokens handled gracefully

---

## Sprint 4: OAuth / Social Login
**Effort:** 6-8 hours | **Priority:** Medium

Add Google and Apple Sign-In for faster onboarding.

### Tasks
1. **Google Sign-In**
   - Add `google_sign_in` package
   - Configure OAuth credentials in Google Cloud Console
   - Handle ID token exchange with backend

2. **Apple Sign-In**
   - Add `sign_in_with_apple` package
   - Configure Apple Developer account
   - Handle authorization code exchange with backend

3. **Update Login Screen**
   - Add "Continue with Google" button
   - Add "Continue with Apple" button (iOS only)
   - Social login buttons above email/password form

4. **Backend Integration**
   - `POST /auth/google` - exchange Google token for app JWT
   - `POST /auth/apple` - exchange Apple token for app JWT

5. **Account Linking**
   - Handle case where social account email already exists
   - Option to link accounts or use different email

### Dependencies to Add
```yaml
dependencies:
  google_sign_in: ^6.0.0
  sign_in_with_apple: ^5.0.0
```

### Platform Configuration
- Android: Add SHA-1 fingerprint to Firebase/Google Cloud
- iOS: Add Sign in with Apple capability
- Both: Configure OAuth redirect URIs

### Success Criteria
- Users can sign in with Google (both platforms)
- Users can sign in with Apple (iOS only)
- Existing accounts detected and handled
- Social auth creates user in backend

---

## Sprint 5: Profile & Account Management 🟡 PARTIAL
**Effort:** 4-6 hours | **Priority:** Low

Enhance profile with account management features. Change Password and Delete
Account are implemented (as dialogs inside `profile_screen.dart`, not as the
separate screens originally planned below); profile editing and session
management remain future work.

### Tasks
1. ✅ **Change Password** (implemented in `profile_screen.dart`)
   - Add "Change Password" option in profile settings
   - Require current password for verification
   - New password with confirmation

2. ✅ **Delete Account** (implemented in `profile_screen.dart`; uses a 6-digit confirmation code, not a password)
   - Add "Delete Account" option
   - Confirmation dialog with warnings
   - Require a 6-digit confirmation code to confirm
   - Backend deletes all user data

3. **Update Profile Information**
   - Allow editing name, email
   - Email change requires verification
   - Profile photo upload

4. **Session Management**
   - Show active sessions/devices
   - "Sign out of all devices" option
   - Remote session termination

### Files to Modify
- `lib/presentation/screens/profile/profile_screen.dart`

### New Files (originally planned)
- ~~`lib/presentation/screens/profile/change_password_screen.dart`~~ → implemented as a dialog in `profile_screen.dart` instead
- ~~`lib/presentation/screens/profile/delete_account_screen.dart`~~ → implemented as a dialog in `profile_screen.dart` instead

### Success Criteria
- Users can change password with current password verification
- Users can delete their account with confirmation
- All user data deleted from backend on account deletion

---

## Sprint 6: Security Hardening 🟡 MOSTLY DONE
**Effort:** 4-6 hours | **Priority:** Medium

Implement security best practices. Biometric auth, client-side rate limiting,
and certificate pinning are implemented; session timeout is intentionally
deferred (stubbed).

### Tasks
1. ✅ **Biometric Authentication** (`lib/features/security/services/biometric_service.dart`, `lib/providers/app_lock_provider.dart`, `lib/presentation/screens/security/app_lock_screen.dart`)
   - Optional fingerprint/Face ID for app unlock
   - Use `local_auth` package
   - Store preference in settings

2. ✅ **Rate Limiting (Client-side)** (`lib/features/security/services/rate_limiter_service.dart`, wired into `AuthProvider.login`)
   - Limit login attempts (5 attempts, then 15-min lockout)
   - Show remaining attempts
   - Countdown timer for lockout

3. ⏳ **Session Timeout** (stubbed — `SessionTimeoutService.isEnabled` returns `false`; deferred for the fitness-tracking use case)
   - Auto-logout after X minutes of inactivity
   - Configurable timeout in settings
   - Warning before timeout

4. ✅ **Certificate Pinning** (`lib/core/network/certificate_pinning.dart`; release-only via `SecurityConfig.enableCertificatePinning`, fingerprints still placeholders)
   - Pin SSL certificates for API calls
   - Prevent MITM attacks

5. **Security Audit**
   - Review all API calls for proper auth
   - Ensure sensitive data encrypted at rest
   - Check for hardcoded secrets

### Dependencies to Add
```yaml
dependencies:
  local_auth: ^2.0.0
```

### Success Criteria
- Biometric unlock available on supported devices
- Rate limiting prevents brute force attacks
- Sessions expire after inactivity (planned — `SessionTimeoutService` is stubbed/not yet implemented)
- API communication secured with certificate pinning

---

## Summary

| Sprint | Description | Effort | Priority | Status |
|--------|-------------|--------|----------|---------------|
| **Sprint 0** | Bug fixes (ProgressProvider) | 1-2 hours | Critical | ✅ Done |
| **Sprint 1** | Backend auth + tokens | 8-12 hours | High | ✅ Done |
| **Sprint 2** | User registration | 4-6 hours | High | ✅ Done |
| **Sprint 3** | Password recovery | 3-4 hours | Medium | ✅ Done |
| **Sprint 4** | OAuth (Google/Apple) | 6-8 hours | Medium | Skipped (MVP) |
| **Sprint 5** | Account management | 4-6 hours | Low | Partial (change password + delete account done) |
| **Sprint 6** | Security hardening | 4-6 hours | Medium | Mostly done (session timeout stubbed) |

**Total Estimated Effort:** 30-44 hours

---

## Recommended Implementation Order

1. **Sprint 0** - Fix bugs first (blocks everything else)
2. **Sprint 1** - Backend auth is foundation for all else
3. **Sprint 2** - Registration needed for real users
4. **Sprint 4** - OAuth improves conversion (do before password recovery)
5. **Sprint 3** - Password recovery less critical if OAuth available
6. **Sprint 6** - Security before launch
7. **Sprint 5** - Account management can wait post-launch
