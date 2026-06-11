---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [Profile Screen Overview](../../../../documentation/screens/PROFILE_SCREEN_OVERVIEW.md) - High-level concepts
>
> **Related:** [DATABASE.md](../../../../database/DATABASE.md) | [PROVIDER_GUIDE.md](../../PROVIDER_GUIDE.md) | [User Feature](../../../features/user/)
---

# Profile Screen Implementation Plan

> **⚠️ Implementation status (current code):** This is the original forward-looking
> plan. The Profile Screen was ultimately built **differently** from the design below:
> - There is **no** `ProfileProvider` and **no** `lib/providers/profile_provider.dart`.
>   The screen uses the existing **`UserProvider`** plus local widget state instead.
> - There is **no** edit-mode toggle (`_isEditing` / Edit / Cancel). Editing happens
>   via selection cards, a settings dialog, and a persistent **Save Changes** button.
> - The screen's **Save Changes** button persists `displayName`/`gender` (plus
>   biometrics — height/weight — and preferences — country), and handles avatar,
>   verification, biometric unlock, change-password, and account deletion.
>
> For an accurate description of what currently ships, see
> [`profile_screen.dart`](./profile_screen.dart) and the up-to-date
> [Profile Screen Overview](../../../../documentation/screens/PROFILE_SCREEN_OVERVIEW.md).
> The sections below are retained as the original plan/design record.

## Overview: Profile Screen with Interactivity

The Profile Screen differs from the Progress Screen through **user interaction**:
- ✏️ **Edit mode** on/off
- 💾 **Save data** (Update User)
- 🖼️ **Enlarge profile picture** (Image Zoom Dialog)
- 🔄 **Form validation**

We use the same **Provider Pattern**, but extend it with **state changes through user interaction**.

---

## Architecture Overview: Interactive Provider

```
┌─────────────────────────────────────────────────────────────────┐
│              Profile Screen - Interactive Architecture          │
│                                                                 │
│  ┌──────────────┐                    ┌──────────────┐           │
│  │   SCREEN     │                    │   PROVIDER   │           │
│  │              │                    │              │           │
│  │  - Edit Btn  │─── toggleEdit() ──►│ _isEditing   │           │
│  │  - Save Btn  │─── updateUser() ──►│ _isSaving    │           │
│  │  - Avatar    │─── showDialog() ───┼──────────────┤           │
│  │  - Form      │                    │              │           │
│  └──────────────┘                    │ Repository   │           │
│         │                            └──────────────┘           │
│         │                                    │                  │
│    Consumer<T>()                      notifyListeners()         │
│    (auto rebuild)                     (UI updates)              │
│         │                                    │                  │
│         ▼                                    ▼                  │
│  ┌──────────────┐                    ┌──────────────┐           │
│  │   WIDGETS    │                    │  USER MODEL  │           │
│  │              │                    │              │           │
│  │ - FormField  │◄───────────────────│ name, email  │           │
│  │ - Avatar     │                    │ copyWith()   │           │
│  │ - EditBtn    │                    │              │           │
│  └──────────────┘                    └──────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components Explained

### 1️⃣ **User Model** (already exists)
**File**: `lib/features/user/domain/user.dart`

**What we have:**
```dart
class User {
  final String id;
  final String name;
  final String email;
  final String passwordHash;

  // Profile fields (v3)
  final String? displayName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? timezone;

  final String? profileImagePath;
  final bool isVerified;
  final String verificationStatus;

  // copyWith() accepts ALL fields (id, name, email, passwordHash,
  // displayName, gender, dateOfBirth, timezone, profileImagePath,
  // isVerified, verificationStatus) — each defaulting to the current value.
  User copyWith({String? name, String? email, /* ...all other fields... */ }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      // ...remaining fields...
    );
  }
}
```

> **Note (current state):** The simplified snippet above is illustrative. The real
> `User` model carries `passwordHash` plus the v3 profile fields shown, and `copyWith`
> exposes every field. See `lib/features/user/domain/user.dart` for the full definition.

**Why `copyWith()` is important:**
→ We can create a new User instance with modified fields without changing the original (immutability).

**Example:**
```dart
// Old
User user = User(id: '1', name: 'Max', email: 'max@test.com', passwordHash: '...');

// New (only change displayName)
User updatedUser = user.copyWith(displayName: 'John');
// id, name, email, passwordHash, etc. are preserved
```

---

### 2️⃣ **ProfileProvider** (PLANNED — not implemented)
**File**: `lib/providers/profile_provider.dart`

> **Status:** This provider was never created. The shipped screen relies on the
> existing `lib/providers/user_provider.dart` (`UserProvider`) and local widget
> state instead. The design below is kept as the original plan.

**What it does:**
- Load user data
- **Manage edit mode**
- **Hold form data temporarily** (before saving)
- Perform user update

```dart
import 'package:flutter/foundation.dart';
import 'package:benefitflutter/features/user/data/user_repository.dart';
import 'package:benefitflutter/features/user/domain/user.dart';

class ProfileProvider extends ChangeNotifier {
  final UserRepository _repository;
  ProfileProvider(this._repository);

  // ===== STATE =====
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditing = false;  // ⭐ NEW: Edit Mode
  String? _error;
  User? _user;

  // Temporary form data (during editing)
  String? _tempName;
  String? _tempEmail;

  // ===== GETTERS =====
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isEditing => _isEditing;  // ⭐ UI asks: Am I in edit mode?
  String? get error => _error;
  User? get user => _user;
  bool get hasError => _error != null;

  // Getters for form fields (during edit mode)
  String get displayName => _isEditing ? (_tempName ?? _user?.name ?? '') : (_user?.name ?? '');
  String get displayEmail => _isEditing ? (_tempEmail ?? _user?.email ?? '') : (_user?.email ?? '');

  // ===== METHODS =====

  /// Load user data
  Future<void> fetchUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _repository.getUserById(userId);
      _error = null;
    } catch (e) {
      _error = 'Error loading: $e';
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ⭐ Activate/deactivate edit mode
  void toggleEditMode() {
    _isEditing = !_isEditing;

    if (_isEditing) {
      // Edit mode activated → Copy current data to temp fields
      _tempName = _user?.name;
      _tempEmail = _user?.email;
    } else {
      // Edit mode deactivated → Discard temp data
      _tempName = null;
      _tempEmail = null;
    }

    notifyListeners(); // 🔔 Rebuild UI (shows edit mode)
  }

  /// ⭐ Update form fields (during editing)
  void updateTempName(String name) {
    _tempName = name;
    // NO notifyListeners() here! TextField updates itself
  }

  void updateTempEmail(String email) {
    _tempEmail = email;
    // NO notifyListeners() here! TextField updates itself
  }

  /// ⭐ Save changes
  Future<bool> saveChanges() async {
    if (_user == null) return false;

    // Validation
    if (_tempName == null || _tempName!.trim().isEmpty) {
      _error = 'Name cannot be empty';
      notifyListeners();
      return false;
    }

    if (_tempEmail == null || !_tempEmail!.contains('@')) {
      _error = 'Invalid email address';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _error = null;
    notifyListeners(); // 🔔 UI shows saving spinner

    try {
      // Create new User object with changed data
      final updatedUser = _user!.copyWith(
        name: _tempName,
        email: _tempEmail,
      );

      // Perform update
      await _repository.updateUser(updatedUser);

      // Update local state
      _user = updatedUser;

      // Exit edit mode
      _isEditing = false;
      _tempName = null;
      _tempEmail = null;
      _error = null;

      return true; // Success
    } catch (e) {
      _error = 'Error saving: $e';
      return false; // Error
    } finally {
      _isSaving = false;
      notifyListeners(); // 🔔 UI updates with new state
    }
  }

  /// ⭐ Discard changes (Cancel)
  void cancelEdit() {
    _isEditing = false;
    _tempName = null;
    _tempEmail = null;
    _error = null;
    notifyListeners();
  }
}
```

**Key Concepts:**

1. **`_isEditing` State** - Controls whether UI is in edit mode
2. **Temporary Variables** (`_tempName`) - Hold changes until saving
3. **`toggleEditMode()`** - Switches between View/Edit mode
4. **`saveChanges()`** - Validates + Saves + Exits edit mode
5. **`cancelEdit()`** - Discards changes without saving

---

### 3️⃣ **ProfileScreen** (Interactive)
**File**: `lib/presentation/screens/profile/profile_screen.dart`

> **Status:** The file exists, but the actual implementation differs from the code
> below. It is a `StatefulWidget` that reads `currentUser` from `UserProvider`,
> loads biometrics and preferences in `_loadProfileData()`, and saves via
> `_saveProfileData()` (Save Changes button) rather than an edit-mode toggle.
> The sketch below is the original plan.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/profile_provider.dart';
import 'package:benefitflutter/presentation/shared/widgets/loading_widget.dart';
import 'package:benefitflutter/presentation/shared/widgets/error_display_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _userId = 'test-user-123';

  // ⭐ Form Controllers (for TextFields)
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchUser(_userId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // ⭐ Edit/Cancel Button in AppBar
          Consumer<ProfileProvider>(
            builder: (context, provider, child) {
              if (provider.isEditing) {
                // In edit mode: Cancel Button
                return IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => provider.cancelEdit(),
                );
              } else {
                // In view mode: Edit Button
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => provider.toggleEditMode(),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          // 1. Loading State
          if (provider.isLoading) {
            return const LoadingWidget(message: 'Loading profile...');
          }

          // 2. Error State
          if (provider.hasError && provider.user == null) {
            return ErrorDisplayWidget(
              message: provider.error!,
              onRetry: () => provider.fetchUser(_userId),
            );
          }

          // 3. Success State
          final user = provider.user!;

          // ⭐ Fill controllers with current data (when edit mode is activated)
          if (provider.isEditing) {
            _nameController.text = provider.displayName;
            _emailController.text = provider.displayEmail;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // ⭐ Profile picture (clickable to enlarge)
                GestureDetector(
                  onTap: () => _showProfileImageDialog(context),
                  child: Hero(
                    tag: 'profile-image',
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        _getInitials(user.name),
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Name (large text in view mode, otherwise TextField)
                if (!provider.isEditing)
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                const SizedBox(height: 8),

                // Email (smaller text in view mode, otherwise TextField)
                if (!provider.isEditing)
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),

                const SizedBox(height: 32),

                // ⭐ Edit Form (only visible in edit mode)
                if (provider.isEditing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Name TextField
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          onChanged: (value) => provider.updateTempName(value),
                        ),

                        const SizedBox(height: 16),

                        // Email TextField
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) => provider.updateTempEmail(value),
                        ),

                        const SizedBox(height: 24),

                        // ⭐ Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: provider.isSaving
                                ? null
                                : () async {
                                    final success = await provider.saveChanges();
                                    if (success && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Profile saved!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                            child: provider.isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),

                        // Error Message
                        if (provider.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              provider.error!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Statistics (always visible)
                const SizedBox(height: 32),
                const Divider(),
                _StatisticsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ⭐ Extract initials from name (for avatar)
  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// ⭐ Dialog to enlarge profile picture
  void _showProfileImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Hero(
          tag: 'profile-image',
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _getInitials(
                  context.read<ProfileProvider>().user?.name ?? '',
                ),
                style: const TextStyle(
                  fontSize: 120,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Statistics section (Sessions, Distance, etc.)
class _StatisticsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(icon: Icons.fitness_center, label: 'Sessions', value: '12'),
              _StatItem(icon: Icons.route, label: 'Distance', value: '45 km'),
              _StatItem(icon: Icons.local_fire_department, label: 'Calories', value: '1200'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }
}
```

---

## Important Interaction Concepts Explained

### 1️⃣ **Edit Mode Toggle**

```dart
// In Provider
void toggleEditMode() {
  _isEditing = !_isEditing;
  notifyListeners(); // UI rebuilds with edit fields
}

// In Screen
IconButton(
  icon: Icon(_isEditing ? Icons.close : Icons.edit),
  onPressed: () => provider.toggleEditMode(),
)
```

**What happens:**
1. User clicks Edit button
2. Provider sets `_isEditing = true`
3. `notifyListeners()` is called
4. Consumer rebuilds UI
5. UI shows TextFields instead of Text

---

### 2️⃣ **TextEditingController**

```dart
final _nameController = TextEditingController();

TextField(
  controller: _nameController,
  onChanged: (value) => provider.updateTempName(value),
)
```

**Why Controller?**
- Controller holds the current text value
- Allows programmatic getting/setting
- Must be cleaned up in `dispose()`

**Important:**
- `onChanged` writes to Provider (for validation)
- NO `notifyListeners()` in `onChanged` (otherwise lag)

---

### 3️⃣ **Saving with Validation**

```dart
Future<bool> saveChanges() async {
  // 1. Validate
  if (_tempName?.trim().isEmpty ?? true) {
    _error = 'Name cannot be empty';
    notifyListeners();
    return false;
  }

  // 2. Set saving state
  _isSaving = true;
  notifyListeners(); // UI shows spinner

  // 3. API Call
  await _repository.updateUser(updatedUser);

  // 4. Update local state
  _user = updatedUser;

  // 5. Exit edit mode
  _isEditing = false;
  notifyListeners(); // UI back to view mode

  return true;
}
```

**In Screen:**
```dart
ElevatedButton(
  onPressed: provider.isSaving ? null : () async {
    final success = await provider.saveChanges();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved!')),
      );
    }
  },
  child: provider.isSaving
    ? CircularProgressIndicator()
    : Text('Save'),
)
```

---

### 4️⃣ **Dialog for Profile Picture (Hero Animation)**

```dart
// In Screen
GestureDetector(
  onTap: () => _showProfileImageDialog(context),
  child: Hero(
    tag: 'profile-image',
    child: CircleAvatar(...),
  ),
)

// Dialog method
void _showProfileImageDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Hero(
        tag: 'profile-image', // Same tag!
        child: Container(width: 300, height: 300, ...),
      ),
    ),
  );
}
```

**Hero Animation:**
- `Hero` widget with same `tag` in Screen + Dialog
- Flutter automatically animates between both
- Smooth zoom effect

---

### 5️⃣ **`context.read<T>()` vs `context.watch<T>()`**

```dart
// ✅ CORRECT: read() in event handlers
IconButton(
  onPressed: () => context.read<ProfileProvider>().toggleEditMode(),
)

// ❌ WRONG: watch() in event handlers (unnecessary rebuilds)
IconButton(
  onPressed: () => context.watch<ProfileProvider>().toggleEditMode(),
)

// ✅ Consumer uses watch() internally
Consumer<ProfileProvider>(
  builder: (context, provider, child) {
    // provider is already "watched"
    return Text(provider.user.name);
  },
)
```

---

## Summary: Interactivity with Provider

| Action | Provider Method | UI Reaction |
|--------|----------------|-------------|
| Click Edit button | `toggleEditMode()` | TextFields appear |
| Enter name | `updateTempName()` | Controller updates |
| Click Save | `saveChanges()` | Spinner → Success/Error |
| Click Cancel | `cancelEdit()` | Back to view mode |
| Click Avatar | - (UI only) | Dialog with Hero animation |

**Key Principle:**
→ **Provider holds the state**, UI reacts automatically via `notifyListeners()`

---

## Checklist

> **Status:** The Profile Screen is implemented, but **not** via this checklist's
> approach. Phase 1 (separate `ProfileProvider`) and Phase 2 (register it in
> `main.dart`) were **not** done — the screen uses `UserProvider` instead. Phase 3+
> (the screen, save feedback, profile-picture upload, change password) shipped in a
> different form. Items remain unchecked because they describe the original plan, not
> the delivered implementation.

### Phase 1: Create Provider
- [ ] Create `lib/providers/profile_provider.dart`
- [ ] State variables: `_isEditing`, `_isSaving`, `_tempName`, `_tempEmail`
- [ ] Methods: `toggleEditMode()`, `saveChanges()`, `cancelEdit()`
- [ ] Implement validation in `saveChanges()`

### Phase 2: Register Provider
- [ ] `lib/main.dart` → Add `ProfileProvider` to the list

### Phase 3: Create Screen
- [ ] Change `ProfileScreen` to `StatefulWidget`
- [ ] Add TextEditingController
- [ ] Implement Consumer
- [ ] Edit/Cancel Button in AppBar
- [ ] TextFields with Controller
- [ ] Save Button with loading state

### Phase 4: Interactions
- [ ] Test edit mode toggle
- [ ] Test form validation
- [ ] Save feedback (SnackBar)
- [ ] Dialog for profile picture
- [ ] Test Hero animation

### Phase 5: Polish
- [ ] Show error messages
- [ ] Add statistics section
- [ ] Optional: Profile picture upload
- [ ] Optional: Change password

---

## Common Errors & Solutions

### ❌ TextField Loses Focus on Every Character
**Problem**: `notifyListeners()` in `updateTempName()`

**Solution**: NO `notifyListeners()` in TextField `onChanged`!
```dart
void updateTempName(String name) {
  _tempName = name;
  // NO notifyListeners() here!
}
```

---

### ❌ "Controller is already attached to a TextField"
**Problem**: Same controller for multiple TextFields

**Solution**: Create one controller per TextField

---

### ❌ Changes Are Not Saved
**Problem**: Forgot `copyWith()`

**Solution**: Always use `copyWith()` for immutable updates:
```dart
final updatedUser = _user!.copyWith(name: _tempName);
await _repository.updateUser(updatedUser);
_user = updatedUser; // ← Important!
```

---

## References

- Benefit Screen (Basics): `lib/presentation/screens/benefit/benefit_screen.dart`
- Provider Guide: `lib/presentation/PROVIDER_GUIDE.md`
- Progress Screen Plan: `lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md`
- User Model: `lib/features/user/domain/user.dart`
