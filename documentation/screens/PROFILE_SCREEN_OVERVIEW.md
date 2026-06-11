---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROFILE_SCREEN_PLAN.md](../../lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [AUTH Overview](../architecture/AUTH_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Profile Screen Overview

## Purpose

The Profile Screen displays and allows editing of user information, biometrics, preferences, and account/security settings. It reads the logged-in user from `AuthProvider` (the source of identity truth) and persists profile edits through `ProfileProvider`, while account/security flows (change password, delete account) go through `AuthProvider` (no dedicated edit-mode toggle).

## Key Features

| Feature | Description |
|---------|-------------|
| **Profile Header** | Avatar (from gallery), display name, country, verification badge |
| **Profile Picture** | Tap avatar to pick an image from the gallery |
| **Biometric Fields** | Select gender, height, and weight |
| **Account Settings** | Edit name, country, and email (with mock verification) |
| **Identity Verification** | Mock flow to mark the account as verified |
| **Security** | Change password, biometric app unlock toggle |
| **Connected Devices** | Navigate to the device connection screen |
| **Delete Account** | Two-step (warning + verification code) account deletion |
| **Logout** | Sign out with confirmation |

## User Flow

```
┌─────────────────────────────────────────────────┐
│ [⎋]            Profile                    [⚙]    │
│                                                  │
│           ┌───────────────┐                     │
│           │     Avatar    │  ← Tap to pick image│
│           └───────────────┘                     │
│                                                  │
│              Your Name                          │
│               Austria                           │
│            [ Verified ]                         │
│                                                  │
│  ▸ Gender          ▸ Height       ▸ Weight     │
│  ▸ Connected Devices                            │
│  ▸ Verify Identity   (only if not verified)    │
│  ▸ Change Password                              │
│  ▸ Unlock with Biometrics  (if available)      │
│  ▸ Delete Account                               │
│                                                  │
│            [ Save Changes ]                     │
│            [ Sign Out ]                         │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Sections

The screen is a single scrolling column with three groups of cards plus action buttons.

| Section | Card(s) | Behavior |
|---------|---------|----------|
| **Header** | Avatar, name, country, badge | Tap avatar to pick a gallery image; badge shows `Verified` (green) or `Not Verified` (orange) |
| **Selection cards** | Gender, Height, Weight | Open a bottom-sheet picker (Male/Female/Other; 140–259 cm; 40–159 kg) |
| **Navigation cards** | Connected Devices, Verify Identity, Change Password, Biometric toggle, Delete Account | Open a screen, dialog, or toggle a setting |

## State Management

The screen reads identity from `AuthProvider` and uses `ProfileProvider` for editable profile data (biometrics/preferences), and holds local widget state:
- `_currentUser`, `_currentBiometrics`, `_currentPreferences` loaded in `_loadProfileData()`
- Display values: `displayName`, `country`, `selectedGender`, `selectedHeight`, `selectedWeight`
- Loading/saving flags: `_isLoading`, `_isSaving`
- Biometric status: `_biometricAvailable`, `_biometricEnabled`, `_biometricType`

## Interaction Flow

### Loading Profile Data
1. `initState` calls `_loadProfileData()` and `_loadBiometricStatus()`
2. `_loadProfileData()` reads `currentUser` from `AuthProvider` (throws if no user)
3. Loads latest biometrics and preferences via `ProfileProvider` (`getLatestBiometrics` / `getPreferences`)
4. Populates the display fields (display name, country, gender, height, weight)

### Saving Changes
1. User edits selection cards and/or the settings dialog
2. User taps **Save Changes**
3. `_saveProfileData()` calls `ProfileProvider` to update the user (`displayName`, `gender`) and upsert biometrics (height/weight) and preferences (country); `ProfileProvider` writes to the repository and then syncs identity via `AuthProvider.setCurrentUser(...)`
4. A confirmation snackbar is shown and data is reloaded

### Editing Account Settings
1. User taps the AppBar settings (⚙) icon
2. A dialog edits Name, Country, and Email
3. Changing the email triggers a mock verification dialog before saving

## Profile Picture

- Shows the user's saved image (`profileImagePath`) or the default profile icon asset
- Tappable to pick a new image from the gallery
- The selected image is copied into the app documents directory as `{userId}_profile.jpg` and saved to the user record

## Security & Account

- **Change Password** — verifies the current password, validates the new one, then calls `AuthProvider.changePassword(...)`
- **Biometric Unlock** — toggle (shown only when biometrics are available) that enables/disables app lock; when enabled, the app locks after 2 minutes in the background
- **Delete Account** — a warning dialog requests a deletion code via `AuthProvider.requestAccountDeletion()`, then a 6-digit code dialog confirms via `AuthProvider.confirmAccountDeletion(code)` and navigates to `/login`

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Authentication | [AUTH.md](../../AUTH.md) | [AUTH_OVERVIEW](../architecture/AUTH_OVERVIEW.md) |
| Progress Screen | [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) | [PROGRESS_SCREEN_OVERVIEW](./PROGRESS_SCREEN_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
