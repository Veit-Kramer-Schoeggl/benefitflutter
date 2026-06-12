import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/presentation/screens/splash/splash_screen.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  testWidgets('shows a loader and triggers AuthProvider.initialize()', (
    tester,
  ) async {
    final auth = AuthProvider(
      repository: FakeUserRepository(),
      authService: FakeAuthService(),
      tokenStorage: FakeTokenStorage(),
      rateLimiter: freshRateLimiter(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const SplashScreen(),
        ),
      ),
    );

    // Loader visible immediately.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The postFrame callback runs AuthProvider.initialize().
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(auth.isInitialized, isTrue);
  });
}
