import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:benefitflutter/providers/auth_provider.dart';

/// Handles deep links for the BeneFit app
///
/// Supports:
/// - benefit://reset-password?token=xxx
///
/// Navigates via [GoRouter]. Cold-start links are buffered until the session
/// has been restored ([AuthProvider.isInitialized]), otherwise the router's
/// boot redirect ("not initialized → /splash") would discard the target.
class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();
  final GoRouter router;
  final AuthProvider authProvider;

  Uri? _pendingLink;

  DeepLinkHandler({required this.router, required this.authProvider});

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
    // Do not log the full URI: it can carry secrets (e.g. password-reset token).
    debugPrint(
      'DeepLinkHandler: Received link - scheme=${uri.scheme} host=${uri.host}',
    );

    // Only handle our custom scheme
    if (uri.scheme != 'benefit') {
      debugPrint(
        'DeepLinkHandler: Ignoring non-benefit scheme - ${uri.scheme}',
      );
      return;
    }

    // Cold start: defer until the session restore finished, so the router's
    // boot redirect doesn't bounce us back to /splash and lose the link.
    if (!authProvider.isInitialized) {
      _pendingLink = uri;
      void replay() {
        if (authProvider.isInitialized) {
          authProvider.removeListener(replay);
          final pending = _pendingLink;
          _pendingLink = null;
          if (pending != null) _navigate(pending);
        }
      }

      authProvider.addListener(replay);
      return;
    }

    _navigate(uri);
  }

  void _navigate(Uri uri) {
    switch (uri.host) {
      case 'reset-password':
        final token = uri.queryParameters['token'];
        // Never log the reset token itself; only whether one is present.
        debugPrint(
          'DeepLinkHandler: Navigating to reset-password (token present: ${token != null && token.isNotEmpty})',
        );
        // Token via `extra` keeps it out of the URL/route history.
        router.go('/reset-password', extra: token);
        break;
      default:
        debugPrint('DeepLinkHandler: Unknown host - ${uri.host}');
    }
  }
}
