import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity status
///
/// Responsibilities:
/// - Check current online/offline status
/// - Stream connectivity changes
/// - Notify listeners when network becomes available
///
/// Usage:
/// ```dart
/// final connectivity = ConnectivityService();
/// final isOnline = await connectivity.isOnline();
///
/// connectivity.onConnectivityChanged.listen((isOnline) {
///   if (isOnline) {
///     // Trigger sync queue processing
///   }
/// });
/// ```
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectivityController;

  /// Stream of connectivity changes (true = online, false = offline)
  Stream<bool> get onConnectivityChanged {
    _connectivityController ??= StreamController<bool>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
    return _connectivityController!.stream;
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Start listening to connectivity changes
  void _startListening() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = _isConnected(results);
      _connectivityController?.add(isOnline);
    });
  }

  /// Stop listening to connectivity changes
  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Check if device is currently online
  ///
  /// Returns true if connected to wifi, mobile, or ethernet
  /// Returns false if no connection or only bluetooth
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _isConnected(results);
    } catch (e) {
      // If check fails, assume offline
      return false;
    }
  }

  /// Check if connectivity results indicate online status
  ///
  /// Supports multiple simultaneous connections (e.g., WiFi + Ethernet)
  /// Returns true if ANY connection is active
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet,
    );
  }

  /// Dispose of resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController?.close();
  }
}
