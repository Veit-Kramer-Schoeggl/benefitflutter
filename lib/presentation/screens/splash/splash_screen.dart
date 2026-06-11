import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/auth_provider.dart';

/// Splash screen - shows loading animation and checks authentication
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  /// Check authentication status and navigate to appropriate screen
  Future<void> _checkAuthAndNavigate() async {
    try {
      // Step 1: Show initial status
      setState(() => _status = 'Loading...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 2: Initialize AuthProvider (checks for stored session)
      setState(() => _status = 'Checking session...');
      if (!mounted) return;
      final userProvider = context.read<AuthProvider>();
      await userProvider.initialize();

      // Step 3: Navigate based on auth status
      if (!mounted) return;
      final isAuthenticated = userProvider.isAuthenticated;

      if (isAuthenticated) {
        setState(
          () => _status =
              'Welcome back, ${userProvider.currentUser?.name ?? 'User'}!',
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Navigate to appropriate screen (fire-and-forget route future)
      if (!mounted) return;
      unawaited(
        Navigator.of(
          context,
        ).pushReplacementNamed(isAuthenticated ? '/home' : '/login'),
      );
    } catch (e) {
      // Handle errors
      debugPrint('SplashScreen error: $e');
      setState(() => _status = 'Error: $e');
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // On error, go to login screen (fire-and-forget route future)
        unawaited(Navigator.of(context).pushReplacementNamed('/login'));
      }
    }
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
