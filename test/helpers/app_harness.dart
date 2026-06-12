import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:benefitflutter/core/config/theme.dart';
import 'package:benefitflutter/core/router/app_router.dart';
import 'package:benefitflutter/features/shared/sensors/sensor_manager.dart';
import 'package:benefitflutter/providers/activity_provider.dart';
import 'package:benefitflutter/providers/app_lock_provider.dart';
import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/providers/benefit_provider.dart';
import 'package:benefitflutter/providers/connectivity_provider.dart';
import 'package:benefitflutter/providers/health_platform_provider.dart';
import 'package:benefitflutter/providers/profile_provider.dart';
import 'package:benefitflutter/providers/progress_provider.dart';

import 'auth_fakes.dart';
import 'benefit_fakes.dart';
import 'biometric_fakes.dart';
import 'connectivity_fakes.dart';
import 'health_fakes.dart';
import 'session_fakes.dart';
import '../mocks/mock_gps_sensor.dart';

const harnessUserId = 'test-user-1';

/// Handles to the fakes + providers behind a pumped routed app, so tests can
/// drive state (e.g. flip `authService.loginSucceeds`) and assert on it.
class AppHarness {
  final GoRouter router;
  final AuthProvider auth;
  final FakeAuthService authService;
  final FakeUserRepository userRepo;
  final FakeTokenStorage tokenStorage;
  final MockSessionRepository sessionRepo;
  final MockBenefitRepositoryForTest benefitRepo;
  final FakeConnectivityService connectivity;
  final FakeBiometricService biometric;
  final FakeHealthSyncService health;
  final MockGpsSensor gpsSensor;

  AppHarness({
    required this.router,
    required this.auth,
    required this.authService,
    required this.userRepo,
    required this.tokenStorage,
    required this.sessionRepo,
    required this.benefitRepo,
    required this.connectivity,
    required this.biometric,
    required this.health,
    required this.gpsSensor,
  });
}

/// Pump the FULL routed app (real go_router via [createAppRouter]) with every
/// provider backed by fakes — no SQLite/platform channels. Set
/// [authenticated] to seed a restored session (lands on /home/activity);
/// otherwise the redirect lands on /login.
///
/// Uses a phone-sized viewport to avoid the default 800x600 overflow.
Future<AppHarness> pumpApp(
  WidgetTester tester, {
  bool authenticated = false,
}) async {
  // Generous surface (reset on teardown) to avoid the default 800x600 layout
  // overflows when pumping full screens.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final userRepo = FakeUserRepository();
  final tokenStorage = FakeTokenStorage();
  final authService = FakeAuthService()..loginUserId = harnessUserId;

  if (authenticated) {
    userRepo.users[harnessUserId] = userFixture(id: harnessUserId);
    tokenStorage.stored = tokensFixture(userId: harnessUserId);
  }

  final auth = AuthProvider(
    repository: userRepo,
    authService: authService,
    tokenStorage: tokenStorage,
    rateLimiter: freshRateLimiter(),
  );
  if (authenticated) {
    await auth.initialize(); // restore session before pumping
  }

  final sessionRepo = MockSessionRepository();
  final benefitRepo = MockBenefitRepositoryForTest();
  final connectivity = FakeConnectivityService();
  final biometric = FakeBiometricService();
  final health = FakeHealthSyncService();
  final gpsSensor = MockGpsSensor();

  final router = createAppRouter(auth);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (_) => ProfileProvider(userRepo),
          update: (_, a, p) {
            p!.attachAuth(a);
            return p;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, BenefitProvider>(
          create: (_) => BenefitProvider(benefitRepo),
          update: (_, a, b) {
            b?.updateUserId(a.userId);
            return b!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>(
          create: (_) => ProgressProvider(sessionRepo),
          update: (_, a, p) {
            p?.updateUserId(a.userId);
            return p!;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider(connectivity),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ActivityProvider>(
          create: (_) => ActivityProvider(
            sessionRepo,
            sensorManager: SensorManager(gpsSensor: gpsSensor),
            gpsPointDao: FakeGpsPointDao(),
          ),
          update: (_, a, act) {
            act?.updateUserId(a.userId);
            return act!;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => HealthPlatformProvider(syncService: health),
        ),
        ChangeNotifierProvider(
          create: (_) => AppLockProvider(biometricService: biometric),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );

  return AppHarness(
    router: router,
    auth: auth,
    authService: authService,
    userRepo: userRepo,
    tokenStorage: tokenStorage,
    sessionRepo: sessionRepo,
    benefitRepo: benefitRepo,
    connectivity: connectivity,
    biometric: biometric,
    health: health,
    gpsSensor: gpsSensor,
  );
}

/// Pump in fixed steps until [finder] matches, with a hard cap so a missing
/// widget fails fast instead of hanging CI. Avoids `pumpAndSettle`, which never
/// settles over the splash spinner / other infinite animations.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 40,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'pumpUntilFound: "$finder" not found after $maxTries pumps',
  );
}
