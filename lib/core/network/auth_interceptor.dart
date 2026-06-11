import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/token_storage.dart';
import '../../features/auth/data/auth_service.dart';

/// Callback type for when auth fails completely (needs re-login)
typedef OnAuthFailure = void Function();

/// Dio interceptor for automatic authentication handling
///
/// - Attaches Bearer token to all requests
/// - Auto-refreshes expired tokens
/// - Handles 401 responses
/// - Triggers logout callback on auth failure
class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final AuthService _authService;
  final OnAuthFailure? onAuthFailure;

  /// Paths that should not have auth headers
  final List<String> excludedPaths;

  /// Whether a token refresh is currently in progress
  bool _isRefreshing = false;

  AuthInterceptor({
    required TokenStorage tokenStorage,
    required AuthService authService,
    this.onAuthFailure,
    this.excludedPaths = const ['/auth/login', '/auth/register'],
  }) : _tokenStorage = tokenStorage,
       _authService = authService;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for excluded paths
    if (_isExcludedPath(options.path)) {
      handler.next(options);
      return;
    }

    try {
      // Check if we need to refresh token before making request
      final tokens = await _tokenStorage.getTokens();

      if (tokens == null) {
        // No tokens - proceed without auth
        handler.next(options);
        return;
      }

      // Check if token needs refresh
      if (tokens.needsRefresh && !_isRefreshing) {
        await _refreshTokenIfNeeded(tokens.refreshToken);
      }

      // Get (possibly refreshed) access token
      final accessToken = await _tokenStorage.getAccessToken();
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }

      handler.next(options);
    } catch (e) {
      debugPrint('AuthInterceptor: Error in onRequest - $e');
      handler.next(options);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized
    if (err.response?.statusCode == 401) {
      // Skip if this is already a refresh request or excluded path
      if (_isExcludedPath(err.requestOptions.path) || _isRefreshing) {
        handler.next(err);
        return;
      }

      try {
        final tokens = await _tokenStorage.getTokens();
        if (tokens == null) {
          _handleAuthFailure();
          handler.next(err);
          return;
        }

        // Try to refresh token
        final newTokens = await _refreshTokenIfNeeded(tokens.refreshToken);
        if (newTokens != null) {
          // Retry the original request with new token
          final response = await _retryRequest(err.requestOptions);
          handler.resolve(response);
          return;
        }
      } catch (e) {
        debugPrint('AuthInterceptor: Failed to refresh token - $e');
        _handleAuthFailure();
      }
    }

    handler.next(err);
  }

  /// Check if path is excluded from auth
  bool _isExcludedPath(String path) {
    return excludedPaths.any((excluded) => path.contains(excluded));
  }

  /// Refresh token if needed, with mutex to prevent multiple simultaneous refreshes
  Future<dynamic> _refreshTokenIfNeeded(String refreshToken) async {
    if (_isRefreshing) {
      // Wait for ongoing refresh
      await Future.delayed(const Duration(milliseconds: 100));
      return _tokenStorage.getTokens();
    }

    _isRefreshing = true;
    try {
      debugPrint('AuthInterceptor: Refreshing token...');
      final newTokens = await _authService.refreshToken(refreshToken);
      await _tokenStorage.saveTokens(newTokens);
      debugPrint('AuthInterceptor: Token refreshed successfully');
      return newTokens;
    } on AuthException catch (e) {
      debugPrint('AuthInterceptor: Refresh failed - ${e.message}');
      _handleAuthFailure();
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Retry a failed request with updated token
  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    final accessToken = await _tokenStorage.getAccessToken();
    final options = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $accessToken',
      },
    );

    return Dio().request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  /// Handle auth failure (clear tokens and trigger callback)
  void _handleAuthFailure() {
    debugPrint('AuthInterceptor: Auth failure - triggering logout');
    _tokenStorage.clearTokens();
    onAuthFailure?.call();
  }
}
