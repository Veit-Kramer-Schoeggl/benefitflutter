import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:benefitflutter/providers/progress_provider.dart';
import 'package:benefitflutter/features/session/domain/activity_entry.dart';
import 'package:benefitflutter/presentation/screens/progress/widgets/statistics_tab.dart';
import 'package:benefitflutter/presentation/screens/progress/widgets/activities_tab.dart';
import 'package:benefitflutter/core/config/theme.dart';
import 'package:benefitflutter/providers/benefit_provider.dart';
import 'package:benefitflutter/providers/auth_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();

  DateTime _selectedStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userId;
      context.read<ProgressProvider>().updateUserId(userId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _caloriesController.dispose();
    _startTimeController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------
  // HELPER METHODS
  // ----------------------------------------------------
  Duration _parseDuration(String durationString) {
    if (durationString.isEmpty) return Duration.zero;

    final parts = durationString
        .split(':')
        .map(int.tryParse)
        .whereType<int>()
        .toList();

    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    } else if (parts.length == 1) {
      return Duration(minutes: parts[0]);
    }
    return Duration.zero;
  }

  Future<void> _selectDateTime(
    BuildContext context,
    StateSetter setDialogState,
  ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedStartTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedStartTime),
      );

      if (pickedTime != null) {
        _selectedStartTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        final DateFormat formatter = DateFormat('dd.MM.yyyy, HH:mm');
        _startTimeController.text = formatter.format(_selectedStartTime);

        setDialogState(() {});
      }
    }
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    required BuildContext context,
  }) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color darkGrey = AppTheme.darkGrey;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(color: darkGrey, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: darkGrey.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        hintStyle: TextStyle(color: darkGrey.withValues(alpha: 0.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
        border: UnderlineInputBorder(borderSide: BorderSide(color: darkGrey)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: darkGrey),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
        ),
      ),
    );
  }

  void _showManualEntrySimulatedDialog(
    BuildContext context, {
    ActivityEntry? entryToEdit,
  }) {
    final bool isEdit = entryToEdit != null;

    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color darkGrey = AppTheme.darkGrey;

    if (isEdit) {
      _durationController.text = entryToEdit.formattedDuration.isNotEmpty
          ? entryToEdit.formattedDuration
          : '00:00:00';
      _distanceController.text =
          entryToEdit.distanceKm?.toStringAsFixed(2) ?? '';
      _caloriesController.text = entryToEdit.calories?.toString() ?? '';
      _startTimeController.text = entryToEdit.formattedDate;
      _selectedStartTime = entryToEdit.startTime;
    } else {
      _durationController.clear();
      _distanceController.clear();
      _caloriesController.clear();
      _startTimeController.clear();
      _selectedStartTime = DateTime.now();
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 25,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          isEdit ? 'EDIT ACTIVITY' : 'MANUAL ENTRY',
                          style: TextStyle(
                            color: darkGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Image.asset(
                          'assets/images/icons/activity/icon_activity.png',
                          width: 40,
                          height: 40,
                          color: darkGrey,
                        ),
                        const SizedBox(height: 20),

                        _buildCustomTextField(
                          context: context,
                          controller: _durationController,
                          label: 'Duration *',
                          hint: '00:30:00',
                          keyboardType: TextInputType.datetime,
                        ),
                        _buildCustomTextField(
                          context: context,
                          controller: _distanceController,
                          label: 'Distance (km) *',
                          hint: 'e.g. 5.00',
                          keyboardType: TextInputType.number,
                        ),
                        _buildCustomTextField(
                          context: context,
                          controller: _caloriesController,
                          label: 'Calories',
                          hint: 'e.g. 300',
                          keyboardType: TextInputType.number,
                        ),

                        _buildCustomTextField(
                          context: context,
                          controller: _startTimeController,
                          label: 'Start time',
                          hint: 'Select date and time',
                          readOnly: true,
                          onTap: () async {
                            await _selectDateTime(context, setDialogState);
                          },
                        ),

                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: () {
                            final distanceKm =
                                double.tryParse(
                                  _distanceController.text.replaceAll(',', '.'),
                                ) ??
                                0.0;
                            final duration = _parseDuration(
                              _durationController.text,
                            );
                            final calories = int.tryParse(
                              _caloriesController.text,
                            );
                            final startTime = _selectedStartTime;

                            // 🚀 NEW VALIDATION: Duration
                            if (duration == Duration.zero) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a valid duration (e.g., 00:30:00). Duration is mandatory.',
                                  ),
                                ),
                              );
                              return;
                            }

                            // 🚀 NEW VALIDATION: Distance
                            if (distanceKm <= 0.0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a valid distance in km (must be greater than 0). Distance is mandatory.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (!isEdit) {
                              final newEntry = ActivityEntry(
                                activityType: 'Manual Entry',
                                // Use `distanceKm` directly since we validated it's > 0 above
                                distanceKm: distanceKm,
                                duration: duration,
                                startTime: startTime,
                                isManual: true,
                                calories: calories,
                              );
                              context.read<ProgressProvider>().addActivity(
                                newEntry,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Manual activity saved and added!',
                                  ),
                                ),
                              );
                            } else {
                              final updatedEntry = ActivityEntry(
                                sessionId: entryToEdit.sessionId,
                                activityType: entryToEdit.activityType,
                                distanceKm: distanceKm,
                                duration: duration,
                                startTime: startTime,
                                isManual: true,
                                calories: calories,
                              );

                              context.read<ProgressProvider>().updateActivity(
                                updatedEntry,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Activity updated!'),
                                ),
                              );
                            }

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            minimumSize: const Size.fromHeight(45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isEdit ? 'UPDATE' : 'SAVE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToAddManualActivity(BuildContext context) {
    _showManualEntrySimulatedDialog(context);
  }

  void _openSessionDetails(BuildContext context, ActivityEntry entry) {
    context.push('/session/${entry.sessionId}');
  }

  // ignore: unused_element — dead code (manual edit/delete dialog not wired to UI); pending dead-code decision (see documentation/ARCHITECTURE_REVIEW.md).
  void _handleTapOrSwipeAction(BuildContext context, ActivityEntry entry) {
    if (entry.isManual) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Action'),
          content: Text('${entry.activityType} - ${entry.formattedDistance}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showManualEntrySimulatedDialog(context, entryToEdit: entry);
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<ProgressProvider>().removeActivity(entry);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${entry.activityType} deleted.')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Details for ${entry.activityType} (${entry.formattedDistance})',
          ),
          action: SnackBarAction(
            label: 'DELETE',
            onPressed: () =>
                context.read<ProgressProvider>().removeActivity(entry),
          ),
        ),
      );
    }
  }

  // ----------------------------------------------------
  // BUILD METHOD
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Progress'),

        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'STATISTICS'),
            Tab(text: 'ACTIVITIES'),
          ],
        ),
      ),

      body: Consumer<ProgressProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Text('Error: ${provider.error}\nTap to retry'),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              StatisticsTab(provider: provider),
              ActivitiesTab(
                provider: provider,
                onTap: (context, entry) => _openSessionDetails(context, entry),
                onAddManualTap: () => _navigateToAddManualActivity(context),
              ),
            ],
          );
        },
      ),

      bottomNavigationBar: _buildEarnedSoFarBar(context),
    );
  }

  Widget _buildEarnedSoFarBar(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color darkGrey = AppTheme.darkGrey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: primaryColor.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EARNED SO FAR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Consumer<BenefitProvider>(
                builder: (context, benefitProvider, _) {
                  return Text(
                    '${benefitProvider.totalSavings.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkGrey,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
