import 'package:flutter/material.dart';
import 'package:benefitflutter/features/auth/utils/password_validator.dart';

/// Visual indicator showing password strength and requirement fulfillment.
///
/// Displays either:
/// - A strength bar with color gradient (weak → strong)
/// - Checkmark list showing which requirements are met
/// - Both combined
///
/// Example usage:
/// ```dart
/// PasswordStrengthIndicator(
///   password: _passwordController.text,
///   style: PasswordStrengthStyle.barWithChecks,
/// )
/// ```
class PasswordStrengthIndicator extends StatelessWidget {
  /// The password to evaluate
  final String password;

  /// Display style for the indicator
  final PasswordStrengthStyle style;

  /// Whether to animate changes
  final bool animate;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.style = PasswordStrengthStyle.checksOnly,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      PasswordStrengthStyle.barOnly => _StrengthBar(
        password: password,
        animate: animate,
      ),
      PasswordStrengthStyle.checksOnly => _RequirementChecks(
        password: password,
        animate: animate,
      ),
      PasswordStrengthStyle.barWithChecks => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StrengthBar(password: password, animate: animate),
          const SizedBox(height: 8),
          _RequirementChecks(password: password, animate: animate),
        ],
      ),
    };
  }
}

/// Display style options for [PasswordStrengthIndicator]
enum PasswordStrengthStyle {
  /// Show only the strength bar
  barOnly,

  /// Show only the requirement checkmarks
  checksOnly,

  /// Show both bar and checkmarks
  barWithChecks,
}

/// Internal widget: Strength progress bar
class _StrengthBar extends StatelessWidget {
  final String password;
  final bool animate;

  const _StrengthBar({required this.password, required this.animate});

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength();
    final color = _getStrengthColor(strength);
    final label = _getStrengthLabel(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password strength',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: animate
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  child: LinearProgressIndicator(
                    value: strength,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: strength,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
        ),
      ],
    );
  }

  double _calculateStrength() {
    if (password.isEmpty) return 0.0;

    int score = 0;
    const totalChecks = 4;

    if (PasswordValidator.hasMinLength(password)) score++;
    if (PasswordValidator.hasUppercase(password)) score++;
    if (PasswordValidator.hasLowercase(password)) score++;
    if (PasswordValidator.hasNumber(password)) score++;

    // Bonus for extra length
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    // Normalize to 0.0 - 1.0
    return (score / (totalChecks + 2)).clamp(0.0, 1.0);
  }

  Color _getStrengthColor(double strength) {
    if (strength < 0.25) return Colors.red;
    if (strength < 0.5) return Colors.orange;
    if (strength < 0.75) return Colors.amber;
    return Colors.green;
  }

  String _getStrengthLabel(double strength) {
    if (password.isEmpty) return '';
    if (strength < 0.25) return 'Weak';
    if (strength < 0.5) return 'Fair';
    if (strength < 0.75) return 'Good';
    return 'Strong';
  }
}

/// Internal widget: Requirement checkmarks
class _RequirementChecks extends StatelessWidget {
  final String password;
  final bool animate;

  const _RequirementChecks({required this.password, required this.animate});

  @override
  Widget build(BuildContext context) {
    final requirements = [
      _Requirement(
        label: 'At least ${PasswordValidator.minLength} characters',
        isMet: PasswordValidator.hasMinLength(password),
      ),
      _Requirement(
        label: 'One uppercase letter',
        isMet: PasswordValidator.hasUppercase(password),
      ),
      _Requirement(
        label: 'One lowercase letter',
        isMet: PasswordValidator.hasLowercase(password),
      ),
      _Requirement(
        label: 'One number',
        isMet: PasswordValidator.hasNumber(password),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: requirements
          .map((req) => _RequirementRow(requirement: req, animate: animate))
          .toList(),
    );
  }
}

class _Requirement {
  final String label;
  final bool isMet;

  const _Requirement({required this.label, required this.isMet});
}

class _RequirementRow extends StatelessWidget {
  final _Requirement requirement;
  final bool animate;

  const _RequirementRow({required this.requirement, required this.animate});

  @override
  Widget build(BuildContext context) {
    final icon = requirement.isMet
        ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
        : const Icon(Icons.circle_outlined, color: Colors.grey, size: 16);

    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: requirement.isMet ? Colors.green.shade700 : Colors.grey.shade600,
      decoration: requirement.isMet ? TextDecoration.lineThrough : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          animate
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: icon,
                )
              : icon,
          const SizedBox(width: 8),
          Text(requirement.label, style: textStyle),
        ],
      ),
    );
  }
}
