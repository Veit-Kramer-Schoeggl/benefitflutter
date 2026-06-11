import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:benefitflutter/features/shared/utils/connectivity_service.dart';

/// Provider wrapper for ConnectivityService
///
/// Exposes connectivity status to UI via ChangeNotifier.
/// Automatically monitors network state changes and notifies listeners.
///
/// Usage:
/// ```dart
/// Consumer<ConnectivityProvider>(
///   builder: (context, connectivity, child) {
///     return Icon(
///       connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
///       color: connectivity.isOnline ? Colors.green : Colors.red,
///     );
///   },
/// )
/// ```
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService;

  bool _isOnline = false;
  StreamSubscription<bool>? _subscription;

  /// Constructor takes a ConnectivityService instance
  ConnectivityProvider(this._connectivityService) {
    _initialize();
  }

  /// Returns true if device is currently online
  bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  ///
  /// Gets initial online/offline state and subscribes to changes
  Future<void> _initialize() async {
    // Get initial state
    _isOnline = await _connectivityService.isOnline();
    notifyListeners();

    // Listen to connectivity changes
    _subscription = _connectivityService.onConnectivityChanged.listen((
      isOnline,
    ) {
      _isOnline = isOnline;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectivityService.dispose();
    super.dispose();
  }
}
