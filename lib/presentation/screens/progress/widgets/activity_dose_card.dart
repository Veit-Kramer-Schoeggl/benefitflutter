import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/core/config/theme.dart';
import 'package:benefitflutter/features/session/utils/activity_dose.dart';
import 'package:benefitflutter/providers/auth_provider.dart';
import 'package:benefitflutter/providers/progress_provider.dart';

/// This week's activity dose (MET-hours) against the WHO recommendation, plus
/// the preliminary "independent years" model estimate (see [ActivityDose]).
class ActivityDoseCard extends StatelessWidget {
  final ProgressProvider provider;

  const ActivityDoseCard({super.key, required this.provider});

  static const Color _brandGreen = Color(0xFF71B33A);

  // Recorded time as "Xh Ym" (same format as the "Total" summary card)
  String _formatActiveTime(double minutes) {
    final totalSeconds = (minutes * 60).round();
    final hours = totalSeconds ~/ 3600;
    final remainingMinutes = (totalSeconds % 3600) ~/ 60;
    return hours > 0
        ? '${hours}h ${remainingMinutes}m'
        : '${remainingMinutes}m';
  }

  // Model statement for the weekly dose. Shows both model rows (women–men)
  // when the profile names neither; the band always stays in the sentence.
  String _modelText(double metHours, ModelSex? sex) {
    final women = ActivityDose.estimateGainMonths(metHours, ModelSex.female);
    final men = ActivityDose.estimateGainMonths(metHours, ModelSex.male);
    if (women == null || men == null) {
      return 'Short, brisk sessions count too. From 2 MET-hours a week, '
          'the model estimate appears here.';
    }

    final String gain = switch (sex) {
      ModelSex.female =>
        '${women.months} more independent months on average '
            '(range ${women.low}–${women.high})',
      ModelSex.male =>
        '${men.months} more independent months on average '
            '(range ${men.low}–${men.high})',
      null =>
        '${women.months}–${men.months} more independent months on average '
            '(women–men; range ${math.min(women.low, men.low)}–'
            '${math.max(women.high, men.high)})',
    };
    final String capNote = men.capped
        ? ' Shown up to twice the recommendation.'
        : '';

    return 'Keeping up this weekly level from age 40 is linked to about '
        '$gain.$capNote';
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Independent years'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSection(
                'What are independent years?',
                'Years of life without permanent long-term care allowance '
                    '(Austrian Pflegegeld, level 1 or higher).',
              ),
              _buildInfoSection(
                'The recommendation',
                'The WHO recommends at least 150 minutes of moderate activity '
                    'per week. At 4.5 MET, that is 11.25 MET-hours.',
              ),
              _buildInfoSection(
                'How BeneFit counts',
                'MET-hours = duration × intensity (MET). Walking counts 4.0, '
                    'cycling 6.8 and running 9.0 (an assumption: twice the '
                    'moderate 4.5). Whether a recording was walking or running '
                    'is estimated from its average speed.',
              ),
              _buildInfoSection(
                'What the model shows',
                'Keeping up the recommended level from age 40 is linked to '
                    'about 1.5 (men) / 1.2 (women) more independent years on '
                    'average (range 1.0–2.6 / 0.7–2.4). 46\u00a0% (men) / '
                    '51\u00a0% (women) of this gain falls after the 80th '
                    'birthday: in the model, care dependence comes later but '
                    'does not disappear.',
              ),
              _buildInfoSection(
                'Time balance',
                'At 150 minutes a week from age 40, each hour of activity is '
                    'matched by about 1.9 (men) / 1.5 (women) waking hours of '
                    'life, 1.6 / 1.2 of them independent. This is a lower '
                    'bound.',
              ),
              _buildInfoSection(
                'Limits',
                'All figures compare keeping up a weekly level with staying '
                    'inactive. They are population averages from '
                    'observational studies: not a personal forecast and no '
                    'proof of cause and effect. BeneFit only counts activity '
                    'recorded in the app. All figures are preliminary.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color darkGrey = AppTheme.darkGrey;
    final cardShape =
        Theme.of(context).cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
      color: darkGrey.withValues(alpha: 0.7),
    );
    final smallGrey = TextStyle(
      fontSize: 12,
      color: darkGrey.withValues(alpha: 0.7),
    );

    // Rounded to the one decimal shown, so the line and the model agree on
    // the 2 MET-hour threshold and the cap
    final metHours = (provider.getMetHoursThisWeek() * 10).round() / 10;
    final share = metHours / ActivityDose.recommendedMetHours;
    // The weekday minutes only cover the current week, so their sum is the
    // time recorded this week.
    final weekMinutes = provider.getDurationPerWeekdayMinutes().values.fold(
      0.0,
      (sum, minutes) => sum + minutes,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        margin: const EdgeInsets.all(4.0),
        elevation: 2,
        shape: cardShape,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('ACTIVITY THIS WEEK', style: headerStyle),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'About independent years',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showInfoDialog(context),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${(share * 100).round()} %',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: _brandGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'of the weekly WHO recommendation',
                      style: TextStyle(fontSize: 14, color: darkGrey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 8,
                color: _brandGreen,
                backgroundColor: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Text(
                '${metHours.toStringAsFixed(1)} of '
                '${ActivityDose.recommendedMetHours} MET-hours · '
                '${_formatActiveTime(weekMinutes)} recorded',
                style: smallGrey,
              ),
              const Divider(height: 24),
              Text('INDEPENDENT YEARS · MODEL', style: headerStyle),
              const SizedBox(height: 6),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => Text(
                  _modelText(
                    metHours,
                    ActivityDose.modelSexForGender(auth.currentUser?.gender),
                  ),
                  style: TextStyle(fontSize: 15, height: 1.3, color: darkGrey),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Independent = not depending on long-term care (Austrian care '
                'allowance). Preliminary model estimate for Austria, compared '
                'with staying inactive — a population average, not a personal '
                'forecast.',
                style: smallGrey.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
