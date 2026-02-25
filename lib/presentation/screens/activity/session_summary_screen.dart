import 'package:flutter/material.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/features/wearable_integration/domain/sensor_data_point.dart';
import 'package:benefitflutter/features/wearable_integration/data/daos/session_sensor_summary_dao.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';

/// Session Summary Screen
///
/// Displays detailed session statistics including:
/// - Basic metrics (distance, duration, pace)
/// - Heart rate statistics (avg/max/min HR, zones)
/// - Steps and calories (if available)
/// - Map preview (placeholder)
class SessionSummaryScreen extends StatefulWidget {
  final Session session;

  const SessionSummaryScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  final Color brandGreen = const Color(0xFF71B33A);
  final SessionSensorSummaryDao _summaryDao = SessionSensorSummaryDao();

  SessionSensorSummary? _sensorSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSensorSummary();
  }

  Future<void> _loadSensorSummary() async {
    try {
      final summary = await _summaryDao.getBySession(widget.session.id);
      setState(() {
        _sensorSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandGreen,
        centerTitle: true,
        title: const Text(
          'Session Summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Activity Type Header
          _buildActivityHeader(),

          const SizedBox(height: 24),

          // Primary Stats Card (Distance, Duration, Pace)
          _buildPrimaryStatsCard(),

          const SizedBox(height: 16),

          // Heart Rate Card (if available)
          if (widget.session.hasWearableData || _sensorSummary != null) ...[
            _buildHeartRateCard(),
            const SizedBox(height: 16),
          ],

          // Additional Metrics Card (Steps, Calories)
          if (_sensorSummary?.totalSteps != null ||
              _sensorSummary?.caloriesBurned != null) ...[
            _buildAdditionalMetricsCard(),
            const SizedBox(height: 16),
          ],

          // Map Preview Card
          _buildMapPreviewCard(),

          const SizedBox(height: 24),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandGreen, brandGreen.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getActivityIcon(widget.session.activityType),
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getActivityName(widget.session.activityType),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(widget.session.startTime),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryStatsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Distance
            _buildStatRow(
              icon: Icons.straighten,
              label: 'Distance',
              value: '${((widget.session.distanceMeters ?? 0) / 1000).toStringAsFixed(2)} km',
              color: Colors.blue,
            ),
            const Divider(height: 24),

            // Duration
            _buildStatRow(
              icon: Icons.timer,
              label: 'Duration',
              value: _formatDuration(widget.session.durationSeconds ?? 0),
              color: Colors.orange,
            ),
            const Divider(height: 24),

            // Average Pace
            _buildStatRow(
              icon: Icons.speed,
              label: 'Avg Pace',
              value: _calculatePace(
                widget.session.distanceMeters ?? 0,
                widget.session.durationSeconds ?? 0,
              ),
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateCard() {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final hasHRData = widget.session.avgHeartRate != null ||
        _sensorSummary?.avgHeartRate != null;

    if (!hasHRData) {
      return const SizedBox.shrink();
    }

    final avgHR = widget.session.avgHeartRate ??
        _sensorSummary?.avgHeartRate?.round();
    final maxHR = widget.session.maxHeartRate ??
        _sensorSummary?.maxHeartRate;
    final minHR = widget.session.minHeartRate ??
        _sensorSummary?.minHeartRate;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Heart Rate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // HR Statistics
            Row(
              children: [
                Expanded(
                  child: _buildHRStat('Average', avgHR, Colors.blue),
                ),
                if (maxHR != null)
                  Expanded(
                    child: _buildHRStat('Max', maxHR, Colors.red),
                  ),
                if (minHR != null)
                  Expanded(
                    child: _buildHRStat('Min', minHR, Colors.green),
                  ),
              ],
            ),

            // Heart Rate Zones (if available)
            if (widget.session.heartRateZones != null ||
                _sensorSummary?.heartRateZones != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Time in Zones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildHeartRateZones(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHRStat(String label, int? value, Color color) {
    return Column(
      children: [
        Text(
          value != null ? '$value' : '--',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const Text(
          'BPM',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildHeartRateZones() {
    // Placeholder for heart rate zones visualization
    // TODO: Parse and display heart rate zones from JSON
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Zone 1 (Fat Burn)'),
              Text('15:30', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Zone 2 (Cardio)'),
              Text('08:15', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Zone 3 (Peak)'),
              Text('02:45', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalMetricsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_sensorSummary?.totalSteps != null)
              _buildStatRow(
                icon: Icons.directions_walk,
                label: 'Steps',
                value: '${_sensorSummary!.totalSteps}',
                color: Colors.teal,
              ),
            if (_sensorSummary?.totalSteps != null &&
                _sensorSummary?.caloriesBurned != null)
              const Divider(height: 24),
            if (_sensorSummary?.caloriesBurned != null)
              _buildStatRow(
                icon: Icons.local_fire_department,
                label: 'Calories',
                value: '${_sensorSummary!.caloriesBurned!.round()} kcal',
                color: Colors.deepOrange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreviewCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.asset(
              "assets/images/backgrounds/activity/activity_map.png",
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Route Map',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Navigate to full map view
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Full map view coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('View Full Map'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Delete session
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete feature coming soon')),
              );
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.walking:
        return Icons.directions_walk;
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.swimming:
        return Icons.pool;
      case ActivityType.strengthTraining:
        return Icons.fitness_center;
      case ActivityType.yoga:
        return Icons.self_improvement;
      case ActivityType.hiking:
        return Icons.terrain;
      case ActivityType.trailRunning:
        return Icons.landscape;
      case ActivityType.dancing:
        return Icons.music_note;
      case ActivityType.martialArts:
        return Icons.sports_martial_arts;
      case ActivityType.teamSports:
        return Icons.sports_soccer;
      case ActivityType.other:
        return Icons.fitness_center;
    }
  }

  String _getActivityName(ActivityType type) {
    switch (type) {
      case ActivityType.running:
        return 'Running';
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.cycling:
        return 'Cycling';
      case ActivityType.swimming:
        return 'Swimming';
      case ActivityType.strengthTraining:
        return 'Strength Training';
      case ActivityType.yoga:
        return 'Yoga';
      case ActivityType.hiking:
        return 'Hiking';
      case ActivityType.trailRunning:
        return 'Trail Running';
      case ActivityType.dancing:
        return 'Dancing';
      case ActivityType.martialArts:
        return 'Martial Arts';
      case ActivityType.teamSports:
        return 'Team Sports';
      case ActivityType.other:
        return 'Other';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today at ${_formatTime(date)}';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  String _calculatePace(double meters, int seconds) {
    if (meters == 0) return '--:--';

    final kilometers = meters / 1000;
    final minutes = seconds / 60;
    final paceMinPerKm = minutes / kilometers;

    final paceMin = paceMinPerKm.floor();
    final paceSec = ((paceMinPerKm - paceMin) * 60).round();

    return '$paceMin:${paceSec.toString().padLeft(2, '0')} min/km';
  }
}
