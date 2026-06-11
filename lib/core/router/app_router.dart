import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:benefitflutter/core/logging/app_logger.dart';
import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/features/benefit/domain/benefit_view_model.dart';

import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/presentation/screens/splash/splash_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/login_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/register_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/email_verification_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/forgot_password_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/reset_password_screen.dart';
import 'package:benefitflutter/presentation/screens/community/community_screen.dart';
import 'package:benefitflutter/presentation/screens/progress/progress_screen.dart';
import 'package:benefitflutter/presentation/screens/activity/activity_screen.dart';
import 'package:benefitflutter/presentation/screens/benefit/benefit_screen.dart';
import 'package:benefitflutter/presentation/screens/profile/profile_screen.dart';
import 'package:benefitflutter/presentation/screens/session/session_detail_screen.dart';
import 'package:benefitflutter/presentation/screens/wearable/device_connection_screen.dart';
import 'package:benefitflutter/presentation/screens/wearable/device_pairing_screen.dart';
import 'package:benefitflutter/presentation/screens/benefit/benefit_qr_screen.dart';

/// Root navigator key — full-screen pushes (session/device/benefit-qr) run here
/// so they cover the bottom navigation bar, matching the old MaterialPageRoute
/// behaviour. Also used to dismiss imperative dialogs on forced logout.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final _communityKey = GlobalKey<NavigatorState>();
final _progressKey = GlobalKey<NavigatorState>();
final _activityKey = GlobalKey<NavigatorState>();
final _benefitKey = GlobalKey<NavigatorState>();
final _profileKey = GlobalKey<NavigatorState>();

/// Routes reachable while unauthenticated.
const _authArea = {
  '/login',
  '/register',
  '/verify',
  '/forgot-password',
  '/reset-password',
};

/// Central auth redirect. Sync (the async session restore happens in
/// [AuthProvider.initialize], triggered by the splash loader); `refreshListenable`
/// re-runs this when auth state changes so splash flips to login/home.
String? _redirect(AuthProvider auth, GoRouterState state) {
  final loc = state.matchedLocation;

  // Booting: hold on splash until the stored session has been restored.
  if (!auth.isInitialized) {
    return loc == '/splash' ? null : '/splash';
  }

  final authed = auth.isAuthenticated;

  if (loc == '/splash') {
    return authed ? '/home/activity' : '/login';
  }

  // Unauthenticated users may only be in the auth area.
  if (!authed && !_authArea.contains(loc)) {
    return '/login';
  }

  // Authenticated user sitting on login → home. (Do NOT bounce /verify or
  // /reset-password: a just-verified user is briefly authed there.)
  if (authed && loc == '/login') {
    return '/home/activity';
  }

  return null;
}

/// Builds the app's [GoRouter]. [authProvider] is injected (not looked up via
/// context) so the redirect works during boot when no context is available.
GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) => _redirect(authProvider, state),
    errorBuilder: (context, state) {
      // Surface unknown routes; fall back to splash (which then redirects).
      AppLogger.e('Router: unknown route ${state.uri}');
      return const SplashScreen();
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),

      // ----- Auth area (root navigator) -----
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, _) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          // Deep-link token via extra (kept out of the URL history), with a
          // ?token= query fallback.
          token: (state.extra as String?) ?? state.uri.queryParameters['token'],
        ),
      ),

      // ----- Home: 5-tab indexed stack -----
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MainNavigationScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _communityKey,
            routes: [
              GoRoute(
                path: '/home/community',
                builder: (_, _) => const CommunityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _progressKey,
            routes: [
              GoRoute(
                path: '/home/progress',
                builder: (_, _) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _activityKey,
            routes: [
              GoRoute(
                path: '/home/activity',
                builder: (_, _) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _benefitKey,
            routes: [
              GoRoute(
                path: '/home/benefit',
                builder: (_, _) => const BenefitScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileKey,
            routes: [
              GoRoute(
                path: '/home/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ----- Full-screen pushes on the root navigator -----
      GoRoute(
        path: '/session/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            SessionDetailScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/device-connection',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DeviceConnectionScreen(),
      ),
      GoRoute(
        path: '/device-pairing',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DevicePairingScreen(),
      ),
      GoRoute(
        path: '/benefit-qr',
        parentNavigatorKey: rootNavigatorKey,
        // extra (the view model) is lost on process-restart → builder handles null.
        builder: (_, state) =>
            BenefitQrScreen(benefitVM: state.extra as BenefitViewModel?),
      ),
    ],
  );
}
