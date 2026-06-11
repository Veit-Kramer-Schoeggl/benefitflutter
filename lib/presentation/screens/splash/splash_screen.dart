import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/auth_provider.dart';

/// Splash screen - pure loading screen shown while the session is restored.
///
/// Navigation is handled declaratively by the go_router redirect + the
/// AuthProvider `refreshListenable`: once [AuthProvider.initialize] completes
/// (`isInitialized` flips), the router moves the user to /home or /login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final String _status = 'Loading...';

  @override
  void initState() {
    super.initState();
    // Trigger session restore exactly once (idempotent). The redirect reacts
    // to the resulting notifyListeners and routes away from /splash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF78BA3F), // Brand green
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo
              Image.asset(
                'assets/images/logos/logo_launcher_round.webp',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),

              // App name
              const Text(
                'BeneFit',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Tagline
              const Text(
                'Move More, Save More',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),

              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),

              // Status text
              Text(
                _status,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
