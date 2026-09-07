---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [MAIN_AUTH_OVERVIEW.md](../documentation/architecture/MAIN_AUTH_OVERVIEW.md) - High-level concepts
>
> **Related:** [AUTH.md](../AUTH.md) | [PROVIDER_GUIDE.md](presentation/PROVIDER_GUIDE.md)
>
> **Stand:** 2026-08-28 — verified against `lib/main.dart`, `lib/core/router/app_router.dart`,
> `lib/core/deep_link/deep_link_handler.dart`, `lib/presentation/screens/splash/splash_screen.dart`
> (go_router 17.3.0).
---

# Main.dart Authentication & Routing Architecture

This document explains how the main.dart routing setup works and how authentication is integrated.

> **Routing note:** the app migrated from Navigator 1.0 to **go_router 17.3.0** in Phase 1 / Round 3.
> The route tree, the central auth redirect and `rootNavigatorKey` now live in
> **`lib/core/router/app_router.dart`**; `main.dart` only builds the router and renders
> `MaterialApp.router`. Screens navigate with `context.go`/`context.push` — no named routes
> (18 `context.go`/`context.push` call sites in `lib/`, zero `pushNamed`/`pushReplacementNamed`).
> A global `rootNavigatorKey` still exists (`app_router.dart:28`), but only as go_router's root
> `navigatorKey`, as `parentNavigatorKey` for the full-screen pushes, and to pop lingering dialogs
> on forced logout (`main.dart:287`); it is no longer used for navigation.

> **Provider note (Phase 1 / Round 2):** Authentication state lives in **`AuthProvider`**
> (`lib/providers/auth_provider.dart`), which replaced the former monolithic `UserProvider`.
> A sibling **`ProfileProvider`** (`lib/providers/profile_provider.dart`) owns editable
> profile data and is **not** involved in the auth gate below — it is wired as
> `ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>` and syncs profile edits back
> into `AuthProvider` via `setCurrentUser(...)`. Everything in this document concerns the
> auth/session flow, which is `AuthProvider`'s responsibility.

## How the Auth Gate Works (Step by Step)

### Conceptual Overview

Think of it like a **decision tree**:
1. App starts → Shows Splash Screen
2. Splash calls `AuthProvider.initialize()`; the router's central `redirect` then checks: "Is user authenticated?"
3. **If YES** → redirect to `/home/activity` (Activity tab of the 5-tab shell — there is no bare `/home` route)
4. **If NO** → Navigate to `/login` (login screen)
5. After successful login → `/home/activity`

Authentication is fully implemented: the splash screen triggers the session
restore via `AuthProvider.initialize()` and the redirect routes accordingly. A
separate runtime **app-lock overlay** (biometric/password) can re-gate the app
after it returns from the background.

---

### The Components

#### 1. main.dart - The Entry Point

`void main()` is synchronous. It installs the global error handlers inside a
`runZonedGuarded` and delegates all async work to the public `bootstrap()` seam
(public so `integration_test/` can boot the real app without main()'s zone,
which would clash with the test binding):

```
main()                                        (main.dart:30)
  └─> runZonedGuarded(
       ├─> WidgetsFlutterBinding.ensureInitialized()
       ├─> AppLogger.init()
       ├─> FlutterError.onError / platformDispatcher.onError / ErrorWidget.builder
       └─> AppConfig.sentryDsn.isEmpty
             ? await bootstrap()
             : SentryFlutter.init(..., appRunner: bootstrap)   // opt-in via --dart-define
     )

bootstrap() async                             (main.dart:103)
  ├─> if (SeedConfig.isEnabled) SeedService.create(userRepository:, sessionRepository:,
  │      benefitRepository:) → seedIfNeeded()      (failures logged via AppLogger.e, non-fatal)
  ├─> SensorManager().initialize()
  ├─> tokenStorage = SecureTokenStorage()
  ├─> authService  = MockAuthService(userRepository: RepositoryConfig.getUserRepository())
  │      // durable SQLite user store, so registrations/password changes survive a restart
  ├─> authProvider = AuthProvider(repository:, authService:, tokenStorage:)
  │      // built here, NOT in MultiProvider, so router + deep links share the instance
  ├─> router = createAppRouter(authProvider)
  ├─> DeepLinkHandler(router: router, authProvider: authProvider).initialize()
  └─> runApp(MultiProvider(providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),   // FIRST
        ProfileProvider, BenefitProvider, ProgressProvider, ConnectivityProvider,
        ActivityProvider, HealthPlatformProvider, AppLockProvider,
      ], child: BeneFitApp(router: router)))
```

**Boot stages.** `main()` (`main.dart:30`) installs `AppLogger`,
`FlutterError.onError`, `binding.platformDispatcher.onError` and a release-safe
`ErrorWidget.builder`, then runs `bootstrap()` either directly or as
`SentryFlutter.init(appRunner: bootstrap)` when `AppConfig.sentryDsn` is
non-empty (opt-in via `--dart-define=SENTRY_DSN=…`; `sendDefaultPii = false`,
`tracesSampleRate = 0.0`, breadcrumb messages redacted by `_scrubSentryEvent`).
Boot-time work therefore belongs in `bootstrap()`, not in `main()`.

`BeneFitApp` is a `StatefulWidget` that **requires** the `GoRouter`; its state
mixes in `WidgetsBindingObserver`:

```
BeneFitApp(router: router)                    (main.dart:206)
  └─> _BeneFitAppState with WidgetsBindingObserver
      ├─> initState: addObserver + postFrame AppLockProvider.initialize()
      ├─> didChangeAppLifecycleState:
      │     paused/inactive → AppLockProvider.onAppPaused() + ActivityProvider.flushPendingGps()
      │     resumed        → ActivityProvider.retryGpsIfNeeded() + AppLockProvider.onAppResumed(...)
      ├─> _handlePasswordRequired: logout + AppLockProvider.reset() +
      │     rootNavigatorKey.currentState?.popUntil(isFirst) + router.go('/login')
      └─> build: MaterialApp.router
          ├─> routerConfig: widget.router      (route tree in core/router/app_router.dart)
          ├─> theme: AppTheme.lightTheme
          └─> builder: Consumer<AppLockProvider> → AppLockScreen when isLocked, else child
```

**Lifecycle hooks in detail** (`main.dart:233-279`):
- `paused` / `inactive` → `AppLockProvider.onAppPaused()` plus
  `ActivityProvider.flushPendingGps()` when a session is running or paused
  (`_flushGpsOnBackground`, `main.dart:254-259`), so an OS kill does not drop
  buffered GPS points.
- `resumed` → `_handleAppResumed` (`main.dart:261-279`) returns early if the
  user is not authenticated, calls `retryGpsIfNeeded()` while tracking (the user
  may have just granted the permission in system settings), and passes
  `isTrackingActive:` into `AppLockProvider.onAppResumed(...)` so the lock never
  interrupts an active session.

**What happens:** go_router starts at `initialLocation: '/splash'` and builds
`SplashScreen`; the central `redirect` then decides where the user actually
lands.

---

#### 2. SplashScreen - A Pure Loader

```
SplashScreen                       (presentation/screens/splash/splash_screen.dart)
  └─> initState()
      └─> addPostFrameCallback(() => context.read<AuthProvider>().initialize())
  └─> build() → brand-green Scaffold: logo, 'BeneFit', 'Move More, Save More',
                CircularProgressIndicator, static status text 'Loading...'
```

The splash performs **no navigation**. `_status` is a `final String`
(`splash_screen.dart:18`) and never changes — there is no `setState` in the
file. `AuthProvider.initialize()` is idempotent (`if (_isInitialized) return;`),
flips `isInitialized` and calls `notifyListeners()`; because the router was built
with `refreshListenable: authProvider`, the central `redirect` re-runs and moves
the user to `/home/activity` or `/login`.

---

#### 3. The Route Tree (go_router)

Declared in `lib/core/router/app_router.dart` by `createAppRouter(AuthProvider)`:

- `initialLocation: '/splash'`, `navigatorKey: rootNavigatorKey`,
  `refreshListenable: authProvider`, `redirect: _redirect`, and an `errorBuilder`
  that logs `Router: unknown route <uri>` and renders `SplashScreen`.
- Root-navigator routes: `/splash`, `/login`, `/register`, `/verify`,
  `/forgot-password`, `/reset-password` — the last builds
  `ResetPasswordScreen(token: (state.extra as String?) ?? state.uri.queryParameters['token'])`.
- `StatefulShellRoute.indexedStack` with five branches, each with its own
  navigator key so per-tab stacks survive switching: `/home/community` (0),
  `/home/progress` (1), `/home/activity` (2, default), `/home/benefit` (3),
  `/home/profile` (4). The shell builder renders
  `MainNavigationScreen(navigationShell: …)`.
- Full-screen pushes pinned with `parentNavigatorKey: rootNavigatorKey` so they
  cover the bottom bar: `/session/:id` (id from `state.pathParameters`),
  `/device-connection`, `/device-pairing`, `/benefit-qr` (`extra` is a
  `BenefitViewModel?` — null after a process restart, and the screen handles that).

**Redirect order** (`_redirect`, `app_router.dart:71-101`):
1. `customSchemeRedirect(state.uri)` — rewrites raw
   `benefit://reset-password?token=…` to `/reset-password?token=…`; any other
   `benefit://` host → `/splash`; non-custom schemes fall through.
2. `!auth.isInitialized` → hold on `/splash`.
3. On `/splash` once initialized → `/home/activity` or `/login`.
4. Unauthenticated outside `_authArea` (`/login`, `/register`, `/verify`,
   `/forgot-password`, `/reset-password`) → `/login`.
5. Authenticated on `/login` → `/home/activity`. `/verify` and `/reset-password`
   are deliberately **not** bounced — a just-verified user is briefly
   authenticated while still on those screens.

---

### File Structure

```
lib/
├── main.dart                              # Entry point, bootstrap(), error handlers,
│                                          #   provider tree, MaterialApp.router
├── core/
│   ├── router/
│   │   └── app_router.dart                # go_router tree, central redirect, rootNavigatorKey
│   └── deep_link/
│       └── deep_link_handler.dart         # benefit:// links → router.go (buffers cold start)
├── presentation/
│   ├── screens/
│   │   ├── splash/
│   │   │   └── splash_screen.dart         # Pure loading screen; triggers AuthProvider.initialize()
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── email_verification_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── reset_password_screen.dart
│   │   ├── security/
│   │   │   └── app_lock_screen.dart       # Lock overlay (biometric/password)
│   │   ├── session/                       # /session/:id (root-navigator push)
│   │   ├── wearable/                      # /device-connection, /device-pairing
│   │   └── ...                            # activity, benefit, community, profile, progress, ...
│   └── navigation/
│       └── main_navigation.dart           # 5-tab shell driven by StatefulNavigationShell
├── providers/                             # AuthProvider, ProfileProvider, AppLockProvider, ...
└── features/auth/data/
    ├── auth_service.dart                  # AuthService / MockAuthService
    └── token_storage.dart                 # SecureTokenStorage (FlutterSecureStorage)
```

---

### The Flow in Practice

#### Returning (already-authenticated) user:

```
User opens app
  ↓
SplashScreen shows ('Loading...') and fires AuthProvider.initialize()
  ↓
AuthProvider.initialize() restores stored tokens from SecureTokenStorage
  ↓
authProvider.isAuthenticated == true
  ↓
notifyListeners() → refreshListenable fires → redirect re-runs
  ↓
redirect → /home/activity
  ↓
MainNavigationScreen appears (5 tabs, Activity selected)
```

#### New / logged-out user:

```
User opens app
  ↓
SplashScreen shows ('Loading...') and fires AuthProvider.initialize()
  ↓
AuthProvider.initialize() finds no valid stored session
  ↓
authProvider.isAuthenticated == false
  ↓
redirect → /login
  ↓
User enters credentials → authProvider.login(email, password)
  ↓
Login successful → tokens saved to SecureTokenStorage
  ↓
LoginScreen calls context.go('/home/activity')
  (the redirect would also bounce an authenticated user off /login)
```

Token persistence uses **`SecureTokenStorage`** (Flutter Secure Storage), not
`SharedPreferences`. Tokens are stored as a single JSON blob under the key
`auth_tokens`. At startup, `AuthProvider.initialize()` refreshes expired access
tokens via `AuthService.refreshToken(...)`; on a refresh failure it clears the
stored tokens and nulls the current user, so `isAuthenticated` becomes `false`
and the central redirect subsequently routes `/splash` → `/login`
(`app_router.dart:85-86`). (An `AuthInterceptor` exists under `core/network/` as
infrastructure for a future networked `AuthService` — **Status: not wired.** It is
never imported or instantiated anywhere else in `lib/` and is not attached to
`ApiClient`.)

---

### Adding a New Route

1. Add a `GoRoute` in `lib/core/router/app_router.dart`. Full-screen screens that
   must cover the bottom bar need `parentNavigatorKey: rootNavigatorKey`; a screen
   that belongs inside a tab goes into that branch's `routes:` list.
2. If it must be reachable while logged out, add its path to `_authArea`
   (`app_router.dart:37-43`) — otherwise the redirect bounces it to `/login`.
3. Navigate with `context.push('/my-route')` (pushes onto the stack) or
   `context.go('/my-route')` (replaces the location).
4. Pass data by path parameter — `/session/:id` read via
   `state.pathParameters['id']!` — or, for objects, via `extra`; `extra` does not
   survive a process restart, so the builder must tolerate `null` (see
   `/benefit-qr`).

---

### The Auth Check Implementation

The auth check is declarative. `SplashScreen` only kicks off the restore:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) context.read<AuthProvider>().initialize();
  });
}
```

`AuthProvider.initialize()` (`auth_provider.dart:121`) reads stored tokens from
`SecureTokenStorage`, refreshes them when `tokens.isExpired`, restores the user
via `_extractUserIdFromToken` + `repository.getUserById`, and always ends with
`_isInitialized = true; notifyListeners();` in its `finally`. The router's
`refreshListenable: authProvider` turns that notification into a re-run of
`_redirect`, which then leaves `/splash`.

---

### Deep Links

Two paths lead to `/reset-password`, and both are needed:

- **Warm links** (app already running): `DeepLinkHandler._navigate` calls
  `router.go('/reset-password', extra: token)`
  (`deep_link_handler.dart:91`), keeping the token out of the URL history.
- **Cold-start links**: the platform hands go_router the raw
  `benefit://reset-password?token=…` URI, which matches no route. Step 1 of the
  redirect, `customSchemeRedirect` (`app_router.dart:54-66`), rewrites it to
  `/reset-password?token=…` (the token is re-encoded via the `Uri` constructor);
  a token-less link becomes `/reset-password`, any other `benefit://` host
  becomes `/splash`. Without this the app hits `errorBuilder` and sticks on
  splash — the exact bug behind smoke finding F5. Covered by
  `test/unit/router/deep_link_redirect_test.dart` (7 cases).

`DeepLinkHandler` additionally buffers a link received before
`AuthProvider.isInitialized` and replays it once the session restore finishes
(`deep_link_handler.dart:64-77`), so the boot redirect cannot discard the target.

---

### Error Handling

Errors are contained inside `AuthProvider.initialize()`, not in the splash
screen — the splash has no try/catch and no fallback navigation. On a
token-refresh failure `initialize()` clears storage, nulls user and tokens, sets
`_isInitialized = true` and returns (`auth_provider.dart:136-153`); on any other
exception the outer `catch` logs via `AppLogger.e` and nulls state while the
`finally` still sets `_isInitialized = true` (`auth_provider.dart:172-181`).
Either way the redirect sees `isInitialized && !isAuthenticated` and sends the
user from `/splash` to `/login` (`app_router.dart:85-86`).

Unknown locations hit go_router's `errorBuilder` (`app_router.dart:111-115`),
which logs `Router: unknown route <uri>` via `AppLogger.e` and renders
`SplashScreen`; the redirect then moves the user on.

---

## Summary

**This routing setup gives you:**

1. ✅ **Declarative routing** - one `GoRouter` in `core/router/app_router.dart`; screens call `context.go`/`context.push`.
2. ✅ **Central auth gate** - a single `redirect` keyed on `isInitialized`/`isAuthenticated`, re-run by `refreshListenable`.
3. ✅ **Thin splash** - a pure loader that only calls `AuthProvider.initialize()`.
4. ✅ **Stateful tabs** - `StatefulShellRoute.indexedStack`, one navigator per tab.
5. ✅ **Deep links** - `benefit://reset-password?token=…` recovered by `customSchemeRedirect`, warm links routed by `DeepLinkHandler` with the token in `extra`.
6. ✅ **Secure persistence** - tokens in `SecureTokenStorage` under `auth_tokens`; expired tokens refreshed at startup, cleared on failure.
7. ✅ **Runtime lock** - `AppLockProvider` + `AppLockScreen` layered in `MaterialApp.router`'s `builder`.

**The beauty:** Authentication is centralized in `AuthProvider`; the router reads
`isInitialized`/`isAuthenticated` in one place, so screens and the splash stay
free of navigation logic.
