---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [MAIN_AUTH_OVERVIEW.md](../documentation/architecture/MAIN_AUTH_OVERVIEW.md) - High-level concepts
>
> **Related:** [AUTH.md](../AUTH.md) | [PROVIDER_GUIDE.md](presentation/PROVIDER_GUIDE.md)
---

# Main.dart Authentication & Routing Architecture

This document explains how the main.dart routing setup works and how authentication is integrated.

> **⚠️ Routing migrated to go_router (Phase 1 / Round 3).** The Navigator-1.0 description
> below (static `routes` map, global `navigatorKey`, `pushReplacementNamed`, `onUnknownRoute`,
> `IndexedStack` tabs) is **historical**. The app now uses **go_router**:
> - Route tree + central auth redirect live in **`lib/core/router/app_router.dart`**
>   (`createAppRouter(AuthProvider)`). `main.dart` uses `MaterialApp.router`.
> - The auth gate is a **`redirect`** keyed on `AuthProvider.isInitialized`/`isAuthenticated`
>   with `refreshListenable: authProvider`; the splash screen is now a pure loader that only
>   calls `AuthProvider.initialize()`.
> - The 5 tabs are a **`StatefulShellRoute.indexedStack`** (`/home/{community,progress,activity,
>   benefit,profile}`, default Activity). Full-screen pushes (`/session/:id`, `/device-connection`,
>   `/device-pairing`, `/benefit-qr`) run on the root navigator.
> - The app-lock overlay stays in `MaterialApp.router`'s `builder`; deep links navigate via the
>   router (`DeepLinkHandler` buffers cold-start links until init; reset token via `extra`).
> - Screens navigate with `context.go`/`context.push` (no named routes / `navigatorKey`).
>
> Read the sections below for the auth/session *concepts* (still accurate), but treat the routing
> mechanics as superseded by `app_router.dart`.

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
2. Splash initializes `AuthProvider` and checks: "Is user authenticated?"
3. **If YES** → Navigate to `/home` (main app with 5 tabs)
4. **If NO** → Navigate to `/login` (login screen)
5. After successful login → Navigate to `/home`

Authentication is fully implemented: the splash screen restores any stored
session via `AuthProvider.initialize()` and routes accordingly. A separate
runtime **app-lock overlay** (biometric/password) can re-gate the app after it
returns from the background.

---

### The Components

#### 1. main.dart - The Entry Point

`void main() async` bootstraps the app before `runApp`:

```
main() async
  ├─> WidgetsFlutterBinding.ensureInitialized()
  ├─> SeedService.seedIfNeeded()        (only if SeedConfig.isEnabled; errors swallowed)
  ├─> SensorManager().initialize()
  ├─> tokenStorage = SecureTokenStorage()
  ├─> authService  = MockAuthService()
  ├─> DeepLinkHandler(navigatorKey).initialize()
  └─> runApp(
        MultiProvider(
          providers: [ AuthProvider (FIRST), ProfileProvider, BenefitProvider,
                       ProgressProvider, ConnectivityProvider, ActivityProvider,
                       HealthPlatformProvider, AppLockProvider ],
          child: const BeneFitApp(),       // StatefulWidget, not MaterialApp directly
        ),
      )
```

`BeneFitApp` is a `StatefulWidget` (with `WidgetsBindingObserver`) whose
`build` returns `Consumer<AppLockProvider>` → `MaterialApp`:

```
BeneFitApp (StatefulWidget)
  └─> Consumer<AppLockProvider> → MaterialApp
      ├─> navigatorKey: navigatorKey (global key, for deep links / forced logout)
      ├─> Routes defined:
      │   ├─ '/' → SplashScreen
      │   ├─ '/login' → LoginScreen
      │   ├─ '/register' → RegisterScreen
      │   ├─ '/verify' → EmailVerificationScreen
      │   ├─ '/forgot-password' → ForgotPasswordScreen
      │   ├─ '/reset-password' → ResetPasswordScreen
      │   └─ '/home' → MainNavigationScreen
      ├─> builder: shows AppLockScreen overlay when appLockProvider.isLocked
      ├─> onUnknownRoute → SplashScreen
      └─> initialRoute: '/' (starts at splash)
```

**What happens:**
- App launches and runs the async bootstrap above
- MaterialApp looks at `initialRoute: '/'`
- Shows the widget mapped to `'/'` → **SplashScreen**

---

#### 2. SplashScreen - The Decision Maker

```
SplashScreen loads
  └─> initState() runs
      └─> _checkAuthAndNavigate()
          ├─> _status = 'Loading...'          (~500ms delay)
          ├─> _status = 'Checking session...'
          ├─> await context.read<AuthProvider>().initialize()  (restores stored session)
          │
          └─> Navigate based on authProvider.isAuthenticated:
              ├─ If true → show 'Welcome back, <name>!' (~500ms), then
              │            Navigator.pushReplacementNamed('/home')
              └─ If false → Navigator.pushReplacementNamed('/login')

          (on exception → debugPrint, _status = 'Error: $e', 2s delay,
           pushReplacementNamed('/login'))
```

**Key concept: `pushReplacementNamed`**
- Removes splash from navigation stack
- User can't press "back" to return to splash
- Clean navigation flow

---

#### 3. The Routes Map

```dart
routes: {
  '/': (context) => const SplashScreen(),
  '/login': (context) => const LoginScreen(),
  '/register': (context) => const RegisterScreen(),
  '/verify': (context) => const EmailVerificationScreen(),
  '/forgot-password': (context) => const ForgotPasswordScreen(),
  '/reset-password': (context) => const ResetPasswordScreen(),
  '/home': (context) => const MainNavigationScreen(),
},
onUnknownRoute: (settings) =>
    MaterialPageRoute(builder: (context) => const SplashScreen()),
```

**How routing works:**
- Each route name (`'/login'`) maps to a widget builder function
- `Navigator.pushReplacementNamed('/home')` looks up `'/home'` in the map
- Builds and displays `MainNavigationScreen()`

---

### File Structure

```
lib/
├── main.dart                              # Entry point, bootstrap, providers, routes
├── presentation/
│   ├── screens/
│   │   ├── splash/
│   │   │   └── splash_screen.dart         # Initial loading + auth-gate screen
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── email_verification_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── reset_password_screen.dart
│   │   ├── security/
│   │   │   └── app_lock_screen.dart       # Lock overlay (biometric/password)
│   │   └── ...                            # activity, benefit, community, profile, progress, ...
│   └── navigation/
│       └── main_navigation.dart           # 5-tab navigation
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
SplashScreen shows ('Loading...' → 'Checking session...')
  ↓
AuthProvider.initialize() restores stored tokens from SecureTokenStorage
  ↓
authProvider.isAuthenticated == true
  ↓
'Welcome back, <name>!' (~500ms)
  ↓
Navigator.pushReplacementNamed('/home')
  ↓
MainNavigationScreen appears (5 tabs)
```

#### New / logged-out user:

```
User opens app
  ↓
SplashScreen shows
  ↓
AuthProvider.initialize() finds no valid stored session
  ↓
authProvider.isAuthenticated == false
  ↓
Navigator.pushReplacementNamed('/login')
  ↓
User enters credentials → authProvider.login(email, password)
  ↓
Login successful → tokens saved to SecureTokenStorage
  ↓
Navigator.pushReplacementNamed('/home')
```

Token persistence uses **`SecureTokenStorage`** (Flutter Secure Storage), not
`SharedPreferences`. Tokens are stored as a single JSON blob under the key
`auth_tokens`. At startup, `AuthProvider.initialize()` refreshes expired access
tokens via `AuthService.refreshToken(...)`; on a refresh failure it clears the
stored tokens and nulls the current user, so `isAuthenticated` becomes `false`
and the splash screen subsequently routes to `/login`. (An `AuthInterceptor`
exists under `core/network/` as not-yet-wired infrastructure for a future
networked `AuthService` — it is not currently instantiated or attached to
`ApiClient`.)

---

### Key Concepts Explained

#### Named Routes vs Direct Navigation

**Direct (what we used before):**
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => HomeScreen()),
);
```

**Named (what we'll use):**
```dart
Navigator.pushNamed(context, '/home');
```

**Benefits:**
- ✅ Centralized route definitions
- ✅ Easy to maintain
- ✅ Can pass arguments
- ✅ Deep linking ready

---

#### pushReplacement vs push

**push** (adds to stack):
```
[Splash] → push → [Splash, Login] → push → [Splash, Login, Home]
User can press back: Home → Login → Splash
```

**pushReplacement** (replaces current):
```
[Splash] → pushReplacement → [Login] → pushReplacement → [Home]
User can't go back to Splash or Login
```

For auth flow, we want **pushReplacement** so users can't accidentally go back to splash/login after they're authenticated.

---

### Adding New Routes Later

When you want to add more screens (e.g., session details):

**1. Add to routes:**
```dart
routes: {
  '/': (context) => const SplashScreen(),
  '/login': (context) => const LoginScreen(),
  // ... other existing routes ...
  '/home': (context) => const MainNavigationScreen(),
  '/session-details': (context) => SessionDetailsScreen(), // NEW
}
```

**2. Navigate to it:**
```dart
// From anywhere in the app:
Navigator.pushNamed(context, '/session-details');
```

**3. Pass data (optional):**
```dart
// Navigate with arguments:
Navigator.pushNamed(
  context,
  '/session-details',
  arguments: sessionId,
);

// Receive in SessionDetailsScreen:
final sessionId = ModalRoute.of(context)!.settings.arguments as String;
```

---

### The Auth Check Implementation

The auth check lives in `SplashScreen._checkAuthAndNavigate()` and delegates the
actual session restore to `AuthProvider`. The splash screen never touches tokens
or the network directly — it asks `AuthProvider` whether the user is
authenticated.

```dart
Future<void> _checkAuthAndNavigate() async {
  try {
    setState(() => _status = 'Loading...');
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() => _status = 'Checking session...');
    final authProvider = context.read<AuthProvider>();
    await authProvider.initialize(); // restores tokens from SecureTokenStorage

    if (mounted) {
      final isAuthenticated = authProvider.isAuthenticated;
      if (isAuthenticated) {
        setState(() =>
            _status = 'Welcome back, ${authProvider.currentUser?.name ?? 'User'}!');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      Navigator.of(context).pushReplacementNamed(
        isAuthenticated ? '/home' : '/login',
      );
    }
  } catch (e) {
    debugPrint('SplashScreen error: $e');
    setState(() => _status = 'Error: $e');
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}
```

`AuthProvider.initialize()` is where the real work happens: it reads stored
tokens via `SecureTokenStorage`, validates/refreshes them through `AuthService`,
and exposes `isAuthenticated` / `currentUser`. The splash screen stays thin.

---

### Error Handling

If anything in `_checkAuthAndNavigate()` throws (e.g. token storage or
initialization fails), the splash screen logs the error, surfaces it in the
on-screen status text, waits briefly, and then **falls back to `/login`** (not
`/home`) so the user can re-authenticate:

```dart
} catch (e) {
  debugPrint('SplashScreen error: $e');
  setState(() => _status = 'Error: $e');
  await Future.delayed(const Duration(seconds: 2));
  if (mounted) {
    Navigator.of(context).pushReplacementNamed('/login');
  }
}
```

In addition, `onUnknownRoute` in `main.dart` routes any unrecognized route name
back to the `SplashScreen`.

---

## Summary

> **⚠️ Historical:** The routing specifics below (named routes,
> `pushReplacement`) describe the superseded Navigator-1.0 setup. The current
> app uses **go_router** (`lib/core/router/app_router.dart`); the auth-gate and
> session *concepts* still hold, but routing is now a central `redirect` +
> `StatefulShellRoute.indexedStack`, not a named-routes map.

**This routing setup gave you:**

1. ✅ **Professional routing** - Named routes, centralized
2. ✅ **Real auth gate** - Splash restores the session via `AuthProvider.initialize()`
3. ✅ **Clean navigation** - `pushReplacement`, no back to splash/login
4. ✅ **Scalable** - Easy to add new screens
5. ✅ **Secure persistence** - Tokens in `SecureTokenStorage`; `AuthProvider.initialize()` refreshes expired tokens at startup and clears them on failure (splash then routes to `/login`)
6. ✅ **Runtime lock** - `AppLockProvider` overlays the app after backgrounding

**The beauty:** Authentication is centralized in `AuthProvider`; screens and the
splash gate just read `isAuthenticated`, so the routing layer stays simple.
