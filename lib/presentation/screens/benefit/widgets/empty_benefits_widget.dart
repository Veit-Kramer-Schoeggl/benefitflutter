import 'package:flutter/material.dart';
import 'package:benefitflutter/presentation/shared/widgets/empty_state_widget.dart';

/// Empty state widget for when user has no earned benefits
/// Encourages them to start tracking activities
class EmptyBenefitsWidget extends StatelessWidget {
  const EmptyBenefitsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.card_giftcard,
      title: 'No Benefits Yet',
      message:
          'Start tracking your activities to earn rewards and savings!\n\nEvery kilometer counts towards amazing benefits.',
      action: ElevatedButton.icon(
        onPressed: () {
          // TODO: Navigate to Activity tab
          // For now, just show a message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Go to Activity tab to start tracking!'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.directions_run),
        label: const Text('Start Tracking'),
      ),
    );
  }
}
