import 'dart:async';

import 'package:benefitflutter/features/shared/utils/connectivity_service.dart';

/// In-memory [ConnectivityService] for tests. Defaults to online; use
/// [setOnline] to drive online/offline transitions on the stream.
class FakeConnectivityService implements ConnectivityService {
  bool _isOnline;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  FakeConnectivityService({bool online = true}) : _isOnline = online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> isOnline() async => _isOnline;

  @override
  void dispose() => _controller.close();

  /// Emit a connectivity change.
  void setOnline(bool online) {
    _isOnline = online;
    _controller.add(online);
  }
}
