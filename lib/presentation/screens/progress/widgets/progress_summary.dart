import 'package:flutter/material.dart';
import 'package:benefitflutter/providers/progress_provider.dart';
import 'package:benefitflutter/features/session/domain/activity_entry.dart';
import 'package:benefitflutter/core/config/theme.dart';

class ProgressSummary extends StatelessWidget {
  final ProgressProvider provider;

  const ProgressSummary({super.key, required this.provider});

  // Helper function for formatting duration in hours/minutes/seconds (Unverändert)
  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '00:00:00 h';

    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds h';
  }

  // Helper function to display a single statistics card
  Widget _buildStatCard({
    required String title,
    required String primaryValue,
    required String secondaryValue,
    required Color primaryColor,
    required BuildContext context,
  }) {
    final Color darkGrey = AppTheme.darkGrey;
    final cardShape =
        Theme.of(context).cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4.0),
        elevation: 2,
        shape: cardShape,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: darkGrey.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                primaryValue,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                secondaryValue,
                style: TextStyle(fontSize: 12, color: darkGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatsForRange(bool Function(ActivityEntry) filter) {
    double distanceKm = 0.0;
    Duration totalDuration = Duration.zero;
    int sessionCount = 0;

    for (final entry in provider.activities) {
      if (filter(entry)) {
        distanceKm += entry.distanceKm ?? 0.0;
        totalDuration += entry.duration ?? Duration.zero;
        sessionCount++;
      }
    }

    return {
      'distanceKm': distanceKm,
      'duration': totalDuration,
      'sessions': sessionCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final Color primaryColor = Theme.of(
      context,
    ).colorScheme.primary; // primaryGreen
    final Color darkGrey = AppTheme.darkGrey; // darkGrey

    // 1. Weekly statistics (Monday to today)
    final startOfWeek = now
        .subtract(Duration(days: now.weekday - 1))
        .copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
    final weekStats = _getStatsForRange(
      (entry) => entry.startTime.isAfter(
        startOfWeek.subtract(const Duration(milliseconds: 1)),
      ),
    );

    // 2. Monthly statistics
    final startOfMonth = DateTime(now.year, now.month, 1);
    final monthStats = _getStatsForRange(
      (entry) => entry.startTime.isAfter(
        startOfMonth.subtract(const Duration(milliseconds: 1)),
      ),
    );

    // 3. Total statistics
    final totalStats = provider.getTotalStats();

    // Format total duration as "Xh Ym"
    final totalDurationSeconds = totalStats['durationSeconds'] as int;
    final totalHours = totalDurationSeconds ~/ 3600;
    final totalMinutes = (totalDurationSeconds % 3600) ~/ 60;
    final totalDurationFormatted = totalHours > 0
        ? '${totalHours}h ${totalMinutes}m'
        : '${totalMinutes}m';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard(
                context: context,
                title: 'This Week',
                primaryValue:
                    '${weekStats['distanceKm'].toStringAsFixed(1)} km',
                secondaryValue: _formatDuration(weekStats['duration']),
                primaryColor: primaryColor,
              ),

              _buildStatCard(
                context: context,
                title: 'This Month',
                primaryValue:
                    '${monthStats['distanceKm'].toStringAsFixed(1)} km',
                secondaryValue: _formatDuration(monthStats['duration']),
                primaryColor: primaryColor,
              ),

              _buildStatCard(
                context: context,
                title: 'Total',
                primaryValue: totalDurationFormatted,
                secondaryValue: '${totalStats['sessions']} sessions',
                primaryColor: darkGrey,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
