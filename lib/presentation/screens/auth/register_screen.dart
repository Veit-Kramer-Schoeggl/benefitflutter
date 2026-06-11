import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/features/auth/utils/password_validator.dart';
import 'package:benefitflutter/features/auth/widgets/auth_widgets.dart';

/// Registration screen with name, email, password fields
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _passwordText = '';

  // Email availability state
  bool _isCheckingEmail = false;
  String? _emailAvailabilityError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _emailFocusNode.addListener(_onEmailFocusChanged);
    // Clear any stale errors from previous screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearError();
    });
  }

  /// Check email availability when email field loses focus
  void _onEmailFocusChanged() {
    if (!_emailFocusNode.hasFocus) {
      _checkEmailAvailability();
    }
  }

  /// Async check if email is available
  Future<void> _checkEmailAvailability() async {
    final email = _emailController.text.trim();

    // Skip check for empty or invalid format
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _emailAvailabilityError = null;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailAvailabilityError = null;
    });

    final userProvider = context.read<AuthProvider>();
    final isAvailable = await userProvider.checkEmailAvailability(email);

    if (!mounted) return;

    setState(() {
      _isCheckingEmail = false;
      _emailAvailabilityError = isAvailable
          ? null
          : 'An account with this email already exists';
    });
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordText = _passwordController.text;
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailFocusNode.removeListener(_onEmailFocusChanged);
    _emailFocusNode.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Handle register button press
  Future<void> _handleRegister() async {
    final userProvider = context.read<AuthProvider>();

    // First, check email availability if not already checked
    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        _emailAvailabilityError == null &&
        !_isCheckingEmail) {
      final isAvailable = await userProvider.checkEmailAvailability(email);
      if (!mounted) return;

      if (!isAvailable) {
        setState(() {
          _emailAvailabilityError = 'An account with this email already exists';
        });
        // Form validation will now fail
      }
    }

    // Validate form (including email availability)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Clear any previous errors
    userProvider.clearError();

    // Attempt registration
    final verificationCode = await userProvider.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (verificationCode != null && mounted) {
      // Show verification code in dialog
      _showVerificationCodeDialog(verificationCode);
    }
  }

  /// Show dialog with verification code (mock email)
  void _showVerificationCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.email_outlined, color: Colors.green, size: 48),
        title: const Text('Verification Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your verification code is:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '(In production, this would be sent to your email)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              context.go('/verify');
            },
            child: const Text('Continue to Verification'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, userProvider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),

                    // Logo
                    Center(
                      child: Image.asset(
                        'assets/images/logos/logo_launcher_round.webp',
                        width: 80,
                        height: 80,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join BeneFit to start tracking your activities',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    // Name field
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      enabled: !userProvider.isLoading,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your name',
                        prefixIcon: const Icon(Icons.person_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email field with async availability check
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enabled: !userProvider.isLoading,
                      onChanged: (_) {
                        // Clear availability error when user edits
                        if (_emailAvailabilityError != null) {
                          setState(() {
                            _emailAvailabilityError = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        suffixIcon: _isCheckingEmail
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _emailAvailabilityError != null
                            ? const Icon(Icons.error_outline, color: Colors.red)
                            : _emailController.text.isNotEmpty &&
                                  _emailController.text.contains('@')
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                        errorText: _emailAvailabilityError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email';
                        }
                        // Also check availability error on submit
                        if (_emailAvailabilityError != null) {
                          return _emailAvailabilityError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field with validation
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      enabled: !userProvider.isLoading,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Create a password',
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
                        helperText: 'Min 8 chars, uppercase, lowercase, number',
                        helperMaxLines: 2,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a password';
                        }
                        return PasswordValidator.validate(value);
                      },
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
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      enabled: !userProvider.isLoading,
                      onFieldSubmitted: (_) => _handleRegister(),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
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

                    // Register button
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: userProvider.isLoading
                            ? null
                            : _handleRegister,
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
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign in link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: userProvider.isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
