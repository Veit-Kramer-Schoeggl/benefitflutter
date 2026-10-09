import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:benefitflutter/core/logging/app_logger.dart';

const Color _brandGreen = Color(0xFF71B33A);

/// Live OpenStreetMap view for the Activity screen.
///
/// Follows the running session's route (polyline + position dot). Without a
/// route it shows the device's idle position (one-shot lookups, shared by all
/// instances), otherwise a fallback centre. Decorative only: no gestures, no
/// keyboard focus.
///
/// GPS rule: only `GpsSensor` may call `Geolocator.getPositionStream` — the
/// plugin caches a single stream (geolocator_android.dart:169-171). Another
/// caller would make tracking run without its foreground service (or keep
/// that service alive after the session), so this widget never opens a stream
/// and never requests a permission.
class LiveLocationMap extends StatefulWidget {
  /// Stored points of the running session, oldest first (empty when idle).
  final List<LatLng> routePoints;

  /// Camera zoom level.
  final double zoom;

  /// Shows the "© OpenStreetMap contributors" attribution (OSM tile policy).
  final bool showAttribution;

  /// A session exists (tracking or paused). Idle lookups stop right at START,
  /// not only once the first route point is stored: on iOS one-shot fixes and
  /// errors share the tracking stream's handler, and on Android a second
  /// location-settings dialog could stack on top of the tracking one.
  final bool sessionActive;

  /// Network state; tiles that failed while offline are retried when it
  /// returns.
  final bool online;

  const LiveLocationMap({
    super.key,
    required this.routePoints,
    required this.zoom,
    this.showAttribution = false,
    this.sessionActive = false,
    this.online = true,
  });

  /// Test seam: blank in-memory tiles, no Geolocator calls and no timers.
  /// Defaults to true under `flutter test` (no network or plugins there).
  @visibleForTesting
  static bool testMode = _isFlutterTest();

  static bool _isFlutterTest() {
    try {
      return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  State<LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends State<LiveLocationMap>
    with WidgetsBindingObserver {
  /// Camera centre until any position is known: FH JOANNEUM Graz.
  static const LatLng _fallbackCenter = LatLng(47.0697, 15.4086);

  final MapController _mapController = MapController();

  /// Created once: without it TileLayer builds a new NetworkTileProvider (and
  /// HTTP client) on every rebuild, and this screen rebuilds every second while
  /// tracking. TileLayer disposes it together with the map.
  late final TileProvider _tileProvider = LiveLocationMap.testMode
      ? _BlankTileProvider()
      : NetworkTileProvider();

  late final MapOptions _mapOptions;

  /// flutter_map never re-requests a failed tile on its own (no eviction, and
  /// the HTTP retry only covers 503), so one network drop would leave grey
  /// squares until the app restarts. Emitting here reloads the visible tiles;
  /// tiles that already loaded come back from the cache.
  final StreamController<void> _tileReset = StreamController<void>.broadcast();
  bool _tileFailed = false;

  bool _mapReady = false;
  bool _appResumed = true;
  bool _tickerEnabled = true;
  bool _polling = false;

  /// End of the last session's route, shown until a newer idle fix arrives
  /// (so the camera doesn't jump back to the pre-session idle position).
  LatLng? _routeEnd;

  /// Where the dot sits and the camera points (null = nothing known yet).
  LatLng? get _position => widget.routePoints.isNotEmpty
      ? widget.routePoints.last
      : _routeEnd ?? _IdleLocation.position.value;

  @override
  void initState() {
    super.initState();
    _mapOptions = MapOptions(
      initialCenter: _position ?? _fallbackCenter,
      initialZoom: widget.zoom,
      interactionOptions: InteractionOptions(
        flags: InteractiveFlag.none,
        keyboardOptions: const KeyboardOptions.disabled(),
        cursorKeyboardRotationOptions: CursorKeyboardRotationOptions.disabled(),
      ),
      onMapReady: _onMapReady,
    );

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _IdleLocation.position.addListener(_onIdlePosition);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Offstage tabs of the shell's indexed stack (and screens covered by a
    // pushed route) have tickers disabled: no polling there.
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _updatePolling();
  }

  @override
  void didUpdateWidget(LiveLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // The list is a new instance on every build: compare length + last point.
    final oldRoute = oldWidget.routePoints;
    final route = widget.routePoints;
    final routeChanged =
        oldRoute.length != route.length ||
        (route.isNotEmpty && oldRoute.last != route.last);

    if (routeChanged) {
      if (route.isEmpty) _routeEnd = oldRoute.last; // session ended
      _follow();
    } else if (oldWidget.zoom != widget.zoom) {
      _follow();
    }
    if (widget.online && !oldWidget.online) _retryFailedTiles();
    _updatePolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed) _retryFailedTiles();
    _updatePolling(); // resuming refreshes the idle position
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _IdleLocation.position.removeListener(_onIdlePosition);
    if (_polling) _IdleLocation.release();
    _mapController.dispose();
    _tileReset.close();
    super.dispose();
  }

  void _retryFailedTiles() {
    if (!_tileFailed || _tileReset.isClosed) return;
    _tileFailed = false;
    _tileReset.add(null);
  }

  void _onMapReady() {
    if (!mounted) return;
    _mapReady = true;
    _follow();
  }

  /// A newer idle fix arrived (shared by all instances).
  void _onIdlePosition() {
    if (!mounted) return;
    setState(() => _routeEnd = null);
    if (widget.routePoints.isEmpty) _follow();
  }

  /// Centre the camera on the current target. Only after onMapReady: the
  /// controller cannot move before the map has been laid out.
  void _follow() {
    if (!_mapReady) return;
    _mapController.move(_position ?? _fallbackCenter, widget.zoom);
  }

  /// Hold a reference on the shared idle-position polling only while it is
  /// useful and visible: no session, app resumed, tab on screen.
  void _updatePolling() {
    final wanted =
        !LiveLocationMap.testMode &&
        !widget.sessionActive &&
        widget.routePoints.isEmpty &&
        _appResumed &&
        _tickerEnabled;
    if (wanted == _polling) return;

    _polling = wanted;
    if (wanted) {
      _IdleLocation.acquire();
    } else {
      _IdleLocation.release();
    }
  }

  Future<void> _openCopyright() async {
    try {
      await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      AppLogger.d(
        'LiveLocationMap: could not open the OSM copyright page - $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.routePoints;
    final position = _position;

    return ExcludeFocus(
      child: FlutterMap(
        mapController: _mapController,
        options: _mapOptions,
        children: [
          // OpenStreetMap tiles (identified by the applicationId, OSM policy)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'us.benefit4.benefitflutter',
            tileProvider: _tileProvider,
            errorTileCallback: (_, _, _) => _tileFailed = true,
            reset: _tileReset.stream,
          ),

          // Route of the running session
          if (route.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: route,
                  strokeWidth: 5,
                  color: _brandGreen,
                  borderStrokeWidth: 4,
                  borderColor: Colors.white,
                ),
              ],
            ),

          // Current position
          if (position != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: position,
                  width: 18,
                  height: 18,
                  child: const _PositionDot(),
                ),
              ],
            ),

          // Always-visible attribution; small and clear of rounded corners.
          if (widget.showAttribution)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 11),
                child: SimpleAttributionWidget(
                  source: const Text('OpenStreetMap contributors'),
                  onTap: _openCopyright,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Position marker: brand-green dot with a white ring and a soft shadow.
class _PositionDot extends StatelessWidget {
  const _PositionDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _brandGreen,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Test tiles: transparent in-memory images (no network, no disk cache).
class _BlankTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

/// Idle position shared by all [LiveLocationMap]s, so the two maps on the
/// Activity screen don't double the GPS requests. Polls with one-shot lookups
/// while at least one map holds a reference (ref-counted).
abstract final class _IdleLocation {
  static final ValueNotifier<LatLng?> position = ValueNotifier<LatLng?>(null);

  static const Duration _interval = Duration(seconds: 20);

  /// After a failed fresh fix (e.g. a timeout indoors) wait before asking
  /// again, instead of re-asking on every resume.
  static const Duration _failureCooldown = Duration(minutes: 2);

  /// On Android the platform LocationManager answers the fresh fix: the fused
  /// client would first run a settings check that can open the system
  /// "location accuracy" dialog (geolocator_android FusedLocationClient.java
  /// :237-257). The LocationManager client never shows a dialog.
  static LocationSettings get _settings =>
      defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
          forceLocationManager: true,
        )
      : const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        );

  static int _users = 0;
  static Timer? _timer;
  static bool _refreshing = false;
  static DateTime? _fixTime;
  static DateTime? _retryAfter;

  static void acquire() {
    _users++;
    if (_users > 1) return;
    _timer = Timer.periodic(_interval, (_) => unawaited(_refresh()));
    unawaited(_refresh());
  }

  static void release() {
    if (_users == 0) return;
    _users--;
    if (_users > 0) return;
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      // Read-only checks: permissions are only ever requested by GpsSensor.
      if (await _try(Geolocator.isLocationServiceEnabled) != true) return;
      final permission = await _try(Geolocator.checkPermission);
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }

      final lastKnown = await _try(Geolocator.getLastKnownPosition); // instant
      _apply(lastKnown);

      final retryAfter = _retryAfter;
      if (_users == 0 ||
          (retryAfter != null && DateTime.now().isBefore(retryAfter))) {
        return;
      }
      final current = await _try(
        () => Geolocator.getCurrentPosition(locationSettings: _settings),
      );
      if (current == null) {
        _retryAfter = DateTime.now().add(_failureCooldown);
      }
      _apply(current);
    } finally {
      _refreshing = false;
    }
  }

  /// Publish [fix] unless an equally fresh or newer fix is already shown.
  static void _apply(Position? fix) {
    if (fix == null) return;
    final shown = _fixTime;
    if (shown != null && !fix.timestamp.isAfter(shown)) return;
    _fixTime = fix.timestamp;
    position.value = LatLng(fix.latitude, fix.longitude);
  }

  /// One-shot Geolocator call; null on any error (permission or services
  /// changed, timeout, plugin missing).
  static Future<T?> _try<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      AppLogger.d('LiveLocationMap: location lookup failed - $e');
      return null;
    }
  }
}
