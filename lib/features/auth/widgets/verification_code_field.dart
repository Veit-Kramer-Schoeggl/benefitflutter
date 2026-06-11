import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable verification code input field for 6-digit codes.
///
/// Used for email verification, password reset, and account deletion flows.
/// Provides consistent styling and validation across the app.
///
/// Example usage:
/// ```dart
/// VerificationCodeField(
///   controller: _codeController,
///   labelText: 'Verification Code',
///   enabled: !isLoading,
/// )
/// ```
class VerificationCodeField extends StatelessWidget {
  /// Controller for the text field
  final TextEditingController controller;

  /// Label text for the input field
  final String labelText;

  /// Whether the field is enabled
  final bool enabled;

  /// External error text
  final String? errorText;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Callback when field is submitted
  final VoidCallback? onSubmitted;

  /// Text input action
  final TextInputAction textInputAction;

  /// Mock code to display as hint (for development)
  final String? mockCode;

  /// Whether to show the mock code hint box
  final bool showMockCodeHint;

  const VerificationCodeField({
    super.key,
    required this.controller,
    this.labelText = 'Verification Code',
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.mockCode,
    this.showMockCodeHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMockCodeHint && mockCode != null) ...[
          _MockCodeHint(code: mockCode!),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textInputAction: textInputAction,
          textAlign: TextAlign.center,
          enabled: enabled,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 16,
          ),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: '000000',
            hintStyle: TextStyle(
              color: Colors.grey[300],
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 16,
            ),
            errorText: errorText,
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
          ),
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted?.call(),
        ),
      ],
    );
  }
}

/// A [FormField] version of [VerificationCodeField] for use with [Form] widgets.
///
/// Integrates with Flutter's form validation system.
///
/// Example usage:
/// ```dart
/// Form(
///   key: _formKey,
///   child: VerificationCodeFormField(
///     controller: _codeController,
///     labelText: 'Reset Code',
///   ),
/// )
/// ```
class VerificationCodeFormField extends StatelessWidget {
  /// Controller for the text field
  final TextEditingController controller;

  /// Label text for the input field
  final String labelText;

  /// Whether the field is enabled
  final bool enabled;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Callback when field is submitted
  final VoidCallback? onFieldSubmitted;

  /// Text input action
  final TextInputAction textInputAction;

  /// Mock code to display as hint (for development)
  final String? mockCode;

  /// Whether to show the mock code hint box
  final bool showMockCodeHint;

  /// Custom validator (runs after built-in validation)
  final String? Function(String?)? additionalValidator;

  const VerificationCodeFormField({
    super.key,
    required this.controller,
    this.labelText = 'Verification Code',
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.done,
    this.mockCode,
    this.showMockCodeHint = false,
    this.additionalValidator,
  });

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the verification code';
    }
    if (value.length != 6) {
      return 'Code must be 6 digits';
    }
    return additionalValidator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMockCodeHint && mockCode != null) ...[
          _MockCodeHint(code: mockCode!),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textInputAction: textInputAction,
          textAlign: TextAlign.center,
          enabled: enabled,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 16,
          ),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: '000000',
            hintStyle: TextStyle(
              color: Colors.grey[300],
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 16,
            ),
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
          ),
          onChanged: onChanged,
          onFieldSubmitted: (_) => onFieldSubmitted?.call(),
          validator: _validate,
        ),
      ],
    );
  }
}

/// Internal widget: Mock code hint box for development
class _MockCodeHint extends StatelessWidget {
  final String code;

  const _MockCodeHint({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '(Mock: Your code is $code)',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
