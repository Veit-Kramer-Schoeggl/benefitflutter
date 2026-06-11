---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [AUTH_OVERVIEW.md](../../documentation/architecture/AUTH_OVERVIEW.md) - High-level concepts
>
> **Related:** [AUTH.md](../../AUTH.md) | [PROVIDER_GUIDE.md](../presentation/PROVIDER_GUIDE.md)
---

# Authentication Provider Implementation Plan

> **Status (implemented, split in Phase 1 / Round 2):** This plan has been carried out,
> significantly extended, and then **split into two providers**. The former monolithic
> `UserProvider` (`lib/providers/user_provider.dart`, now removed) has been divided into:
> - **`AuthProvider`** (`lib/providers/auth_provider.dart`) — identity & sessions: the
>   current `User`, `userId`, tokens, `isAuthenticated`, plus all auth/account flows
>   (login, logout, session refresh, register, email verification, password reset,
>   account deletion, `changePassword`, rate limiting). It is the **single source of
>   identity truth** and exposes `setCurrentUser(User)` / `refreshUser()` so the profile
>   layer can sync edits back. Registered **first** in `MultiProvider` (`lib/main.dart`).
> - **`ProfileProvider`** (`lib/providers/profile_provider.dart`) — editable profile data
>   (profile fields via `updateUser`, biometrics, preferences). Wired as
>   `ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>`; it writes to the
>   `UserRepository` first (durable) and then calls `AuthProvider.setCurrentUser(...)`.
>
> `ProgressProvider`, `ActivityProvider`, and `BenefitProvider` now consume **`AuthProvider`**
> via `ChangeNotifierProxyProvider<AuthProvider, …>`/`updateUserId(authProvider.userId)`.
> Real authentication is implemented on top of `AuthService`/`TokenStorage`, going well beyond
> the original test-user scope below. The code examples in this document are the original PLAN
> drafts (which used a single `UserProvider`) and do not match the final API exactly — read
> them as historical design context; the shipped API is `AuthProvider` + `ProfileProvider`.

## Problem Statement
The original problem this plan addressed: the app used hardcoded user IDs scattered across
multiple files:
- `ActivityProvider`: `'test-user-123'`
- `BenefitScreen`: `'test-user-123'`
- `ProgressProvider`: `'test-user-123'`
- No centralized user state management
- Not reactive to user changes
- Violates MVVM/Provider pattern principles

These hardcoded IDs have since been removed from the providers; `'test-user-123'` now only
appears in seed/test data (`lib/core/seed/seed_data.dart`, `MockAuthService` test credentials).

## Solution Architecture

### Core Principle: Single Source of Truth
Create a **UserProvider** (or AuthProvider) that serves as the centralized state manager for the current authenticated user.

---

## Phase 1: Create User Provider Infrastructure

### 1.1 Create `UserProvider` class
**Location:** `lib/providers/user_provider.dart`

**Responsibilities:**
- Hold current user state
- Manage authentication state (logged in/out)
- Provide reactive userId to all consumers
- Load user from persistence on app start
- Update user data

**Key Properties:**
```dart
class UserProvider extends ChangeNotifier {
  User? _currentUser;           // Current authenticated user
  bool _isAuthenticated = false; // Auth state
  bool _isLoading = true;        // Loading state

  // Getters
  User? get currentUser => _currentUser;
  String? get userId => _currentUser?.id;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  // Methods
  Future<void> initialize();     // Load user from storage
  Future<void> login(String email, String password);
  Future<void> logout();
  Future<void> updateUser(User user);
}
```

> **Implementation note:** In the shipped `AuthProvider` (formerly `UserProvider`),
> `isAuthenticated` is a computed getter (`_currentUser != null && _currentTokens != null`),
> not a stored `_isAuthenticated` field, and `_isLoading` defaults to `false`. The constructor
> takes injected dependencies —
> `AuthProvider({required UserRepository repository, required AuthService authService,
> required TokenStorage tokenStorage, RateLimiterService? rateLimiter})` — and the implemented
> `login`/`logout`/`refreshSession` return `Future<bool>`/`Future<void>` rather than the
> signatures sketched above.

### 1.2 Add to Provider hierarchy
**Location:** `lib/main.dart`

**Strategy:** UserProvider must be **at the top** of the provider tree since other providers depend on it.

```dart
MultiProvider(
  providers: [
    // 1. UserProvider FIRST (no dependencies)
    ChangeNotifierProvider(
      create: (_) => UserProvider()..initialize(),
    ),

    // 2. Providers that need userId use ProxyProvider
    ChangeNotifierProxyProvider<UserProvider, ProgressProvider>(
      create: (_) => ProgressProvider(...),
      update: (_, userProvider, progressProvider) {
        progressProvider?.updateUserId(userProvider.userId);
        return progressProvider ?? ProgressProvider(...);
      },
    ),

    // Similar for other providers...
  ],
)
```

> **Implementation note:** The shipped `MultiProvider` (`lib/main.dart`) registers
> `AuthProvider` first with injected dependencies (no `..initialize()` chained in `create`),
> then `ProfileProvider` (as `ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>`),
> followed by `BenefitProvider`, `ProgressProvider`, `ActivityProvider` (all via
> `ChangeNotifierProxyProvider<AuthProvider, …>` calling `updateUserId(authProvider.userId)`),
> plus plain `ChangeNotifierProvider`s for `ConnectivityProvider`, `HealthPlatformProvider`,
> and `AppLockProvider`.

---

## Phase 2: Refactor Existing Providers

### 2.1 Update `ProgressProvider`
**Changes:**
- Remove hardcoded `'test-user-123'`
- Add `_userId` field
- Add `updateUserId()` method
- Use `_userId` in queries

```dart
class ProgressProvider extends ChangeNotifier {
  String? _userId;

  void updateUserId(String? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      if (_userId != null) {
        loadActivities(); // Reload with new userId
      }
    }
  }

  Future<void> loadActivities() async {
    if (_userId == null) return; // Guard clause

    final dbSessions = await _sessionRepository.getAllSessions(
      userId: _userId!, // Use dynamic userId
    );
    // ...
  }
}
```

### 2.2 Update `ActivityProvider`
**Same pattern:**
```dart
class ActivityProvider extends ChangeNotifier {
  String? _userId;

  void updateUserId(String? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      // Reset state if needed
    }
  }

  Future<void> startSession() async {
    if (_userId == null) throw Exception('No user logged in');

    final session = Session(
      userId: _userId!, // Use dynamic userId
      // ...
    );
  }
}
```

### 2.3 Update `BenefitScreen`
**Changes:**
- Remove hardcoded userId
- Get userId from context

```dart
class BenefitScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get userId from UserProvider
    final userId = context.watch<UserProvider>().userId;

    if (userId == null) {
      return Center(child: Text('Please log in'));
    }

    // Use userId in queries...
  }
}
```

---

## Phase 3: Implementation Steps

### Step 1: Create User Domain Model (if not exists)
**File:** `lib/features/user/domain/user.dart`

Check if this already exists or needs updates:
```dart
class User {
  final String id;
  final String email;
  final String name;
  // other fields...
}
```

### Step 2: Create UserProvider
**File:** `lib/providers/user_provider.dart`

**Implementation priority:**
1. Basic structure with hardcoded test user (for now)
2. Add persistence (SharedPreferences or database)
3. Add real authentication later

**Initial Implementation:**
```dart
class UserProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = true;

  // Getters
  User? get currentUser => _currentUser;
  String? get userId => _currentUser?.id;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  // Initialize with test user for now
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Load from SharedPreferences or database
      // For now, use test user
      _currentUser = User(
        id: 'test-user-123',
        email: 'test@example.com',
        name: 'Test User',
      );

      debugPrint('UserProvider: Initialized with user ${_currentUser?.id}');
    } catch (e) {
      debugPrint('UserProvider: Error initializing - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
    // Clear from storage
  }
}
```

### Step 3: Update main.dart Provider Tree
**Order matters!**

```dart
MultiProvider(
  providers: [
    // 1. UserProvider (no dependencies)
    ChangeNotifierProvider(
      create: (_) => UserProvider()..initialize(),
    ),

    // 2. BenefitProvider (no user dependency yet)
    ChangeNotifierProvider(
      create: (_) => BenefitProvider(
        RepositoryConfig.getBenefitRepository(),
      ),
    ),

    // 3. ProgressProvider (needs userId)
    ChangeNotifierProxyProvider<UserProvider, ProgressProvider>(
      create: (context) => ProgressProvider(
        RepositoryConfig.getSessionRepository(),
      )..updateUserId(context.read<UserProvider>().userId),
      update: (context, userProvider, progressProvider) {
        progressProvider?.updateUserId(userProvider.userId);
        return progressProvider!;
      },
    ),

    // 4. ConnectivityProvider (no user dependency)
    ChangeNotifierProvider(
      create: (_) => ConnectivityProvider(
        ConnectivityService(),
      ),
    ),

    // 5. ActivityProvider (needs userId)
    ChangeNotifierProxyProvider<UserProvider, ActivityProvider>(
      create: (context) => ActivityProvider(
        RepositoryConfig.getSessionRepository(),
        sensorManager: sensorManager,
      )..updateUserId(context.read<UserProvider>().userId),
      update: (context, userProvider, activityProvider) {
        activityProvider?.updateUserId(userProvider.userId);
        return activityProvider!;
      },
    ),
  ],
  child: const BeneFitApp(),
)
```

### Step 4: Refactor Individual Providers
For each provider that uses userId:

1. Add `String? _userId` field
2. Add `updateUserId(String? newUserId)` method
3. Replace hardcoded userId with `_userId!`
4. Add null checks before operations

### Step 5: Update Screens
Any screen that directly uses userId:

```dart
// Before:
static const String _userId = 'test-user-123';

// After:
final userId = context.watch<UserProvider>().userId;
if (userId == null) return LoadingOrLoginWidget();
```

---

## Phase 4: Testing Strategy

### 4.1 Test User Provider
- [ ] Initialize with test user
- [ ] Check userId is available
- [ ] Check isAuthenticated state
- [ ] Test logout clears user

### 4.2 Test Provider Updates
- [ ] ProgressProvider receives userId on init
- [ ] ProgressProvider reloads data when userId changes
- [ ] ActivityProvider can create sessions with dynamic userId
- [ ] BenefitScreen displays correct user data

### 4.3 Test User Switching
- [ ] Logout clears all data
- [ ] Login with different user loads different data
- [ ] Providers react to user changes

---

## Phase 5: Future Enhancements

### 5.1 Real Authentication — IMPLEMENTED
- Integrate with UserRepository ✅ (`AuthProvider`/`ProfileProvider` wrap `UserRepository`)
- Add login/register methods ✅ (`login`, `register`, `verifyEmail`, plus password reset /
  account deletion / change password)
- Add token management ✅ (`AuthTokens` + `TokenStorage`/`SecureTokenStorage`,
  `refreshSession`, `AuthInterceptor` for 401 refresh)
- Add auto-login from stored credentials ✅ (`initialize()` restores the session from
  `TokenStorage` and refreshes expired tokens)
- Note: the live app uses `MockAuthService`; PostgREST/remote sync is still TODO.

### 5.2 Auth Guards — PARTIALLY IMPLEMENTED
- Protect screens that require authentication (routing via named routes in `main.dart`)
- Redirect to login if not authenticated ✅ (the `SplashScreen`
  (`lib/presentation/screens/splash/splash_screen.dart` ~44-45) navigates to `/login` after
  `authProvider.initialize()` when not authenticated). Note: the only `navigatorKey` → `/login`
  navigation in the live app is the app-lock flow `_handlePasswordRequired()` in `main.dart`,
  not an auth-failure flow; `AuthProvider.handleAuthFailure()` exists but is **not** currently
  called anywhere.
- Handle token expiration ⚠️ (`AuthInterceptor` implements refresh-on-401 with a `needsRefresh`
  5-min window, but it is **not** wired into the live app — it is never instantiated/registered,
  so this is currently dead code)

### 5.3 Multi-user Support
- Switch between users (providers reset state via `updateUserId` on user change)
- Maintain separate data per user
- Clear cache on logout (each ProxyProvider clears its state when `userId` becomes null)

---

## File Structure

```
lib/
├── providers/
│   ├── user_provider.dart           # NEW: Central user state
│   ├── progress_provider.dart       # UPDATE: Use dynamic userId
│   ├── activity_provider.dart       # UPDATE: Use dynamic userId
│   ├── benefit_provider.dart        # UPDATE: Use dynamic userId (if needed)
│   └── connectivity_provider.dart   # No changes needed
├── features/
│   └── user/
│       ├── domain/
│       │   └── user.dart            # CHECK: Ensure exists
│       └── data/
│           └── user_repository.dart # EXISTS: Already implemented
└── main.dart                        # UPDATE: Provider tree order
```

---

## Migration Checklist

### Preparation
- [ ] Check if User domain model exists and is complete
- [ ] Review UserRepository implementation
- [ ] Document all locations with hardcoded userId

### Implementation
- [ ] Create UserProvider with test user
- [ ] Update main.dart provider tree
- [ ] Add `updateUserId()` to ProgressProvider
- [ ] Add `updateUserId()` to ActivityProvider
- [ ] Update BenefitScreen to use context userId
- [ ] Update ProfileScreen to use context userId (if applicable)

### Testing
- [ ] Test app initialization
- [ ] Test Progress screen loads sessions
- [ ] Test Activity screen creates sessions
- [ ] Test user logout clears data
- [ ] Test all screens with null user (not logged in)

### Cleanup
- [ ] Remove all hardcoded userId constants
- [ ] Add documentation comments
- [ ] Update any TODO comments related to auth

---

## Benefits of This Approach

✅ **Single Source of Truth:** One place for user state
✅ **Reactive:** Providers automatically update when user changes
✅ **Testable:** Easy to mock UserProvider for testing
✅ **Scalable:** Easy to add real authentication later
✅ **Type-safe:** Compile-time checks for userId availability
✅ **MVVM Compliant:** Proper separation of concerns

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing functionality | High | Test thoroughly after each provider update |
| ProxyProvider complexity | Medium | Use clear naming and documentation |
| Null userId edge cases | Medium | Add guard clauses and null checks |
| Provider initialization order | High | Document dependencies clearly |

---

## Timeline Estimate

- **Phase 1 (Infrastructure):** 1-2 hours
- **Phase 2 (Provider Refactoring):** 2-3 hours
- **Phase 3 (Testing):** 1-2 hours
- **Phase 4 (Documentation):** 1 hour

**Total: 5-8 hours**

---

## Next Steps

1. Review this plan and approve approach
2. Start with Phase 1: Create UserProvider
3. Test with minimal changes first
4. Progressively refactor each provider
5. Add real authentication in future iteration
