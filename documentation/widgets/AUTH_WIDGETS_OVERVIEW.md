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
- Validation integration

### 2. PasswordStrengthIndicator
Visual feedback for password strength:
- Color-coded strength levels
- Progress bar visualization
- Real-time updates as user types
- Clear strength labels

### 3. PasswordRequirementsText
Lists password requirements with checkmarks:
- Minimum length indicator
- Character type requirements
- Real-time validation feedback
- Green checkmarks for met requirements

### 4. VerificationCodeField
Input field for email/SMS verification codes:
- Fixed number of digits
- Auto-advance between fields
- Paste support
- Clear visual feedback

## Password Strength Levels

| Level | Color | Requirements |
|-------|-------|--------------|
| **Weak** | Red | Less than 6 characters |
| **Fair** | Orange | 6+ characters |
| **Good** | Yellow | 8+ chars, mixed case |
| **Strong** | Green | 10+ chars, numbers, symbols |

## Password Requirements

The password must meet these criteria:
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character

## Usage Context

These widgets are used in:
- **Login Screen** - Password entry
- **Registration Screen** - Password creation with strength
- **Password Reset** - New password entry
- **Email Verification** - Code input

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
│  │    [████████░░░░░░░░░░] Good              │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │    PasswordRequirementsText               │  │
│  │    ✓ 8+ characters                        │  │
│  │    ✓ Uppercase letter                     │  │
│  │    ○ Number                               │  │
│  │    ○ Special character                    │  │
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
