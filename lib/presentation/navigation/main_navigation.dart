import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/presentation/screens/activity/activity_screen.dart';
import 'package:benefitflutter/presentation/screens/progress/progress_screen.dart';
import 'package:benefitflutter/presentation/screens/benefit/benefit_screen.dart';
import 'package:benefitflutter/presentation/screens/profile/profile_screen.dart';
import 'package:benefitflutter/presentation/screens/community/community_screen.dart';
import 'package:benefitflutter/providers/progress_provider.dart';

/// Main navigation screen with 5 bottom tabs
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // Start at Activity tab (index 2)

  // List of screens for each tab
  final List<Widget> _screens = const [
    CommunityScreen(), // Tab 0: Community
    ProgressScreen(), // Tab 1: Progress
    ActivityScreen(), // Tab 2: Activity
    BenefitScreen(), // Tab 3: Benefits & rewards
    ProfileScreen(), // Tab 4: Profile
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Reload Progress data when navigating to Progress tab (index 1)
    if (index == 1) {
      // Use addPostFrameCallback to ensure context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ProgressProvider>().loadActivities();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/icons/community/icon_community.png',
              width: 24,
              height: 24,
              color: _currentIndex == 0
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
              color: _currentIndex == 1
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
              color: _currentIndex == 2
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
              color: _currentIndex == 3
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
              color: _currentIndex == 4
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
