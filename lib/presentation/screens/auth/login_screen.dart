import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/user_provider.dart';
import 'package:benefitflutter/core/seed/seed_service.dart';
import 'package:benefitflutter/core/seed/seed_config.dart';
import 'package:benefitflutter/core/config/repository_config.dart';
import 'package:benefitflutter/features/auth/data/token_storage.dart';

/// Login screen with email/password authentication
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isReseeding = false;

  // Rate limiting state
  bool _isLockedOut = false;
  Duration _lockoutRemaining = Duration.zero;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  /// Check if currently locked out and start timer if needed
  Future<void> _checkLockoutStatus() async {
    final userProvider = context.read<UserProvider>();
    final isLocked = await userProvider.rateLimiter.isLockedOut();

    if (isLocked) {
      final remaining = await userProvider.rateLimiter.getLockoutRemaining();
      setState(() {
        _isLockedOut = true;
        _lockoutRemaining = remaining;
      });
      _startLockoutTimer();
    }
  }

  /// Start countdown timer for lockout
  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _lockoutRemaining = _lockoutRemaining - const Duration(seconds: 1);
        if (_lockoutRemaining.isNegative ||
            _lockoutRemaining == Duration.zero) {
          _isLockedOut = false;
          _lockoutRemaining = Duration.zero;
          timer.cancel();
        }
      });
    });
  }

  /// Handle login button press
  Future<void> _handleLogin() async {
    // Check if locked out
    if (_isLockedOut) {
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Clear any previous errors
    final userProvider = context.read<UserProvider>();
    userProvider.clearError();

    // Attempt login
    final success = await userProvider.login(
      _emailController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      // Navigate to home on success
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (mounted) {
      // Check if now locked out after failed attempt
      final isLocked = await userProvider.rateLimiter.isLockedOut();
      if (isLocked) {
        final remaining = await userProvider.rateLimiter.getLockoutRemaining();
        setState(() {
          _isLockedOut = true;
          _lockoutRemaining = remaining;
        });
        _startLockoutTimer();
      }
    }
  }

  /// Handle database reseed with confirmation and feedback
  Future<void> _handleReseedDatabase() async {
    // Step 1: Show confirmation dialog
    final confirmed = await _showReseedConfirmation();
    if (!confirmed) return;

    // Step 2: Show loading state
    setState(() => _isReseeding = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Reseeding database...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      // Step 3: Clear auth tokens first (user will need to re-login)
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.clearTokens();
      debugPrint('LoginScreen: Cleared auth tokens before reseed');

      // Step 4: Create SeedService and trigger reseed
      final seedService = await SeedService.create(
        userRepository: RepositoryConfig.getUserRepository(),
        sessionRepository: RepositoryConfig.getSessionRepository(),
        benefitRepository: RepositoryConfig.getBenefitRepository(),
      );

      await seedService.clearAndReseed();

      // Step 5: Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Database reset successfully!\nPlease log in again.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
    } catch (e, stackTrace) {
      debugPrint('Reseed error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(child: Text('Reset failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isReseeding = false);
      }
    }
  }

  /// Show confirmation dialog before reseeding
  Future<bool> _showReseedConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
        title: const Text('Reset Test Data?'),
        content: const Text(
          'This will:\n'
          '• Clear all database data\n'
          '• Repopulate with fresh test data\n'
          '• Log you out\n\n'
          'This is useful for testing.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),

                    // Logo
                    Center(
                      child: Image.asset(
                        'assets/images/logos/logo_launcher_round.webp',
                        width: 100,
                        height: 100,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // App name
                    Text(
                      'BeneFit',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Move More, Save More',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 48),

                    // Welcome text
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue tracking your activities',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enabled: !userProvider.isLoading,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        // Basic email validation
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !userProvider.isLoading,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
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
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: userProvider.isLoading
                            ? null
                            : () => Navigator.of(
                                context,
                              ).pushNamed('/forgot-password'),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lockout warning banner
                    if (_isLockedOut) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_clock,
                                  color: Colors.orange[700],
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Too many login attempts',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.timer,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Try again in ${_lockoutRemaining.inMinutes}:${(_lockoutRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Error message
                    if (userProvider.hasError && !_isLockedOut) ...[
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

                    // Login button
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: (userProvider.isLoading || _isLockedOut)
                            ? null
                            : _handleLogin,
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
                            : Text(
                                _isLockedOut ? 'Locked Out' : 'Sign In',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Test credentials hint — debug builds only, never shipped in release.
                    // The seeded test accounts only exist when seeding runs (kDebugMode),
                    // so this hint must not be visible to public/release users.
                    if (kDebugMode) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Test Credentials',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'User 1: test@gmail.com / 1234\nUser 2: test2@gmail.com / 1234',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Create account link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: userProvider.isLoading
                              ? null
                              : () {
                                  userProvider.clearError();
                                  Navigator.of(context).pushNamed('/register');
                                },
                          child: const Text('Create Account'),
                        ),
                      ],
                    ),

                    // Reset seed data button (debug only)
                    if (kDebugMode && SeedConfig.isEnabled) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: (_isReseeding || userProvider.isLoading)
                            ? null
                            : _handleReseedDatabase,
                        icon: _isReseeding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(
                          _isReseeding ? 'Resetting...' : 'Reset Test Data',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ],
                    const SizedBox(height: 48),
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
