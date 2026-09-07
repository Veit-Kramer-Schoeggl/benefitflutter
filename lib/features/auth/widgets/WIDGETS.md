---
> **Documentation Type:** TECHNICAL (Implementation Details & Code Examples)
>
> **Overview Version:** [AUTH_WIDGETS_OVERVIEW.md](../../../../documentation/widgets/AUTH_WIDGETS_OVERVIEW.md) - High-level concepts
>
> **Related:** [AUTH.md](../../../../AUTH.md) | [MAIN_AUTH.md](../../../MAIN_AUTH.md)
---

# Auth Widgets

Reusable authentication widgets for consistent password handling across the BeneFit app.

## Overview

This module provides a unified system for password input, validation, and strength indication. All widgets are designed to work together, and they read `PasswordValidator.minLength` from a single source of truth. The requirement *labels*, however, are still duplicated inside the widgets - see [Changing Password Requirements](#changing-password-requirements).

### Key Benefits

- **Single Source of Truth (for `minLength`)**: widgets interpolate `PasswordValidator.minLength`; requirement *labels* are still duplicated across three widget files - see [Changing Password Requirements](#changing-password-requirements)
- **Consistent UX**: Same look and behavior across registration, login, reset, and profile screens
- **Composable**: Use widgets individually or combine them for richer experiences
- **Accessible**: Built with Flutter's accessibility features in mind

## Quick Start

```dart
import 'package:benefitflutter/features/auth/widgets/auth_widgets.dart';
```

## Widgets

### PasswordTextField

A password input field with visibility toggle and optional validation.

#### Basic Usage

```dart
final _passwordController = TextEditingController();

PasswordTextField(
  controller: _passwordController,
  labelText: 'Password',
)
```

#### With Real-time Validation

```dart
PasswordTextField(
  controller: _passwordController,
  labelText: 'New Password',
  validateStrength: true,
  validateOnChange: true,
  showRequirementsHelper: true,
  onValidationChanged: (errors) {
    // errors is List<String> of current validation failures
    setState(() => _hasErrors = errors.isNotEmpty);
  },
)
```

#### Form Integration

Use `PasswordFormField` when working with Flutter's `Form` widget.
**Status: no call sites** - implemented and exported, but currently used nowhere in `lib/`;
the app's only `PasswordTextField` usage is the Profile change-password dialog
(`profile_screen.dart:999, 1006, 1025`).

```dart
Form(
  key: _formKey,
  child: Column(
    children: [
      PasswordFormField(
        controller: _passwordController,
        labelText: 'Password',
        validateStrength: true,
        showRequirementsHelper: true,
      ),
      PasswordFormField(
        controller: _confirmController,
        labelText: 'Confirm Password',
        additionalValidator: (value) {
          if (value != _passwordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
      ),
    ],
  ),
)
```

#### Properties

All 13 constructor parameters of `PasswordTextField`:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `controller` | `TextEditingController` | required | Text controller |
| `labelText` | `String` | 'Password' | Field label |
| `validateStrength` | `bool` | false | Run `PasswordValidator.getErrors` - **only takes effect together with `validateOnChange: true`** |
| `validateOnChange` | `bool` | false | Attach a controller listener; does nothing unless `validateStrength` is also true |
| `showRequirementsHelper` | `bool` | false | Shows `'Min 8 chars, uppercase, lowercase, number'` as helper text |
| `errorText` | `String?` | null | External error; takes precedence over the internal one |
| `enabled` | `bool` | true | Field enabled state |
| `focusNode` | `FocusNode?` | null | Focus node |
| `onValidationChanged` | `ValueChanged<List<String>>?` | null | Fires only when both `validateStrength` and `validateOnChange` are true |
| `onChanged` | `ValueChanged<String>?` | null | Callback on text change |
| `onSubmitted` | `VoidCallback?` | null | Callback on submit |
| `textInputAction` | `TextInputAction?` | null | Keyboard action |
| `autofillHints` | `Iterable<String>?` | null | Autofill hints |

> **Gotcha:** `PasswordTextField` validates only when *both* `validateStrength` and
> `validateOnChange` are true - the listener is attached in `initState` for `validateOnChange`
> (`password_text_field.dart:90-92`) and `_onTextChanged` returns early when `validateStrength`
> is false (`:103-104`). `validateStrength: true` on its own is a no-op, and
> `onValidationChanged` never fires. `PasswordFormField` differs: `validateStrength: true` alone
> is enough there, because validation runs from the form validator (`:235-238`).

#### PasswordFormField Properties

`PasswordFormField` is **not** a drop-in replacement for `PasswordTextField`: it has no
`validateOnChange`, `errorText`, `onValidationChanged` or `onSubmitted`, and it adds
`additionalValidator`. Copying `errorText:` or `validateOnChange:` across is a compile error.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `controller` | `TextEditingController` | required | Text controller |
| `labelText` | `String` | 'Password' | Field label; also used in the `'<label> is required'` message |
| `validateStrength` | `bool` | false | Run `PasswordValidator.validate` inside the form validator |
| `showRequirementsHelper` | `bool` | false | Show the compact requirements helper text |
| `enabled` | `bool` | true | Field enabled state |
| `focusNode` | `FocusNode?` | null | Focus node |
| `additionalValidator` | `String? Function(String?)?` | null | Runs after the built-in empty/strength checks |
| `onChanged` | `ValueChanged<String>?` | null | Callback on text change |
| `textInputAction` | `TextInputAction?` | null | Keyboard action |
| `autofillHints` | `Iterable<String>?` | null | Autofill hints |

---

### PasswordStrengthIndicator

Visual indicator showing password strength and requirement fulfillment.

#### Checkmarks Only (Default)

```dart
PasswordStrengthIndicator(
  password: _passwordController.text,
)
```

#### Strength Bar Only

```dart
PasswordStrengthIndicator(
  password: _passwordController.text,
  style: PasswordStrengthStyle.barOnly,
)
```

#### Combined Bar + Checkmarks

```dart
PasswordStrengthIndicator(
  password: _passwordController.text,
  style: PasswordStrengthStyle.barWithChecks,
)
```

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `password` | `String` | required | Password to evaluate |
| `style` | `PasswordStrengthStyle` | `checksOnly` | Display style |
| `animate` | `bool` | true | Animate changes |

#### Strength Styles

| Style | Description |
|-------|-------------|
| `checksOnly` | Checkmark list showing met/unmet requirements |
| `barOnly` | Progress bar with color (red→green) |
| `barWithChecks` | Both bar and checkmarks |

---

### PasswordRequirementsText

Static text displaying password requirements. Reads `PasswordValidator.minLength`; the rest of
the labels are hardcoded in `password_requirements_text.dart:58-67`.

**Status: no call sites** - implemented and exported, but currently used nowhere in `lib/`.

#### Compact (Single Line)

```dart
PasswordRequirementsText.compact()
// Output: "Min 8 chars, uppercase, lowercase, number"
```

#### Detailed (Bulleted List)

```dart
PasswordRequirementsText.detailed()
// Output:
// • At least 8 characters
// • One uppercase letter (A-Z)
// • One lowercase letter (a-z)
// • One number (0-9)
```

#### Custom Format

```dart
PasswordRequirementsText(
  format: PasswordRequirementsFormat.numbered,
  prefixText: 'Password must have:',
  textStyle: TextStyle(fontSize: 12, color: Colors.grey),
)
// Output:
// Password must have:
// 1. At least 8 characters
// 2. One uppercase letter (A-Z)
// 3. One lowercase letter (a-z)
// 4. One number (0-9)
```

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `format` | `PasswordRequirementsFormat` | `compact` | Display format |
| `textStyle` | `TextStyle?` | null | Custom text style |
| `prefixText` | `String?` | null | Text before requirements |

---

### VerificationCodeField

A styled input field for 6-digit verification codes used in email verification, password reset, and account deletion flows.

#### Basic Usage

```dart
final _codeController = TextEditingController();

VerificationCodeField(
  controller: _codeController,
  labelText: 'Verification Code',
)
```

#### With Mock Code Hint (Development)

```dart
VerificationCodeField(
  controller: _codeController,
  labelText: 'Enter Code',
  mockCode: '123456',
  showMockCodeHint: true,
)
```

#### Form Integration

Use `VerificationCodeFormField` when working with Flutter's `Form` widget.
**Status: no call sites** - implemented and exported, but currently used nowhere in `lib/`.

```dart
Form(
  key: _formKey,
  child: VerificationCodeFormField(
    controller: _codeController,
    labelText: 'Reset Code',
    onFieldSubmitted: () => _handleSubmit(),
  ),
)
```

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `controller` | `TextEditingController` | required | Text controller |
| `labelText` | `String` | 'Verification Code' | Field label |
| `enabled` | `bool` | true | Field enabled state |
| `errorText` | `String?` | null | External error message |
| `mockCode` | `String?` | null | Mock code to display (dev only) |
| `showMockCodeHint` | `bool` | false | Show mock code hint box |
| `onChanged` | `ValueChanged<String>?` | null | Callback on text change |
| `onSubmitted` | `VoidCallback?` | null | Callback on submit |
| `textInputAction` | `TextInputAction` | `done` | Keyboard action |

> The table above describes `VerificationCodeField`. `VerificationCodeFormField` differs: it has
> **no** `errorText`, its submit callback is named `onFieldSubmitted` (not `onSubmitted`), and it
> adds `additionalValidator` (`String? Function(String?)?`) which runs after the built-in empty /
> 6-digit checks (`verification_code_field.dart:147-168`).

#### Features

- Centered, large font with letter spacing for easy reading
- Digits-only input filtering
- Built-in validation (empty check, 6-digit length) on `VerificationCodeFormField`
- Optional mock code hint box for development
- Consistent styling across all verification flows

---

## Changing Password Requirements

`PasswordValidator` (`lib/features/auth/utils/password_validator.dart`) owns the rules, but the
widgets only read `minLength` from it.

**Changing `minLength` is automatic.** Editing this one line updates every widget:

```dart
class PasswordValidator {
  static const int minLength = 8;  // Change this value
}
```

The interpolation sites are `password_requirements_text.dart:59` and `:67`,
`password_strength_indicator.dart:174`, and `password_text_field.dart:126` and `:245`.

**Adding a new rule is _not_ automatic.** After adding e.g. `hasSpecialChar` to
`PasswordValidator.validate` / `getErrors`, no widget would display or score it until you also
update all five hardcoded places:

1. `password_requirements_text.dart:58-63` - the `requirements` label list
2. `password_requirements_text.dart:66-67` - `compactString`
3. `password_strength_indicator.dart:172-189` - the `_Requirement` list
4. `password_strength_indicator.dart:131-145` - `score` plus the hardcoded `totalChecks = 4`
   and the two length bonuses
5. `password_text_field.dart:126` and `:245` - the hardcoded helper strings

---

## Complete Example: Registration Form

```dart
class RegistrationForm extends StatefulWidget {
  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Password field with requirements helper
          PasswordFormField(
            controller: _passwordController,
            labelText: 'Password',
            validateStrength: true,
            showRequirementsHelper: true,
          ),
          const SizedBox(height: 8),

          // Real-time strength indicator
          ListenableBuilder(
            listenable: _passwordController,
            builder: (context, _) => PasswordStrengthIndicator(
              password: _passwordController.text,
              style: PasswordStrengthStyle.barWithChecks,
            ),
          ),
          const SizedBox(height: 16),

          // Confirm password field
          PasswordFormField(
            controller: _confirmController,
            labelText: 'Confirm Password',
            additionalValidator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Handle registration
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
```

---

## Adding New Widgets

When adding new auth widgets to this module:

1. Create the widget file in this directory
2. Export it from `auth_widgets.dart`
3. Add documentation to this file
4. Include code examples

### Widget Template

```dart
import 'package:flutter/material.dart';

/// Brief description of the widget.
///
/// Detailed description and usage notes.
///
/// Example usage:
/// ```dart
/// MyNewWidget(
///   property: value,
/// )
/// ```
class MyNewWidget extends StatelessWidget {
  // ... implementation
}
```

---

## Related Files

| File | Purpose |
|------|---------|
| `lib/features/auth/utils/password_validator.dart` | Validation rules (`minLength = 8`, uppercase, lowercase, digit) |
| `lib/core/utils/password_utils.dart` | SHA-256 hashing + `verifyPassword` |
| `lib/features/auth/data/auth_service.dart` | `AuthService` interface + `MockAuthService` (in-memory or SQLite-backed; **no network calls** - `RealAuthService` does not exist yet) |

## Migration Guide

To migrate existing screens to use these widgets:

1. Import `auth_widgets.dart`
2. Replace `TextField` with `PasswordTextField` or `PasswordFormField`
3. Add `PasswordStrengthIndicator` for visual feedback
4. Remove duplicated validation logic (use `PasswordValidator` directly)

Migrated examples in the app today: `register_screen.dart:354`,
`reset_password_screen.dart:232, 282`, `email_verification_screen.dart:118`,
`profile_screen.dart:999-1025, 1256`.
