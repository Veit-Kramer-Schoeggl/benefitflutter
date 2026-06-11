import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/core/config/theme.dart';
import 'package:benefitflutter/core/config/repository_config.dart';
import 'package:benefitflutter/core/seed/seed_service.dart';
import 'package:benefitflutter/core/seed/seed_config.dart';
import 'package:benefitflutter/presentation/screens/splash/splash_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/login_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/register_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/email_verification_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/forgot_password_screen.dart';
import 'package:benefitflutter/presentation/screens/auth/reset_password_screen.dart';
import 'package:benefitflutter/presentation/screens/security/app_lock_screen.dart';
import 'package:benefitflutter/presentation/navigation/main_navigation.dart';
import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/providers/profile_provider.dart';
import 'package:benefitflutter/providers/benefit_provider.dart';
import 'package:benefitflutter/providers/progress_provider.dart';
import 'package:benefitflutter/providers/connectivity_provider.dart';
import 'package:benefitflutter/providers/activity_provider.dart';
import 'package:benefitflutter/providers/health_platform_provider.dart';
import 'package:benefitflutter/providers/app_lock_provider.dart';
import 'package:benefitflutter/features/shared/utils/connectivity_service.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_manager.dart';
import 'package:benefitflutter/features/auth/data/auth_service.dart';
import 'package:benefitflutter/features/auth/data/token_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:benefitflutter/core/deep_link/deep_link_handler.dart';
import 'package:benefitflutter/core/logging/app_logger.dart';
import 'package:benefitflutter/core/config/app_config.dart';

/// Global navigator key for deep link navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Catch-all guard for async errors that escape the framework handlers.
  runZonedGuarded(() async {
    // Bindings first — before any async/Sentry work, in the SAME zone as runApp.
    final binding = WidgetsFlutterBinding.ensureInitialized();
    AppLogger.init();

    // Global error handlers (Sentry chains onto FlutterError.onError later).
    FlutterError.onError = (details) {
      AppLogger.e(
        'FlutterError: ${details.exceptionAsString()}',
        details.exception,
        details.stack,
      );
    };
    binding.platformDispatcher.onError = (error, stack) {
      AppLogger.e('Uncaught platform error', error, stack);
      return true;
    };
    ErrorWidget.builder = (details) {
      if (kReleaseMode) {
        return const Material(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Etwas ist schiefgelaufen. Bitte starte die App neu.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      return ErrorWidget(details.exception);
    };

    // Crash reporting is opt-in via --dart-define=SENTRY_DSN=...; without a
    // DSN nothing is sent (no network, GDPR-safe for local/dev/CI builds).
    final dsn = AppConfig.sentryDsn;
    if (dsn.isEmpty) {
      await _bootstrap();
    } else {
      AppLogger.enableSentry();
      await SentryFlutter.init((options) {
        options.dsn = dsn;
        options.environment = AppConfig.sentryEnv;
        options.sendDefaultPii = false;
        options.tracesSampleRate = 0.0;
        options.beforeSend = _scrubSentryEvent;
      }, appRunner: _bootstrap);
    }
  }, (error, stack) => AppLogger.e('Uncaught zone error', error, stack));
}

/// Redact PII from breadcrumb messages before any event leaves the device.
/// (sendDefaultPii=false already prevents user/IP/request collection.)
SentryEvent? _scrubSentryEvent(SentryEvent event, Hint hint) {
  final crumbs = event.breadcrumbs;
  if (crumbs == null) return event;
  return event.copyWith(
    breadcrumbs: [
      for (final b in crumbs)
        b.message == null
            ? b
            : b.copyWith(message: AppLogger.redact(b.message!)),
    ],
  );
}

/// App initialization + runApp. Shared by the no-Sentry path and (later) Sentry's appRunner.
Future<void> _bootstrap() async {
  // Seed database with test data in debug mode
  if (SeedConfig.isEnabled) {
    try {
      final seedService = await SeedService.create(
        userRepository: RepositoryConfig.getUserRepository(),
        sessionRepository: RepositoryConfig.getSessionRepository(),
        benefitRepository: RepositoryConfig.getBenefitRepository(),
      );
      await seedService.seedIfNeeded();
    } catch (e, s) {
      // Don't block app startup on seed failure
      AppLogger.e('Failed to seed database', e, s);
    }
  }

  // Initialize sensor manager
  final sensorManager = SensorManager();
  await sensorManager.initialize();

  // Initialize auth dependencies. The mock auth service authenticates against
  // the durable user repository (same SQLite DB as AuthProvider) so password
  // changes/resets/registrations survive a process restart.
  final tokenStorage = SecureTokenStorage();
  final authService = MockAuthService(
    userRepository: RepositoryConfig.getUserRepository(),
  );

  // Initialize deep link handler
  final deepLinkHandler = DeepLinkHandler(navigatorKey: navigatorKey);
  await deepLinkHandler.initialize();

  runApp(
    // MultiProvider wraps the app to provide state management
    MultiProvider(
      providers: [
        // Auth Provider - MUST BE FIRST - identity, sessions, account flows
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            repository: RepositoryConfig.getUserRepository(),
            authService: authService,
            tokenStorage: tokenStorage,
          ),
        ),
        // Profile Provider - editable profile data; reads identity from AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (_) => ProfileProvider(RepositoryConfig.getUserRepository()),
          update: (_, authProvider, profileProvider) {
            profileProvider!.attachAuth(authProvider);
            return profileProvider;
          },
        ),
        // Benefit Provider - receives userId from AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, BenefitProvider>(
          create: (_) =>
              BenefitProvider(RepositoryConfig.getBenefitRepository()),
          update: (_, authProvider, benefitProvider) {
            benefitProvider?.updateUserId(authProvider.userId);
            return benefitProvider!;
          },
        ),
        // Progress Provider - receives userId from AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>(
          create: (_) =>
              ProgressProvider(RepositoryConfig.getSessionRepository()),
          update: (_, authProvider, progressProvider) {
            progressProvider?.updateUserId(authProvider.userId);
            return progressProvider!;
          },
        ),
        // Connectivity Provider - monitors network connectivity status
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider(ConnectivityService()),
        ),
        // Activity Provider - receives userId from AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, ActivityProvider>(
          create: (_) => ActivityProvider(
            RepositoryConfig.getSessionRepository(),
            sensorManager: sensorManager,
          ),
          update: (_, authProvider, activityProvider) {
            activityProvider?.updateUserId(authProvider.userId);
            return activityProvider!;
          },
        ),
        // Health Platform Provider - manages health platform integration
        ChangeNotifierProvider(create: (_) => HealthPlatformProvider()),
        // App Lock Provider - manages biometric app lock
        ChangeNotifierProvider(create: (_) => AppLockProvider()),
      ],
      child: const BeneFitApp(),
    ),
  );
}

/// Root application widget with lifecycle observer
class BeneFitApp extends StatefulWidget {
  const BeneFitApp({super.key});

  @override
  State<BeneFitApp> createState() => _BeneFitAppState();
}

class _BeneFitAppState extends State<BeneFitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize app lock provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppLockProvider>().initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appLockProvider = context.read<AppLockProvider>();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App going to background
        appLockProvider.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground
        _handleAppResumed();
        break;
      default:
        break;
    }
  }

  Future<void> _handleAppResumed() async {
    final appLockProvider = context.read<AppLockProvider>();
    final authProvider = context.read<AuthProvider>();

    // Only check lock if user is authenticated
    if (!authProvider.isAuthenticated) return;

    // Check if activity tracking is active (don't lock during tracking)
    final activityProvider = context.read<ActivityProvider>();
    final isTracking = activityProvider.isTracking || activityProvider.isPaused;

    await appLockProvider.onAppResumed(isTrackingActive: isTracking);
  }

  void _handlePasswordRequired() {
    // Navigate to login screen and reset lock state after successful login
    final appLockProvider = context.read<AppLockProvider>();
    final authProvider = context.read<AuthProvider>();

    // Logout and go to login screen
    authProvider.logout();
    appLockProvider.reset();
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLockProvider>(
      builder: (context, appLockProvider, child) {
        return MaterialApp(
          // Navigator key for deep link handling
          navigatorKey: navigatorKey,

          // App metadata
          title: 'BeneFit',
          debugShowCheckedModeBanner: false,

          // Theme
          theme: AppTheme.lightTheme,

          // Show lock screen overlay when locked
          builder: (context, child) {
            if (appLockProvider.isLocked) {
              return AppLockScreen(onPasswordRequired: _handlePasswordRequired);
            }
            return child ?? const SizedBox.shrink();
          },

          // Routing configuration
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/verify': (context) => const EmailVerificationScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/reset-password': (context) => const ResetPasswordScreen(),
            '/home': (context) => const MainNavigationScreen(),
          },

          // Handle unknown routes
          onUnknownRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
