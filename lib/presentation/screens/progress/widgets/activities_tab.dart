import 'package:flutter/material.dart';
import 'package:benefitflutter/providers/progress_provider.dart';
import 'package:benefitflutter/features/session/domain/activity_entry.dart';
import 'package:benefitflutter/presentation/screens/progress/widgets/activity_list_item.dart';

/// Groups activities by date ranges
enum DateGroup { today, yesterday, thisWeek, older }

class ActivitiesTab extends StatelessWidget {
  final ProgressProvider provider;
  final void Function(BuildContext, ActivityEntry) onTap;
  final void Function(BuildContext, ActivityEntry)? onLongPress;
  final VoidCallback onAddManualTap;

  const ActivitiesTab({
    super.key,
    required this.provider,
    required this.onTap,
    this.onLongPress,
    required this.onAddManualTap,
  });

  // ===================== DATE GROUPING =====================

  DateGroup _getDateGroup(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final activityDay = DateTime(date.year, date.month, date.day);

    if (activityDay == today) {
      return DateGroup.today;
    }

    if (activityDay == today.subtract(const Duration(days: 1))) {
      return DateGroup.yesterday;
    }

    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    if (activityDay.isAfter(
      startOfWeek.subtract(const Duration(milliseconds: 1)),
    )) {
      return DateGroup.thisWeek;
    }

    return DateGroup.older;
  }

  // ===================== UI HELPERS =====================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    if (provider.activities.isEmpty) {
      return const Center(child: Text('No activities yet.'));
    }

    final Map<DateGroup, List<ActivityEntry>> groupedActivities = {
      DateGroup.today: [],
      DateGroup.yesterday: [],
      DateGroup.thisWeek: [],
      DateGroup.older: [],
    };

    for (final entry in provider.activities) {
      final group = _getDateGroup(entry.startTime);
      groupedActivities[group]!.add(entry);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (groupedActivities[DateGroup.today]!.isNotEmpty) ...[
          _buildSectionHeader('TODAY'),
          ...groupedActivities[DateGroup.today]!.map(
            (entry) => ActivityListItem(
              entry: entry,
              onTap: () => onTap(context, entry),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(context, entry),
            ),
          ),
        ],

        if (groupedActivities[DateGroup.yesterday]!.isNotEmpty) ...[
          _buildSectionHeader('YESTERDAY'),
          ...groupedActivities[DateGroup.yesterday]!.map(
            (entry) => ActivityListItem(
              entry: entry,
              onTap: () => onTap(context, entry),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(context, entry),
            ),
          ),
        ],

        if (groupedActivities[DateGroup.thisWeek]!.isNotEmpty) ...[
          _buildSectionHeader('THIS WEEK'),
          ...groupedActivities[DateGroup.thisWeek]!.map(
            (entry) => ActivityListItem(
              entry: entry,
              onTap: () => onTap(context, entry),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(context, entry),
            ),
          ),
        ],

        if (groupedActivities[DateGroup.older]!.isNotEmpty) ...[
          _buildSectionHeader('OLDER'),
          ...groupedActivities[DateGroup.older]!.map(
            (entry) => ActivityListItem(
              entry: entry,
              onTap: () => onTap(context, entry),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(context, entry),
            ),
          ),
        ],
      ],
    );
  }
}
