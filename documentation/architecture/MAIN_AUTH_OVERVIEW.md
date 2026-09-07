---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [MAIN_AUTH.md](../../lib/MAIN_AUTH.md) - Implementation details with code examples
>
> **Related:** [AUTH Overview](./AUTH_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
>
> **Stand:** 2026-08-28 — verified against `lib/main.dart`, `lib/core/router/app_router.dart`,
> `lib/core/deep_link/deep_link_handler.dart` (go_router 17.3.0).
---

# Main.dart Routing & Authentication Overview

## Purpose

The main.dart file serves as the entry point for the BeneFit app, wiring up the router and integrating the authentication flow. It determines whether users see the login screen or main app based on their authentication status.

Routing uses **go_router**: `main.dart` builds the router with `createAppRouter(authProvider)` and renders `MaterialApp.router`. The route tree and the central auth redirect live in [`lib/core/router/app_router.dart`](../../lib/core/router/app_router.dart).

## Navigation Flow

```
┌─────────────────────────────────────────────────────────┐
│                   App Navigation Flow                   │
│                                                         │
│   main() ──► bootstrap() ──► MaterialApp.router         │
│         createAppRouter(authProvider)                   │
│                  │                                      │
│                  ▼                                      │
│         initialLocation: '/splash'                      │
│                  │                                      │
│                  ▼                                      │
│            SplashScreen (pure loader)                   │
│      calls AuthProvider.initialize() (no navigation)    │
│                  │                                      │
│         central redirect re-runs                        │
│         (refreshListenable: authProvider)               │
│                  │                                      │
│         ┌───────┴───────┐                               │
│         │               │                               │
│    Logged in      Not logged in                         │
│         │               │                               │
│         ▼               ▼                               │
│  '/home/activity'    '/login'                           │
└─────────────────────────────────────────────────────────┘
```

> **Note:** This is a simplified high-level flow showing the main paths. The full route list is in [Routes](#routes) below.

## Key Concepts

### Routes
Routing is declared with **go_router** in `lib/core/router/app_router.dart`. The app boots at `/splash` and navigation between auth/home is driven by a central `redirect` (see [Auth Redirect](#auth-redirect)), not imperative calls:
- `'/splash'` - Splash loader (initial location)
- `'/login'` - Login screen
- `'/register'` - Registration screen
- `'/verify'` - Email verification screen
- `'/forgot-password'` - Request password reset
- `'/reset-password'` - Reset password. The token arrives either as `extra` (warm deep links via `DeepLinkHandler`) or as a `?token=` query parameter (cold-start `benefit://` links rewritten by `customSchemeRedirect`); the builder takes `extra ?? queryParameters['token']`.
- `'/home/{community,progress,activity,benefit,profile}'` - Main app, a `StatefulShellRoute.indexedStack` with 5 tabs (default `/home/activity`)
- Full-screen pushes on the root navigator: `'/session/:id'`, `'/device-connection'`, `'/device-pairing'`, `'/benefit-qr'`
- Deep-link entry: raw `benefit://reset-password?token=…` is not a matchable in-app path — the redirect rewrites it first (see [Auth Redirect](#auth-redirect)).

Unknown routes are surfaced via the router's `errorBuilder`, which falls back to the splash screen (which then redirects).

### Auth Redirect
Instead of the splash screen imperatively navigating, a central `redirect` in `app_router.dart` gates the app. It runs in this order:

1. **Custom-scheme recovery** — `customSchemeRedirect(state.uri)` maps `benefit://reset-password?token=X` to `/reset-password?token=X` (token re-encoded via the `Uri` constructor), a token-less reset link to `/reset-password`, and any other `benefit://` host to `/splash`. Without this the platform's raw URI matches no route and the app sticks on splash (smoke finding F5); covered by `test/unit/router/deep_link_redirect_test.dart` (7 cases).
2. **Boot hold** — while `AuthProvider.isInitialized` is `false`, everything is held on `/splash`.
3. **Hand-off** — once initialized, `/splash` becomes `/home/activity` (authenticated) or `/login`.
4. **Auth-area fence** — an unauthenticated user anywhere outside `_authArea` (`/login`, `/register`, `/verify`, `/forgot-password`, `/reset-password`) is sent to `/login`.
5. **Login bounce** — an authenticated user on `/login` goes to `/home/activity`. `/verify` and `/reset-password` are deliberately exempt, because a just-verified user is briefly authenticated while still on those screens.

`refreshListenable: authProvider` re-runs the redirect whenever auth state changes.

Screens navigate with `context.go` / `context.push` — no named routes. A `rootNavigatorKey` is still exported from `app_router.dart`, but only as go_router's root navigator key, as `parentNavigatorKey` for the full-screen pushes, and to dismiss lingering dialogs on forced logout. A runtime **app-lock overlay** is layered in `MaterialApp.router`'s `builder`; when it demands a password, `_handlePasswordRequired` (`main.dart:281-289`) logs out via `AuthProvider.logout()`, resets `AppLockProvider`, pops open dialogs via `rootNavigatorKey.currentState?.popUntil((r) => r.isFirst)`, and calls `router.go('/login')`.

### Provider Setup
Main.dart configures the Provider tree:
- `AuthProvider` is constructed inside `bootstrap()` **before** the router, then registered first via `ChangeNotifierProvider<AuthProvider>.value` — so `createAppRouter` and `DeepLinkHandler` reference the same instance the widget tree sees.
- `ProfileProvider` for editable profile data, wired as `ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>` and attached with `attachAuth(authProvider)`.
- `ChangeNotifierProxyProvider<AuthProvider, …>` for the three data providers — Benefit, Progress and Activity each receive `updateUserId(authProvider.userId)`.
- Plain `ChangeNotifierProvider` for `ConnectivityProvider`, `HealthPlatformProvider` and `AppLockProvider`.
- Eight providers total, all accessible throughout the app.

## The 5 Main Tabs

After authentication, users access the main app with five tabs (a `StatefulShellRoute.indexedStack`). The redirect lands users on the **Activity** tab by default (`/home/activity`, branch index 2):

| Tab Index | Screen | Purpose |
|-----------|--------|---------|
| 0 | Community | Social features (placeholder) |
| 1 | Progress | View session history |
| 2 | Activity (default) | Start/stop tracking sessions |
| 3 | Benefit | Rewards and analytics |
| 4 | Profile | User information |

## File Structure

```
lib/
├── main.dart                    # Entry point; bootstrap() + MaterialApp.router
├── core/
│   ├── router/
│   │   └── app_router.dart      # go_router route tree + central auth redirect
│   └── deep_link/
│       └── deep_link_handler.dart  # benefit:// links → router.go
├── presentation/
│   ├── screens/
│   │   ├── splash/              # Initial loading
│   │   ├── auth/                # Login screens
│   │   ├── community/           # Tab 0
│   │   ├── progress/            # Tab 1
│   │   ├── activity/            # Tab 2 (default)
│   │   ├── benefit/             # Tab 3
│   │   ├── profile/             # Tab 4
│   │   ├── session/             # /session/:id (root-navigator push)
│   │   ├── wearable/            # /device-connection, /device-pairing
│   │   └── security/            # app_lock_screen.dart (overlay in builder)
│   └── navigation/
│       └── main_navigation.dart # Bottom tab bar (StatefulNavigationShell host)
```

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Authentication | [AUTH.md](../../AUTH.md) | [AUTH_OVERVIEW](./AUTH_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](../screens/ACTIVITY_SCREEN_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
