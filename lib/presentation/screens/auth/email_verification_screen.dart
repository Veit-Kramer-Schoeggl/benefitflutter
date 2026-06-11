import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/user_provider.dart';
import 'package:benefitflutter/features/auth/widgets/auth_widgets.dart';

/// Email verification screen - enter 6-digit code
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Handle verify button press
  Future<void> _handleVerify() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Clear any previous errors
    final userProvider = context.read<UserProvider>();
    userProvider.clearError();

    // Attempt verification
    final success = await userProvider.verifyEmail(_codeController.text);

    if (success && mounted) {
      // Navigate to home on success
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  /// Handle back button - clear pending registration
  void _handleBack() {
    final userProvider = context.read<UserProvider>();
    userProvider.clearPendingRegistration();
    userProvider.clearError();
    Navigator.of(context).pop();
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
        child: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            // Redirect if no pending registration (and not just verified)
            if (userProvider.pendingRegistrationUserId == null &&
                !userProvider.isAuthenticated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/register');
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),

                    // Icon
                    const Center(
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 80,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Verify Your Email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 6-digit verification code',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 48),

                    // Code input field with mock code hint
                    VerificationCodeField(
                      controller: _codeController,
                      labelText: 'Verification Code',
                      enabled: !userProvider.isLoading,
                      mockCode: userProvider.pendingVerificationCode,
                      showMockCodeHint: true,
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

                    // Verify button
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: userProvider.isLoading
                            ? null
                            : _handleVerify,
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
                                'Verify',
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
              ),
            );
          },
        ),
      ),
    );
  }
}
