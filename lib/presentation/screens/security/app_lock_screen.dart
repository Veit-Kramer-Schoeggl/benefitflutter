import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/app_lock_provider.dart';
import 'package:benefitflutter/features/security/services/biometric_service.dart';

/// Full-screen lock overlay when biometric authentication is required
///
/// Shows app logo, biometric unlock button, and handles authentication flow.
/// If biometric fails too many times, shows password fallback option.
class AppLockScreen extends StatefulWidget {
  /// Callback when user requests password login
  final VoidCallback? onPasswordRequired;

  const AppLockScreen({super.key, this.onPasswordRequired});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;
  AppBiometricType _biometricType = AppBiometricType.none;

  @override
  void initState() {
    super.initState();
    _loadBiometricType();
    // Automatically trigger biometric prompt on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _loadBiometricType() async {
    final appLockProvider = context.read<AppLockProvider>();
    final type = await appLockProvider.biometricService
        .getPrimaryBiometricType();
    if (mounted) {
      setState(() {
        _biometricType = type;
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final appLockProvider = context.read<AppLockProvider>();
    final success = await appLockProvider.unlockWithBiometrics();

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        if (!success && !appLockProvider.isPermanentlyLocked) {
          final remaining = appLockProvider.remainingAttempts;
          if (remaining > 0) {
            _errorMessage =
                'Authentication failed. $remaining attempts remaining.';
          }
        }
      });
    }
  }

  String _getBiometricIcon() {
    switch (_biometricType) {
      case AppBiometricType.faceId:
        return 'Face ID';
      case AppBiometricType.fingerprint:
        return 'Fingerprint';
      case AppBiometricType.iris:
        return 'Iris';
      case AppBiometricType.none:
        return 'Biometric';
    }
  }

  IconData _getBiometricIconData() {
    switch (_biometricType) {
      case AppBiometricType.faceId:
        return Icons.face;
      case AppBiometricType.fingerprint:
        return Icons.fingerprint;
      case AppBiometricType.iris:
        return Icons.remove_red_eye;
      case AppBiometricType.none:
        return Icons.lock;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLockProvider>(
      builder: (context, appLockProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // App logo
                  Image.asset(
                    'assets/images/logos/logo_launcher_round.webp',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 24),

                  // App name
                  Text(
                    'BeneFit',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Lock message
                  Text(
                    'App Locked',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),

                  const Spacer(),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Permanently locked message
                  if (appLockProvider.isPermanentlyLocked) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.lock, color: Colors.orange[700], size: 32),
                          const SizedBox(height: 12),
                          Text(
                            'Biometric authentication unavailable',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please log in with your password to continue.',
                            style: TextStyle(color: Colors.orange[700]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Password login button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: widget.onPasswordRequired,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Log In with Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Biometric unlock button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _isAuthenticating ? null : _authenticate,
                        icon: _isAuthenticating
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
                            : Icon(_getBiometricIconData(), size: 28),
                        label: Text(
                          _isAuthenticating
                              ? 'Authenticating...'
                              : 'Unlock with ${_getBiometricIcon()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Use password instead
                    TextButton(
                      onPressed: widget.onPasswordRequired,
                      child: const Text('Use Password Instead'),
                    ),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
