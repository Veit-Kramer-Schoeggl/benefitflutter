---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [MAIN_AUTH.md](../../lib/MAIN_AUTH.md) - Implementation details with code examples
>
> **Related:** [AUTH Overview](./AUTH_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Main.dart Routing & Authentication Overview

## Purpose

The main.dart file serves as the entry point for the BeneFit app, defining the routing structure and integrating authentication flow. It determines whether users see the login screen or main app based on their authentication status.

## Navigation Flow

```
┌─────────────────────────────────────────────────────────┐
│                   App Navigation Flow                    │
│                                                          │
│   main() ──► MaterialApp                                │
│                  │                                       │
│                  ▼                                       │
│              Routes:                                     │
│              '/'      → SplashScreen                    │
│              '/login' → LoginScreen                     │
│              '/home'  → MainNavigationScreen (5 tabs)   │
│                                                          │
│                  │                                       │
│                  ▼                                       │
│           initialRoute: '/'                             │
│                  │                                       │
│                  ▼                                       │
│            SplashScreen                                 │
│                  │                                       │
│           Check auth status                             │
│                  │                                       │
│         ┌───────┴───────┐                               │
│         │               │                               │
│    Logged in      Not logged in                         │
│         │               │                               │
│         ▼               ▼                               │
│      '/home'        '/login'                            │
└─────────────────────────────────────────────────────────┘
```

## Key Concepts

### Named Routes
The app uses named routes for navigation, making it easy to navigate between screens and manage the navigation stack:
- `'/'` - Splash screen (initial route)
- `'/login'` - Login screen
- `'/home'` - Main app with bottom navigation

### Push Replacement
The splash screen uses `pushReplacementNamed` to navigate, which:
- Removes the splash screen from the navigation stack
- Prevents users from pressing "back" to return to splash
- Creates a clean navigation flow

### Provider Setup
Main.dart configures the Provider tree:
- `UserProvider` for authentication state
- `ProxyProvider` pattern for dependent providers
- All providers accessible throughout the app

## The 5 Main Tabs

After authentication, users access the main app with five tabs:

| Tab | Screen | Purpose |
|-----|--------|---------|
| 1 | Activity | Start/stop tracking sessions |
| 2 | Progress | View session history |
| 3 | Benefit | Rewards and analytics |
| 4 | Profile | User information |
| 5 | Community | Social features (placeholder) |

## File Structure

```
lib/
├── main.dart                    # Entry point + routes
├── presentation/
│   ├── screens/
│   │   ├── splash/              # Initial loading
│   │   ├── auth/                # Login screens
│   │   ├── activity/            # Tab 1
│   │   ├── progress/            # Tab 2
│   │   ├── benefit/             # Tab 3
│   │   ├── profile/             # Tab 4
│   │   └── community/           # Tab 5
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
