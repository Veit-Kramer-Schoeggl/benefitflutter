import 'package:flutter/material.dart';
import 'package:benefitflutter/features/session/domain/activity_entry.dart';
import 'package:benefitflutter/core/config/theme.dart';

class ActivityListItem extends StatelessWidget {
  final ActivityEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ActivityListItem({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
  });

  static const String _activityIconPath = 'assets/images/icons/activity/icon_activity.png';

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color darkGrey = AppTheme.darkGrey;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                _activityIconPath,
                width: 24,
                height: 24,
                color: primaryColor,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.activityType,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: darkGrey,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: darkGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.formattedDistance,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.formattedDuration,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}