import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:benefitflutter/core/config/gps_tracking_config.dart';
import 'package:benefitflutter/core/config/repository_config.dart';
import 'package:benefitflutter/core/config/theme.dart';
import 'package:benefitflutter/features/session/data/session_repository.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/session/data/gps_point_dao.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  /// Optional injected dependencies — default to the production
  /// [RepositoryConfig]/[GpsPointDao]/network tiles so the route is unchanged;
  /// tests pass fakes to make the screen widget-testable.
  final SessionRepository? repository;
  final GpsPointDao? gpsPointDao;
  final TileProvider? tileProvider;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    this.repository,
    this.gpsPointDao,
    this.tileProvider,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final Color brandGreen = const Color(0xFF71B33A);

  bool _isLoading = true;
  String? _error;

  Session? _session;
  List<GpsPoint> _gpsPoints = [];

  late final SessionRepository _sessionRepository;
  late final GpsPointDao _gpsPointDao;

  /// Created once: without it TileLayer builds a new NetworkTileProvider (and
  /// HTTP client) on every rebuild. TileLayer disposes it with the map.
  late final TileProvider _tileProvider =
      widget.tileProvider ?? NetworkTileProvider();

  @override
  void initState() {
    super.initState();
    _sessionRepository =
        widget.repository ?? RepositoryConfig.getSessionRepository();
    _gpsPointDao = widget.gpsPointDao ?? GpsPointDao();
    _loadData();
  }

  // ===================== DATA LOADING =====================

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _sessionRepository.getSessionById(widget.sessionId);
      final points = await _gpsPointDao.findBySessionId(widget.sessionId);

      setState(() {
        _session = session;
        _gpsPoints = points.where(_isAccurateEnough).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Tracked points already passed the full quality check at capture time
  /// (GpsSensor). Re-running it here would also re-check the fix age (max
  /// 10s) and reject every point of a past session (BL-072), so only the
  /// accuracy threshold is re-applied; points without accuracy are kept.
  static bool _isAccurateEnough(GpsPoint point) {
    final accuracy = point.accuracyMeters;
    return accuracy == null || accuracy <= GpsTrackingConfig.minAccuracyMeters;
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_session == null) {
      return const Center(child: Text('Session not found.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [_buildSummaryCard(), const SizedBox(height: 16), _buildMap()],
    );
  }

  // ===================== SUMMARY =====================

  Widget _buildSummaryCard() {
    final distanceKm = (_session!.distanceMeters ?? 0) / 1000.0;

    final duration = Duration(seconds: _session!.durationSeconds ?? 0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _session!.activityType.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _row('Distance', '${distanceKm.toStringAsFixed(2)} km'),
            _row('Duration', _formatDuration(duration)),
            _row(
              'Start',
              DateFormat(
                'dd.MM.yyyy, HH:mm',
              ).format(_session!.startTime.toLocal()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  // ===================== MAP =====================
  Widget _buildMap() {
    if (_gpsPoints.length < 2) {
      return const Center(child: Text('Not enough GPS data to display route.'));
    }

    final routePoints = _gpsPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return SizedBox(
      height: 320,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            // The fit is applied after the first frame; start that frame on
            // the route too, or flutter_map's default camera (50.5, 30.51)
            // loads tiles nobody sees.
            initialCenter: LatLngBounds.fromPoints(routePoints).center,
            initialZoom: 14,
            // Show the whole route. maxZoom keeps the fit finite when all
            // points share one position (zero-size bounds).
            initialCameraFit: CameraFit.coordinates(
              coordinates: routePoints,
              padding: const EdgeInsets.all(32),
              maxZoom: 17,
            ),
          ),
          children: [
            // 🗺️ OpenStreetMap Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'us.benefit4.benefitflutter',
              tileProvider: _tileProvider,
            ),

            // 📍 Route Polyline
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 5,
                  color: brandGreen,
                  borderStrokeWidth: 4,
                  borderColor: Colors.white,
                ),
              ],
            ),

            // Start / end of the route
            MarkerLayer(
              markers: [
                Marker(
                  point: routePoints.first,
                  width: 16,
                  height: 16,
                  child: _routeDot(brandGreen),
                ),
                Marker(
                  point: routePoints.last,
                  width: 16,
                  height: 16,
                  child: _routeDot(AppTheme.darkGrey),
                ),
              ],
            ),

            // OSM tile usage policy: visible "© OpenStreetMap contributors".
            // The map is not at the screen edge, so drop the system insets
            // the widget's SafeArea would otherwise lift it by. The Builder
            // keeps that MediaQuery dependency out of the screen (rebuilds),
            // and the smaller text keeps the unshrinkable row from overflowing
            // on narrow phones at large font sizes.
            Builder(
              builder: (context) => MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                removeTop: true,
                removeRight: true,
                removeBottom: true,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 11),
                  child: SimpleAttributionWidget(
                    source: const Text('OpenStreetMap contributors'),
                    onTap: _openOsmCopyright,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeDot(Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
    );
  }

  Future<void> _openOsmCopyright() async {
    final url = Uri.parse('https://www.openstreetmap.org/copyright');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open OSM copyright page: $e');
    }
  }
}
