import 'package:flutter/material.dart';
import 'package:benefitflutter/features/auth/utils/password_validator.dart';

/// A reusable password text field with built-in validation and visibility toggle.
///
/// Features:
/// - Password visibility toggle
/// - Real-time validation (optional)
/// - Integration with [PasswordValidator]
/// - Customizable decoration
/// - Error display via [errorText] or [FormField] validation
///
/// Example usage:
/// ```dart
/// PasswordTextField(
///   controller: _passwordController,
///   labelText: 'Password',
///   validateOnChange: true,
///   showRequirementsHelper: true,
/// )
/// ```
class PasswordTextField extends StatefulWidget {
  /// Controller for the text field
  final TextEditingController controller;

  /// Label text for the input field
  final String labelText;

  /// Whether to validate password strength (not just empty check)
  final bool validateStrength;

  /// Whether to validate on every change (real-time validation)
  final bool validateOnChange;

  /// Whether to show password requirements as helper text
  final bool showRequirementsHelper;

  /// External error text (overrides internal validation display)
  final String? errorText;

  /// Whether the field is enabled
  final bool enabled;

  /// Focus node for the field
  final FocusNode? focusNode;

  /// Callback when validation state changes
  final ValueChanged<List<String>>? onValidationChanged;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Callback when field is submitted
  final VoidCallback? onSubmitted;

  /// Text input action
  final TextInputAction? textInputAction;

  /// Autofill hints
  final Iterable<String>? autofillHints;

  const PasswordTextField({
    super.key,
    required this.controller,
    this.labelText = 'Password',
    this.validateStrength = false,
    this.validateOnChange = false,
    this.showRequirementsHelper = false,
    this.errorText,
    this.enabled = true,
    this.focusNode,
    this.onValidationChanged,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;
  String? _internalError;

  @override
  void initState() {
    super.initState();
    if (widget.validateOnChange) {
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    if (widget.validateOnChange) {
      widget.controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    if (!widget.validateStrength) return;

    final password = widget.controller.text;
    final errors = PasswordValidator.getErrors(password);

    setState(() {
      _internalError = errors.isNotEmpty ? errors.first : null;
    });

    widget.onValidationChanged?.call(errors);
  }

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  String? get _displayError => widget.errorText ?? _internalError;

  String? get _helperText {
    if (!widget.showRequirementsHelper) return null;
    return 'Min ${PasswordValidator.minLength} chars, uppercase, lowercase, number';
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: (value) {
        widget.onChanged?.call(value);
      },
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.labelText,
        errorText: _displayError,
        errorMaxLines: 2,
        helperText: _helperText,
        helperMaxLines: 2,
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: _toggleVisibility,
        ),
      ),
    );
  }
}

/// A [FormField] version of [PasswordTextField] for use with [Form] widgets.
///
/// Integrates with Flutter's form validation system.
///
/// Example usage:
/// ```dart
/// Form(
///   key: _formKey,
///   child: PasswordFormField(
///     controller: _passwordController,
///     labelText: 'Password',
///     validateStrength: true,
///   ),
/// )
/// ```
class PasswordFormField extends StatefulWidget {
  /// Controller for the text field
  final TextEditingController controller;

  /// Label text for the input field
  final String labelText;

  /// Whether to validate password strength
  final bool validateStrength;

  /// Whether to show password requirements as helper text
  final bool showRequirementsHelper;

  /// Whether the field is enabled
  final bool enabled;

  /// Focus node for the field
  final FocusNode? focusNode;

  /// Custom validator (runs after strength validation if enabled)
  final String? Function(String?)? additionalValidator;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Text input action
  final TextInputAction? textInputAction;

  /// Autofill hints
  final Iterable<String>? autofillHints;

  const PasswordFormField({
    super.key,
    required this.controller,
    this.labelText = 'Password',
    this.validateStrength = false,
    this.showRequirementsHelper = false,
    this.enabled = true,
    this.focusNode,
    this.additionalValidator,
    this.onChanged,
    this.textInputAction,
    this.autofillHints,
  });

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscureText = true;

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  String? _validate(String? value) {
    if (value == null || value.isEmpty) {
      return '${widget.labelText} is required';
    }

    if (widget.validateStrength) {
      final error = PasswordValidator.validate(value);
      if (error != null) return error;
    }

    return widget.additionalValidator?.call(value);
  }

  String? get _helperText {
    if (!widget.showRequirementsHelper) return null;
    return 'Min ${PasswordValidator.minLength} chars, uppercase, lowercase, number';
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      validator: _validate,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: _helperText,
        helperMaxLines: 2,
        errorMaxLines: 2,
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: _toggleVisibility,
        ),
      ),
    );
  }
}
