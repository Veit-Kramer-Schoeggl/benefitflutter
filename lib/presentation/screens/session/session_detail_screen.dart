import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:benefitflutter/core/config/repository_config.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/session/data/gps_point_dao.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _isLoading = true;
  String? _error;

  Session? _session;
  List<GpsPoint> _gpsPoints = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ===================== DATA LOADING =====================

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessionRepository = RepositoryConfig.getSessionRepository();
      final gpsPointDao = GpsPointDao();

      final session = await sessionRepository.getSessionById(widget.sessionId);
      final points = await gpsPointDao.findBySessionId(widget.sessionId);

      setState(() {
        _session = session;
        _gpsPoints = points.where((p) => p.meetsQualityRequirements()).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
            initialCenter: routePoints.first,
            initialZoom: 14,
          ),
          children: [
            // 🗺️ OpenStreetMap Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.benefitflutter',
            ),

            // 📍 Route Polyline
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 4,
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
