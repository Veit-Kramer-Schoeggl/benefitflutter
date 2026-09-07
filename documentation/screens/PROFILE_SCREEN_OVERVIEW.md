---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROFILE_SCREEN_PLAN.md](../../lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [AUTH Overview](../architecture/AUTH_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Profile Screen Overview

> _Last verified against `lib/presentation/screens/profile/profile_screen.dart` (1337 lines) and `lib/providers/profile_provider.dart` (83 lines) on 2026-08-28 — branch `feat/phase-2-background-tracking`, commit `fd7dfc1`._

## Purpose

The Profile Screen displays and allows editing of user information, biometrics, preferences, and account/security settings. It reads the logged-in user from `AuthProvider` (the source of identity truth) and persists profile edits through `ProfileProvider`, while account/security flows (change password, delete account) go through `AuthProvider` (no dedicated edit-mode toggle).

## Key Features

| Feature | Description |
|---------|-------------|
| **Profile Header** | Avatar (from gallery), display name, country, verification badge |
| **Profile Picture** | Tap avatar to pick an image from the gallery |
| **Biometric Fields** | Select gender, height, and weight |
| **Account Settings** | Settings dialog edits display name (`User.displayName`), country (persisted as `UserPreferences.defaultLocationCity`) and email (mock verification, saved immediately) |
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
| **Selection cards** | Gender, Height, Weight | Open a bottom-sheet picker (Male/Female/Other; 140–259 cm; 40–159 kg — height and weight are 120 entries each, profile_screen.dart:356, 368, 380) |
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
3. `_saveProfileData()` (profile_screen.dart:158-239) writes three things: `User.copyWith(displayName:, gender:)` through `ProfileProvider.updateUser()` — which persists to the repository first and then syncs identity via `AuthProvider.setCurrentUser(...)` (profile_provider.dart:69-70); a `UserBiometricsReported` upsert (height/weight); and a `UserPreferences` upsert (country → `defaultLocationCity`)
4. Only the user update does the two-step write. `saveBiometrics()` / `savePreferences()` are one-line repository passthroughs — no identity sync, no error capture and no `notifyListeners()` (profile_provider.dart:46-52)
5. A confirmation snackbar is shown and `_loadProfileData()` re-reads user, biometrics and preferences

> **Biometrics are overwritten in place, not appended.** The write runs only when height or weight is set (profile_screen.dart:179) and reuses the existing record id (`_currentBiometrics?.id ?? const Uuid().v4()`, 181) while stamping a fresh `reportDate: DateTime.now()` (183); a missing value falls back to the previously stored one (184-185). In the repository, `saveBiometrics()` looks the row up by exact `(userId, reportDate)` (user_repository_impl.dart:169-173) — which never matches, because the timestamp is always new — so it takes the insert path, and `ConflictAlgorithm.replace` on the reused primary key (user_biometrics_dao.dart:59-66) replaces the existing row. **Result: no measurement history accumulates.** `UserRepository.getBiometricsHistory()` (user_repository.dart:36) exists and is implemented, but is **not surfaced in any screen or provider**.

### Editing Account Settings
1. User taps the AppBar settings (⚙) icon
2. A dialog edits Name, Country, and Email
3. Changing the email triggers a mock verification dialog before saving; on "Verified" the new address is written straight away (profile_screen.dart:898-900)

## Persistence Model

Not everything on this screen waits for **Save Changes** — six of the flows write the moment their dialog is confirmed:

| Change | When it is written | Entry point |
|--------|--------------------|-------------|
| Display name, gender, height, weight, country | On **Save Changes** | `_saveProfileData()` (profile_screen.dart:158-239) |
| Profile picture | Immediately on pick | `_pickImageFromGallery()` (545-588, `updateUser` at 569) |
| Email (after mock verification) | Immediately on "Verified" | `_handleEmailChange()` (862-900, `updateUser` at 900) |
| Identity verification | Immediately on "Verify" | `_startVerificationFlow()` (922-976, `updateUser` at 958) |
| Password | Immediately on "Save" | `AuthProvider.changePassword(...)` (1110-1113) |
| Biometric unlock toggle | Immediately on toggle | `BiometricService.enableBiometric()` / `disableBiometric()` (706, 731) — stored in secure prefs, not the user row |
| Account deletion | Immediately on code confirm | `AuthProvider.confirmAccountDeletion(code)` (1303) |

Name and country typed into the settings dialog are the exception: they only mutate local widget state (profile_screen.dart:843-844) and are **lost if the user navigates away without tapping Save Changes**.

## Data Mapping

What the picker labels become on disk — relevant when querying the DB or writing a migration:

| UI value | Stored as | Conversion |
|----------|-----------|------------|
| Gender — `Male` / `Female` / `Other` | `User.gender` = `male` / `female` / `other` | capitalised for display by `_formatGender()` (profile_screen.dart:133-136), lower-cased on save by `_parseGender()` (139-141) |
| Height — `"175 cm"` | `UserBiometricsReported.heightCm` (`int`) | digits extracted by `_parseHeight()` (144-148) |
| Weight — picked as whole kg, redisplayed as `"72.0 kg"` | `UserBiometricsReported.weightKg` (`double`) | `_parseWeight()` (151-155); re-rendered with `toStringAsFixed(1)` (115) |
| Country — `"Austria"` | `UserPreferences.defaultLocationCity` | read at 109, written at 195 (update) / 204 (create). There is no country column on `User` |

`User.name` is never written by this screen. The only `copyWith` call sites are `displayName`/`gender` (169), `profileImagePath` (566), `email` (898) and `isVerified`/`verificationStatus` (952).

## Profile Picture

- Shows the user's saved image (`profileImagePath`) via `FileImage`, otherwise the default asset `assets/images/icons/profile/icon_profil.png` (profile_screen.dart:296-300)
- Tapping the avatar opens the gallery picker, constrained to `maxWidth: 512`, `maxHeight: 512`, `imageQuality: 80` (profile_screen.dart:550-555), so a full-resolution photo is never loaded or stored for a 110 px avatar — package `image_picker: ^1.2.1` (pubspec.yaml:53)
- The picked file is copied into the app documents directory as `{userId}_profile.jpg` (profile_screen.dart:533-540) and the new path is persisted **immediately** through `ProfileProvider.updateUser()` (566-569) — it does not wait for Save Changes
- Failures surface as a red "Error saving image" snackbar and reset `_isSaving` (profile_screen.dart:576-586)
- **Status: local only.** The image stays in app documents; there is no upload/sync of the avatar

## Security & Account

- **Change Password** — verifies the current password against `passwordHash` with `PasswordUtils.verifyPassword` (profile_screen.dart:1075-1084), checks the confirmation match (1087-1092), runs `PasswordValidator.validate` (1095-1101), then calls `AuthProvider.changePassword(...)` (1110-1113)
- **Biometric Unlock** — card rendered only when `_biometricAvailable` (profile_screen.dart:417); its title is dynamic ("Unlock with Face ID / Fingerprint / Iris / Biometrics", 647-657, from `AppBiometricType` in lib/features/security/services/biometric_service.dart:8). When enabled, the app locks after `SecurityConfig.biometricLockDelay = Duration(minutes: 2)` in the background (lib/core/config/security_config.dart:61) — **except while an activity-tracking session is running**: `AppLockProvider.onAppResumed()` returns early when `isTrackingActive` is true (lib/providers/app_lock_provider.dart:74-78), and `main.dart:270-278` passes `isTracking || isPaused` from `ActivityProvider`. Failed unlock attempts are capped at `SecurityConfig.maxBiometricAttempts = 3` (security_config.dart:69), after which `_isPermanentlyLocked` is set and the overlay falls back to password entry, `unlockWithPassword()` (app_lock_provider.dart:144-151, 161-168)
- **Delete Account** — a warning dialog (profile_screen.dart:1163-1214) requests a deletion code via `AuthProvider.requestAccountDeletion()` (1222); the follow-up dialog rejects empty or non-6-character input client-side (1281-1295) and confirms via `AuthProvider.confirmAccountDeletion(code)` (1303), which deletes the local user row and clears tokens (auth_provider.dart:663-668), then navigates to `/login` (1318). Cancel calls `AuthProvider.clearPendingDeletion()` (1271)
- **Status: the deletion code is a mock.** The dialog passes `mockCode: mockCode, showMockCodeHint: true` to `VerificationCodeField` (profile_screen.dart:1256-1263), which renders the 6-digit code **on screen** via `_MockCodeHint` (lib/features/auth/widgets/verification_code_field.dart:63-64). No email is sent: `AuthService.requestAccountDeletion()` generates the 6 digits with `Random()` and keeps them in an in-memory `_pendingDeletions` map with a 15-minute expiry (lib/features/auth/data/auth_service.dart:294-297, 544-557). Identity verification (`_startVerificationFlow`) and the email-change confirmation are mocks in the same sense — both simply set the field when the user taps the confirm button

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Authentication | [AUTH.md](../../AUTH.md) | [AUTH_OVERVIEW](../architecture/AUTH_OVERVIEW.md) |
| Progress Screen | [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) | [PROGRESS_SCREEN_OVERVIEW](./PROGRESS_SCREEN_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
