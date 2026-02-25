import 'package:flutter/material.dart';
import 'package:benefitflutter/features/auth/utils/password_validator.dart';

/// A text widget that displays password requirements.
///
/// Automatically pulls requirements from [PasswordValidator] to ensure
/// consistency across the app. When requirements change in the validator,
/// this widget reflects those changes automatically.
///
/// Example usage:
/// ```dart
/// // Compact single-line format
/// PasswordRequirementsText.compact()
///
/// // Detailed bulleted list
/// PasswordRequirementsText.detailed()
///
/// // Custom format
/// PasswordRequirementsText(
///   format: PasswordRequirementsFormat.numbered,
///   textStyle: TextStyle(fontSize: 12),
/// )
/// ```
class PasswordRequirementsText extends StatelessWidget {
  /// Display format for the requirements
  final PasswordRequirementsFormat format;

  /// Custom text style (optional)
  final TextStyle? textStyle;

  /// Prefix text before requirements (optional)
  final String? prefixText;

  const PasswordRequirementsText({
    super.key,
    this.format = PasswordRequirementsFormat.compact,
    this.textStyle,
    this.prefixText,
  });

  /// Factory constructor for compact single-line format
  factory PasswordRequirementsText.compact({TextStyle? textStyle}) {
    return PasswordRequirementsText(
      format: PasswordRequirementsFormat.compact,
      textStyle: textStyle,
    );
  }

  /// Factory constructor for detailed bulleted list
  factory PasswordRequirementsText.detailed({TextStyle? textStyle}) {
    return PasswordRequirementsText(
      format: PasswordRequirementsFormat.bulleted,
      textStyle: textStyle,
    );
  }

  /// Get the list of requirements from PasswordValidator
  static List<String> get requirements => [
        'At least ${PasswordValidator.minLength} characters',
        'One uppercase letter (A-Z)',
        'One lowercase letter (a-z)',
        'One number (0-9)',
      ];

  /// Get compact requirements string
  static String get compactString =>
      'Min ${PasswordValidator.minLength} chars, uppercase, lowercase, number';

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey.shade600,
        );
    final style = textStyle ?? defaultStyle;

    return switch (format) {
      PasswordRequirementsFormat.compact => _buildCompact(style),
      PasswordRequirementsFormat.bulleted => _buildBulleted(style),
      PasswordRequirementsFormat.numbered => _buildNumbered(style),
    };
  }

  Widget _buildCompact(TextStyle? style) {
    final text = prefixText != null
        ? '$prefixText $compactString'
        : compactString;

    return Text(text, style: style);
  }

  Widget _buildBulleted(TextStyle? style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prefixText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(prefixText!, style: style),
          ),
        ...requirements.map(
          (req) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: style),
                Expanded(child: Text(req, style: style)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumbered(TextStyle? style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prefixText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(prefixText!, style: style),
          ),
        ...requirements.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text('${entry.key + 1}. ', style: style),
                ),
                Expanded(child: Text(entry.value, style: style)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Display format options for [PasswordRequirementsText]
enum PasswordRequirementsFormat {
  /// Single line: "Min 8 chars, uppercase, lowercase, number"
  compact,

  /// Bulleted list with each requirement on its own line
  bulleted,

  /// Numbered list with each requirement on its own line
  numbered,
}
