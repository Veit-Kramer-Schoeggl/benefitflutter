import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/core/config/theme.dart';

/// Helper function to wrap widgets with MaterialApp and necessary providers for testing
///
/// Usage:
/// ```dart
/// await tester.pumpWidget(
///   createTestApp(
///     providers: [
///       ChangeNotifierProvider(create: (_) => BenefitProvider(mockRepo)),
///     ],
///     child: BenefitScreen(),
///   ),
/// );
/// ```
Widget createTestApp({
  required Widget child,
  List<ChangeNotifierProvider>? providers,
}) {
  Widget app = MaterialApp(theme: AppTheme.lightTheme, home: child);

  // Wrap with providers if provided
  if (providers != null && providers.isNotEmpty) {
    app = MultiProvider(providers: providers, child: app);
  }

  return app;
}

/// Pump a widget with the test app wrapper
/// Convenience method that combines pumpWidget with createTestApp
Future<void> pumpTestApp(
  WidgetTester tester, {
  required Widget child,
  List<ChangeNotifierProvider>? providers,
}) async {
  await tester.pumpWidget(createTestApp(child: child, providers: providers));
}
