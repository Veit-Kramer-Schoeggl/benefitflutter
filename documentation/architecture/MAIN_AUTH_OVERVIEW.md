---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [MAIN_AUTH.md](../../lib/MAIN_AUTH.md) - Implementation details with code examples
>
> **Related:** [AUTH Overview](./AUTH_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Main.dart Routing & Authentication Overview

## Purpose

The main.dart file serves as the entry point for the BeneFit app, wiring up the router and integrating the authentication flow. It determines whether users see the login screen or main app based on their authentication status.

Routing uses **go_router**: `main.dart` builds the router with `createAppRouter(authProvider)` and renders `MaterialApp.router`. The route tree and the central auth redirect live in [`lib/core/router/app_router.dart`](../../lib/core/router/app_router.dart).

## Navigation Flow

```
┌─────────────────────────────────────────────────────────┐
│                   App Navigation Flow                    │
│                                                          │
│   main() ──► MaterialApp.router (createAppRouter)        │
│                  │                                       │
│                  ▼                                       │
│         initialLocation: '/splash'                      │
│                  │                                       │
│                  ▼                                       │
│            SplashScreen (pure loader)                   │
│         calls AuthProvider.initialize()                 │
│                  │                                       │
│         central redirect re-runs                        │
│         (refreshListenable: authProvider)               │
│                  │                                       │
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
- `'/reset-password'` - Reset password (also reached via deep link; token passed via `extra`)
- `'/home/{community,progress,activity,benefit,profile}'` - Main app, a `StatefulShellRoute.indexedStack` with 5 tabs (default `/home/activity`)
- Full-screen pushes on the root navigator: `'/session/:id'`, `'/device-connection'`, `'/device-pairing'`, `'/benefit-qr'`

Unknown routes are surfaced via the router's `errorBuilder`, which falls back to the splash screen (which then redirects).

### Auth Redirect
Instead of the splash screen imperatively navigating, a central `redirect` in `app_router.dart` gates the app:
- It holds on `/splash` until `AuthProvider.isInitialized` is `true` (session restore done).
- Once initialized, it routes to `/home/activity` (if `isAuthenticated`) or `/login`.
- Unauthenticated users are kept inside the auth area; an authenticated user on `/login` is sent home.
- `refreshListenable: authProvider` re-runs the redirect whenever auth state changes.

Screens navigate with `context.go` / `context.push` (no named routes or global `navigatorKey`). A runtime **app-lock overlay** is layered in `MaterialApp.router`'s `builder`.

### Provider Setup
Main.dart configures the Provider tree:
- `AuthProvider` for authentication/identity state (registered first)
- `ProfileProvider` for editable profile data (wired as a `ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>`)
- `ProxyProvider` pattern for dependent providers (they receive `userId` from `AuthProvider`)
- All providers accessible throughout the app

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
├── main.dart                    # Entry point; builds router + MaterialApp.router
├── core/
│   └── router/
│       └── app_router.dart      # go_router route tree + central auth redirect
├── presentation/
│   ├── screens/
│   │   ├── splash/              # Initial loading
│   │   ├── auth/                # Login screens
│   │   ├── community/           # Tab 0
│   │   ├── progress/            # Tab 1
│   │   ├── activity/            # Tab 2 (default)
│   │   ├── benefit/             # Tab 3
│   │   └── profile/             # Tab 4
│   └── navigation/
│       └── main_navigation.dart # Bottom tab bar
```

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Authentication | [AUTH.md](../../AUTH.md) | [AUTH_OVERVIEW](./AUTH_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](../screens/ACTIVITY_SCREEN_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
