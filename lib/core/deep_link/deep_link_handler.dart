import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

/// Handles deep links for the BeneFit app
///
/// Supports:
/// - benefit://reset-password?token=xxx
class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> navigatorKey;

  DeepLinkHandler({required this.navigatorKey});

  /// Initialize deep link handling
  ///
  /// Call this early in app startup to catch links that launched the app.
  Future<void> initialize() async {
    // Handle link when app is started from terminated state (cold start)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink);
      }
    } catch (e) {
      debugPrint('DeepLinkHandler: Error getting initial link - $e');
    }

    // Handle links when app is already running (warm start)
    _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (error) {
        debugPrint('DeepLinkHandler: Stream error - $error');
      },
    );
  }

  /// Process a deep link URI
  void _handleLink(Uri uri) {
    debugPrint('DeepLinkHandler: Received link - $uri');

    // Only handle our custom scheme
    if (uri.scheme != 'benefit') {
      debugPrint('DeepLinkHandler: Ignoring non-benefit scheme - ${uri.scheme}');
      return;
    }

    switch (uri.host) {
      case 'reset-password':
        final token = uri.queryParameters['token'];
        debugPrint('DeepLinkHandler: Navigating to reset-password with token: $token');
        if (token != null && token.isNotEmpty) {
          navigatorKey.currentState?.pushNamed(
            '/reset-password',
            arguments: {'token': token},
          );
        } else {
          // No token - still navigate to reset screen
          navigatorKey.currentState?.pushNamed('/reset-password');
        }
        break;
      default:
        debugPrint('DeepLinkHandler: Unknown host - ${uri.host}');
    }
  }
}
