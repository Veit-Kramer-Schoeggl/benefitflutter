import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/features/auth/utils/password_validator.dart';
import 'package:benefitflutter/features/auth/widgets/auth_widgets.dart';

/// Reset password screen - enter code and new password
class ResetPasswordScreen extends StatefulWidget {
  /// Optional reset code delivered via deep link (`benefit://reset-password?token=`),
  /// passed by the router as `extra`/query. When present it pre-fills the code field.
  final String? token;

  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _resetSuccessful = false;
  String _passwordText = '';

  // Validation error state (for ordered validation)
  String? _codeError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    // Pre-fill the code from a deep-link token, if any.
    if (widget.token != null && widget.token!.isNotEmpty) {
      _codeController.text = widget.token!;
    }
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordText = _passwordController.text;
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Handle reset password button press
  Future<void> _handleReset() async {
    final userProvider = context.read<AuthProvider>();

    // Clear previous errors
    setState(() {
      _codeError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });
    userProvider.clearError();

    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // STEP 1: Validate code FIRST
    if (code.isEmpty) {
      setState(() {
        _codeError = 'Please enter the reset code';
      });
      return;
    }
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _codeError = 'Code must be exactly 6 digits';
      });
      return;
    }

    // STEP 2: Only after code is valid, check passwords
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Please enter a new password';
      });
      return;
    }

    final passwordValidation = PasswordValidator.validate(password);
    if (passwordValidation != null) {
      setState(() {
        _passwordError = passwordValidation;
      });
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        _confirmPasswordError = 'Please confirm your password';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
      return;
    }

    // STEP 3: All validations passed - attempt password reset
    final success = await userProvider.resetPassword(
      code: code,
      newPassword: password,
    );

    if (success && mounted) {
      setState(() {
        _resetSuccessful = true;
      });
      _showSuccessDialog();
    }
    // If failed, userProvider.error will be shown via Consumer
  }

  /// Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Password Reset'),
        content: const Text(
          'Your password has been successfully reset. Please sign in with your new password.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              context.go('/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  /// Handle back button - clear pending reset
  void _handleBack() {
    final userProvider = context.read<AuthProvider>();
    userProvider.clearPendingReset();
    userProvider.clearError();
    // May have been reached via deep link (go) with no back stack → go to login.
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, userProvider, child) {
            // Redirect if no pending reset AND no deep-link token (and not just
            // reset successfully).
            if (userProvider.pendingResetEmail == null &&
                widget.token == null &&
                !userProvider.isLoading &&
                !_resetSuccessful) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.go('/forgot-password');
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // Icon
                  const Center(
                    child: Icon(
                      Icons.lock_reset,
                      size: 80,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Reset Password',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your reset code and new password',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  // Code input field with mock code hint
                  VerificationCodeField(
                    controller: _codeController,
                    labelText: 'Reset Code',
                    enabled: !userProvider.isLoading,
                    errorText: _codeError,
                    mockCode: userProvider.pendingResetCode,
                    showMockCodeHint: true,
                  ),
                  const SizedBox(height: 16),

                  // New password field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    enabled: !userProvider.isLoading,
                    onChanged: (_) {
                      // Clear error when user types
                      if (_passwordError != null) {
                        setState(() => _passwordError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter your new password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _passwordError,
                      helperText: _passwordError == null
                          ? 'Min 8 chars, uppercase, lowercase, number'
                          : null,
                      helperMaxLines: 2,
                    ),
                  ),
                  if (_passwordText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    PasswordStrengthIndicator(
                      password: _passwordText,
                      style: PasswordStrengthStyle.checksOnly,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Confirm password field
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    enabled: !userProvider.isLoading,
                    onSubmitted: (_) => _handleReset(),
                    onChanged: (_) {
                      // Clear error when user types
                      if (_confirmPasswordError != null) {
                        setState(() => _confirmPasswordError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter your new password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _confirmPasswordError,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (userProvider.hasError) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              userProvider.error!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Reset password button
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: userProvider.isLoading ? null : _handleReset,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: userProvider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
