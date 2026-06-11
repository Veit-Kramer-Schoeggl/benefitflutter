---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [WIDGETS.md](../../lib/features/auth/widgets/WIDGETS.md) - Implementation details with code examples
>
> **Related:** [AUTH Overview](../architecture/AUTH_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Authentication Widgets Overview

## Purpose

The authentication widgets provide reusable UI components for password entry, validation feedback, and verification code input. These widgets ensure consistent user experience across all authentication screens.

## Available Widgets

### 1. PasswordTextField
A specialized text field for password entry with:
- Toggle visibility (show/hide password)
- Obscured input by default
- Consistent styling
- Validation integration via `PasswordValidator`

A `PasswordFormField` variant is also provided for use inside a `Form`.

### 2. PasswordStrengthIndicator
Visual feedback for password strength, with three styles (`PasswordStrengthStyle`):
- `barOnly` - color-coded strength bar with label (Weak/Fair/Good/Strong)
- `checksOnly` (default) - per-requirement checkmark list, updated in real time
- `barWithChecks` - both the bar and the checkmark list

### 3. PasswordRequirementsText
A static text widget that lists the password requirements (no live validation):
- Pulls requirements from `PasswordValidator` for consistency
- Three formats (`PasswordRequirementsFormat`): `compact` (default, single line), `bulleted`, `numbered`
- Optional prefix text and custom text style

### 4. VerificationCodeField
A single centered input field for 6-digit verification codes:
- Fixed 6-digit length (`maxLength: 6`)
- Digits-only input (`FilteringTextInputFormatter.digitsOnly`)
- Optional mock-code hint box for development
- Used for email verification, password reset, and account deletion flows

A `VerificationCodeFormField` variant is also provided for use inside a `Form`.

## Password Strength Levels

Strength is scored over 6 points: one point each for min length, uppercase,
lowercase, and number (4 checks), plus bonus points for length >= 12 and
length >= 16. The score is normalized to 0.0-1.0, and the level/color is
derived from that value.

| Level | Color | Normalized strength |
|-------|-------|---------------------|
| **Weak** | Red | < 0.25 |
| **Fair** | Orange | < 0.5 |
| **Good** | Amber | < 0.75 |
| **Strong** | Green | >= 0.75 |

## Password Requirements

The password must meet these criteria (enforced by `PasswordValidator`):
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number

> Note: special characters are not required by `PasswordValidator`.

## Usage Context

These widgets are intended for the authentication screens. Current usage:
- **Registration Screen** - `PasswordStrengthIndicator` (checks-only) for password creation
- **Password Reset Screen** - `VerificationCodeField` (reset code) and `PasswordStrengthIndicator` for the new password
- **Email Verification Screen** - `VerificationCodeField` for code input
- **Profile Screen** - `VerificationCodeField` (account-deletion flow, `_showDeletionVerificationDialog`)

> Note: the Login Screen currently uses a plain `TextFormField` (with its own
> visibility toggle) rather than `PasswordTextField`. `PasswordTextField`,
> `PasswordFormField`, and `PasswordRequirementsText` are available but not yet
> wired into any auth screen.

## Widget Architecture

```
┌─────────────────────────────────────────────────┐
│              Authentication Form                 │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │          Email TextField                  │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │       PasswordTextField                   │  │
│  │                                    [👁]   │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │    PasswordStrengthIndicator              │  │
│  │    [████████░░░░░░░░░░] Fair              │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │    PasswordStrengthIndicator (checks)     │  │
│  │    ✓ At least 8 characters                │  │
│  │    ✓ One uppercase letter                 │  │
│  │    ✓ One lowercase letter                 │  │
│  │    ○ One number                           │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Reusability** | Components work in any auth context |
| **Consistency** | Same look and feel everywhere |
| **Accessibility** | Clear labels and feedback |
| **Real-time** | Immediate validation feedback |

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Authentication | [AUTH.md](../../AUTH.md) | [AUTH_OVERVIEW](../architecture/AUTH_OVERVIEW.md) |
| Main Routing | [MAIN_AUTH.md](../../lib/MAIN_AUTH.md) | [MAIN_AUTH_OVERVIEW](../architecture/MAIN_AUTH_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
