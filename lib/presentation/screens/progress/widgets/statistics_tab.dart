import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:benefitflutter/core/config/theme.dart';
import 'package:benefitflutter/providers/progress_provider.dart';
import 'package:benefitflutter/presentation/screens/progress/widgets/custom_charts.dart';
import 'package:benefitflutter/presentation/screens/progress/widgets/progress_summary.dart';

class StatisticsTab extends StatelessWidget {
  final ProgressProvider provider;

  const StatisticsTab({super.key, required this.provider});

  Widget _buildMonthlyDistanceChart(BuildContext context, Map<String, double> monthlyData) {

    final int currentYear = DateTime.now().year;
    final Map<int, double> chartData = {};
    final Map<int, String> chartLabels = {};
    final DateFormat formatter = DateFormat('MMM');

    for (int month = 1; month <= 12; month++) {
      final String key = '$currentYear-${month.toString().padLeft(2, '0')}';
      final double distance = monthlyData[key] ?? 0.0;
      final date = DateTime(currentYear, month, 1);
      final String label = formatter.format(date);

      chartData[month] = distance;
      chartLabels[month] = label;
    }

    if (chartData.values.every((d) => d == 0.0)) {
      return const Center(child: Text('No distance recorded this year.'));
    }

    return CustomBarChart(
      data: chartData,
      title: 'Monthly Distance (km) - $currentYear',
      customLabels: chartLabels,
    );
  }

  // Helper function for monthly duration chart (LINE CHART)
  Widget _buildMonthlyDurationChart() {
    final int currentYear = DateTime.now().year;

    final Map<String, double> durationMonthlyData = provider.getDurationPerMonth();

    final Map<int, double> chartData = {};
    final Map<int, String> chartLabels = {};
    final DateFormat formatter = DateFormat('MMM');

    for (int month = 1; month <= 12; month++) {
      final String key = '$currentYear-${month.toString().padLeft(2, '0')}';

      final double duration = durationMonthlyData[key] ?? 0.0;
      final date = DateTime(currentYear, month, 1);
      final String label = formatter.format(date);

      chartData[month] = duration;
      chartLabels[month] = label;
    }

    if (chartData.values.every((d) => d == 0.0)) {
      return const Center(child: Text('No duration recorded this year.'));
    }

    return CustomLineChart(
      data: chartData,
      title: 'Monthly Duration (min) - $currentYear',
      customLabels: chartLabels,
    );
  }

  // Helper function for weekly distance chart (BAR CHART)
  Widget _buildWeeklyDistanceChart() {
    final distanceWeeklyDataFromProvider = provider.getDistancePerWeekday();
    final Map<int, double> fullWeeklyDistanceData = {};
    for (int i = 1; i <= 7; i++) {
      fullWeeklyDistanceData[i] = distanceWeeklyDataFromProvider[i] ?? 0.0;
    }

    return CustomBarChart(
      data: fullWeeklyDistanceData,
      title: 'Weekly Distance (km)',
    );
  }

  Widget _buildWeeklyDurationChart() {
    final durationWeeklyDataFromProvider =
    provider.getDurationPerWeekdayMinutes();

    final Map<int, double> fullWeeklyDurationData = {};
    final Map<int, String> labels = {
      1: 'Mo',
      2: 'Di',
      3: 'Mi',
      4: 'Do',
      5: 'Fr',
      6: 'Sa',
      7: 'So',
    };

    for (int i = 1; i <= 7; i++) {
      fullWeeklyDurationData[i] =
          durationWeeklyDataFromProvider[i] ?? 0.0;
    }

    return CustomLineChart(
      data: fullWeeklyDurationData,
      title: 'Weekly Duration (min)',
      customLabels: labels,
    );
  }

  // Helper function for yearly distance chart (BAR CHART)
  Widget _buildYearlyDistanceChart() {
    final distanceYearlyDataFromProvider = provider.getDistancePerYear();

    if (distanceYearlyDataFromProvider.isEmpty) {
      return const Center(child: Text('No yearly distance data available.'));
    }

    final now = DateTime.now();
    final currentYear = now.year;

    final Map<int, String> yearlyLabels = {};
    final int numYears = distanceYearlyDataFromProvider.length;

    final int startYear = currentYear - numYears + 1;

    for (int i = 1; i <= numYears; i++) {
      final year = startYear + i - 1;
      yearlyLabels[i] = year.toString();
    }

    return CustomBarChart(
      data: distanceYearlyDataFromProvider,
      title: 'Yearly Distance (km) - Last $numYears Years',
      customLabels: yearlyLabels,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color mediumGrey = AppTheme.mediumGrey;

    // Empty state
    if (provider.activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/icons/activity/icon_activity.png',
              width: 80,
              height: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Progress - Statistics',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Perform activities to see statistics.',
              style: TextStyle(color: mediumGrey),
            ),
          ],
        ),
      );
    }

    // Main content (Charts and Summary)
    final distanceMonthlyData = provider.getDistancePerMonth();

    return ListView(
      children: [
        ProgressSummary(provider: provider),
        const SizedBox(height: 10),

        _buildWeeklyDistanceChart(),
        const SizedBox(height: 10),

        _buildWeeklyDurationChart(),
        const SizedBox(height: 20),

        _buildMonthlyDistanceChart(context, distanceMonthlyData),
        const SizedBox(height: 10),

        _buildMonthlyDurationChart(),
        const SizedBox(height: 10),

        _buildYearlyDistanceChart(),

        const SizedBox(height: 20),
      ],
    );
  }
}