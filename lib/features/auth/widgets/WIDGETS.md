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

This module provides a unified system for password input, validation, and strength indication. All widgets are designed to work together and pull their validation rules from a single source of truth: `PasswordValidator`.

### Key Benefits

- **Single Source of Truth**: Change password requirements in `PasswordValidator` and all widgets update automatically
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

Use `PasswordFormField` when working with Flutter's `Form` widget:

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

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `controller` | `TextEditingController` | required | Text controller |
| `labelText` | `String` | 'Password' | Field label |
| `validateStrength` | `bool` | false | Enable strength validation |
| `validateOnChange` | `bool` | false | Validate as user types |
| `showRequirementsHelper` | `bool` | false | Show requirements helper text |
| `errorText` | `String?` | null | External error (overrides internal) |
| `enabled` | `bool` | true | Field enabled state |
| `onValidationChanged` | `ValueChanged<List<String>>?` | null | Callback with current errors |

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

Static text displaying password requirements. Automatically syncs with `PasswordValidator`.

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

## Changing Password Requirements

All password requirements are defined in a single location:

```
lib/features/auth/utils/password_validator.dart
```

To change requirements (e.g., minimum length):

```dart
class PasswordValidator {
  static const int minLength = 8;  // Change this value

  // Add new requirements here...
  static bool hasSpecialChar(String password) =>
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
}
```

After changing the validator, all widgets automatically reflect the new rules.

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

Use `VerificationCodeFormField` when working with Flutter's `Form` widget:

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

#### Features

- Centered, large font with letter spacing for easy reading
- Digits-only input filtering
- Built-in validation (empty check, 6-digit length)
- Optional mock code hint box for development
- Consistent styling across all verification flows

---

## Related Files

| File | Purpose |
|------|---------|
| `password_validator.dart` | Core validation logic and requirements |
| `password_utils.dart` | Password hashing (SHA-256) |
| `auth_service.dart` | Authentication API integration |

## Migration Guide

To migrate existing screens to use these widgets:

1. Import `auth_widgets.dart`
2. Replace `TextField` with `PasswordTextField` or `PasswordFormField`
3. Add `PasswordStrengthIndicator` for visual feedback
4. Remove duplicated validation logic (use `PasswordValidator` directly)

See the [commit history](#) for examples of migrated screens.
