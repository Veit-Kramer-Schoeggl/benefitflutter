---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [MAIN_AUTH_OVERVIEW.md](../documentation/architecture/MAIN_AUTH_OVERVIEW.md) - High-level concepts
>
> **Related:** [AUTH.md](../AUTH.md) | [PROVIDER_GUIDE.md](presentation/PROVIDER_GUIDE.md)
---

# Main.dart Authentication & Routing Architecture

This document explains how the main.dart routing setup works and how authentication is integrated.

## How Option 3 Works (Step by Step)

### Conceptual Overview

Think of it like a **decision tree**:
1. App starts → Shows Splash Screen
2. Splash checks: "Is user logged in?"
3. **If YES** → Navigate to `/home` (main app with 5 tabs)
4. **If NO** → Navigate to `/login` (login screen)
5. After successful login → Navigate to `/home`

For MVP: We **always return "YES"** (skip login), but the structure is ready.

---

### The Components

#### 1. main.dart - The Entry Point

```
main()
  └─> BeneFitApp (MaterialApp)
      ├─> Routes defined:
      │   ├─ '/' → SplashScreen
      │   ├─ '/login' → LoginScreen
      │   └─ '/home' → MainNavigationScreen
      └─> initialRoute: '/' (starts at splash)
```

**What happens:**
- App launches
- MaterialApp looks at `initialRoute: '/'`
- Shows the widget mapped to `'/'` → **SplashScreen**

---

#### 2. SplashScreen - The Decision Maker

```
SplashScreen loads
  └─> initState() runs
      └─> _checkAuthAndNavigate()
          ├─> Wait 2 seconds (show splash animation)
          ├─> Call _checkAuth() → returns bool
          │   └─> (MVP: always returns true)
          │   └─> (Future: checks token/session)
          │
          └─> Navigate based on result:
              ├─ If true → Navigator.pushReplacementNamed('/home')
              └─ If false → Navigator.pushReplacementNamed('/login')
```

**Key concept: `pushReplacementNamed`**
- Removes splash from navigation stack
- User can't press "back" to return to splash
- Clean navigation flow

---

#### 3. The Routes Map

```dart
routes: {
  '/': (context) => SplashScreen(),
  '/login': (context) => LoginScreen(),
  '/home': (context) => MainNavigationScreen(),
}
```

**How routing works:**
- Each route name (`'/login'`) maps to a widget builder function
- `Navigator.pushReplacementNamed('/home')` looks up `'/home'` in the map
- Builds and displays `MainNavigationScreen()`

---

### File Structure

```
lib/
├── main.dart                              # Entry point + route definitions
├── presentation/
│   ├── screens/
│   │   ├── splash/
│   │   │   └── splash_screen.dart         # Initial loading screen
│   │   ├── auth/
│   │   │   └── login_screen.dart          # Login (placeholder for MVP)
│   │   └── home/...                       # Existing screens
│   └── navigation/
│       └── main_navigation.dart           # 5-tab navigation
```

---

### The Flow in Practice

#### MVP Behavior (No Auth):

```
User opens app
  ↓
SplashScreen shows (2 seconds)
  ↓
_checkAuth() returns true (hardcoded)
  ↓
Navigator.pushReplacementNamed('/home')
  ↓
MainNavigationScreen appears (5 tabs)
```

#### Future Behavior (With Auth):

```
User opens app
  ↓
SplashScreen shows
  ↓
_checkAuth() checks SharedPreferences for token
  ↓
  ├─> Token exists and valid?
  │     ↓
  │   Navigator.pushReplacementNamed('/home')
  │
  └─> No token or expired?
        ↓
      Navigator.pushReplacementNamed('/login')
        ↓
      User enters credentials
        ↓
      Login successful → save token
        ↓
      Navigator.pushReplacementNamed('/home')
```

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
  '/': (context) => SplashScreen(),
  '/login': (context) => LoginScreen(),
  '/home': (context) => MainNavigationScreen(),
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

#### MVP Version (now):
```dart
Future<bool> _checkAuth() async {
  // Always return true - skip auth for MVP
  return true;
}
```

#### Future Version (Phase 2):
```dart
Future<bool> _checkAuth() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  if (token == null) return false;

  // Optional: Validate token with API
  try {
    final response = await http.get(
      Uri.parse('$apiUrl/auth/validate'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}
```

**You change ONE function, everything else stays the same!**

---

### Error Handling

```dart
Future<void> _checkAuthAndNavigate() async {
  try {
    await Future.delayed(Duration(seconds: 2));

    final isAuthenticated = await _checkAuth();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        isAuthenticated ? '/home' : '/home', // MVP: always /home
      );
    }
  } catch (e) {
    // Handle errors (network issues, etc.)
    if (mounted) {
      // Show error screen or retry
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      // Still navigate somewhere (fallback to home)
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}
```

---

## Summary

**This routing setup gives you:**

1. ✅ **Professional routing** - Named routes, centralized
2. ✅ **Auth-ready** - Change one function later
3. ✅ **Clean navigation** - No back to splash
4. ✅ **Scalable** - Easy to add new screens
5. ✅ **Works now** - Skips auth for MVP

**The beauty:** The app works immediately, but the architecture is production-ready for auth when you need it.
