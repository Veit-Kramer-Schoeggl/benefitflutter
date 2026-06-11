import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/progress_provider.dart';

/// Main navigation scaffold with 5 bottom tabs, driven by go_router's
/// [StatefulNavigationShell] (each tab is a branch with its own navigator, so
/// per-tab state survives switching — same UX as the previous IndexedStack).
class MainNavigationScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationScreen({super.key, required this.navigationShell});

  void _onTabTapped(BuildContext context, int index) {
    // Reload Progress data when navigating to the Progress tab (index 1),
    // preserving the previous behaviour. Hooked before the branch switch.
    if (index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<ProgressProvider>().loadActivities();
        }
      });
    }

    // Tapping the active tab returns it to its root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTabTapped(context, index),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/icons/community/icon_community.png',
              width: 24,
              height: 24,
              color: currentIndex == 0
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/icons/progress/icon_progress.png',
              width: 24,
              height: 24,
              color: currentIndex == 1
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/icons/activity/icon_activity.png',
              width: 24,
              height: 24,
              color: currentIndex == 2
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/icons/benefit/icon_benefit.png',
              width: 24,
              height: 24,
              color: currentIndex == 3
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            label: 'Benefit',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/icons/profile/icon_profil.png',
              width: 24,
              height: 24,
              color: currentIndex == 4
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
