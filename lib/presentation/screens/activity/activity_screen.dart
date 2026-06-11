import 'dart:ui'; // for ImageFilter.blur

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/activity_provider.dart';
import 'package:benefitflutter/providers/connectivity_provider.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/tracking_state.dart';
import 'package:benefitflutter/presentation/shared/widgets/error_display_widget.dart';
import 'package:benefitflutter/presentation/screens/wearable/widgets/heart_rate_display.dart';
import 'package:benefitflutter/presentation/screens/wearable/device_connection_screen.dart';
import 'package:benefitflutter/providers/benefit_provider.dart';

/// Activity screen - Running session with real GPS tracking
///
/// MVVM Pattern:
/// - UI (View) consumes ActivityProvider state
/// - User actions trigger provider methods
/// - Provider manages backend (GPS, database, timer)
///
/// States (from ActivityProvider.TrackingState):
///   - idle → Ready to start
///   - tracking → Recording active
///   - paused → Paused, can continue or stop
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // BRAND COLORS
  final Color brandGreen = const Color(0xFF71B33A);
  final Color buttonIdle = const Color(0xFF71B33A);
  final Color buttonRecording = const Color(0xFFB00020); // red
  final Color buttonPaused = const Color(0xFF444444); // dark grey

  @override
  void initState() {
    super.initState();
    // Initialize activity provider on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ActivityProvider>();
      // Set default activity type if needed
      if (provider.selectedActivityType != ActivityType.running) {
        provider.selectActivityType(ActivityType.running);
      }
    });
  }

  // ---------------------------------------------------------
  // BUTTON LOGIC (Maps TrackingState to UI)
  // ---------------------------------------------------------

  String _getButtonText(TrackingState state) {
    switch (state) {
      case TrackingState.idle:
        return "START Running";
      case TrackingState.tracking:
        return "Pause";
      case TrackingState.paused:
        return "Continue / Stop";
    }
  }

  Color _getButtonColor(TrackingState state) {
    switch (state) {
      case TrackingState.idle:
        return buttonIdle;
      case TrackingState.tracking:
        return buttonRecording;
      case TrackingState.paused:
        return buttonPaused;
    }
  }

  String _getStatusText(TrackingState state, bool hasError, String? error) {
    if (hasError && error != null) {
      return error;
    }

    switch (state) {
      case TrackingState.idle:
        return "Ready to start recording";
      case TrackingState.tracking:
        return "Recording running";
      case TrackingState.paused:
        return "Recording paused";
    }
  }

  bool _isTimerVisible(TrackingState state) {
    return state == TrackingState.tracking || state == TrackingState.paused;
  }

  // ---------------------------------------------------------
  // SESSION CONTROL (Delegates to ActivityProvider)
  // ---------------------------------------------------------

  Future<void> _handleTap(BuildContext context, TrackingState state) async {
    final provider = context.read<ActivityProvider>();

    switch (state) {
      case TrackingState.idle:
        await provider.startSession();
        break;
      case TrackingState.tracking:
        await provider.pauseSession();
        break;
      case TrackingState.paused:
        await provider.resumeSession();
        break;
    }
  }

  Future<void> _handleLongPress(
    BuildContext context,
    TrackingState state,
  ) async {
    if (state == TrackingState.paused) {
      final provider = context.read<ActivityProvider>();
      await provider.stopSession();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session saved!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Long press only works while paused")),
      );
    }
  }

  // ---------------------------------------------------------
  // HELPER
  // ---------------------------------------------------------

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  String _formatDistance(double meters) {
    final km = meters / 1000.0;
    return km.toStringAsFixed(1);
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandGreen,
        centerTitle: true,
        title: const Text(
          "Activity",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // Connectivity indicator
        actions: [
          Consumer<ConnectivityProvider>(
            builder: (context, connectivity, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(
                  connectivity.isOnline
                      ? Icons.signal_cellular_alt
                      : Icons.signal_cellular_connected_no_internet_0_bar,
                  color: connectivity.isOnline ? Colors.white : Colors.red,
                  size: 24,
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ActivityProvider>(
        builder: (context, provider, child) {
          // Error state
          if (provider.hasError) {
            return ErrorDisplayWidget(message: provider.error!, onRetry: null);
          }

          // Extract state from provider
          final state = provider.trackingState;
          final distance = provider.currentDistance;
          final elapsedSeconds = provider.elapsedSeconds;
          final isLoading = provider.isLoading;

          // Map provider state to UI
          final buttonText = _getButtonText(state);
          final buttonColor = _getButtonColor(state);
          final statusText = _getStatusText(
            state,
            provider.hasError,
            provider.error,
          );
          final timerVisible = _isTimerVisible(state);
          final formattedTime = _formatTime(elapsedSeconds);
          final distanceKm = _formatDistance(distance);

          return Stack(
            children: [
              // ---------- MAP BACKGROUND ----------
              Positioned.fill(
                child: Image.asset(
                  "assets/images/backgrounds/activity/activity_map.png",
                  fit: BoxFit.cover,
                ),
              ),

              // ---------- BLUR + DARK OVERLAY ----------
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
              ),

              // ---------- LOADING OVERLAY ----------
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),

              // ---------- FOREGROUND ----------
              Column(
                children: [
                  // Scrollable content area
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // HEART RATE DISPLAY
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: HeartRateDisplayCompact(
                              currentHeartRate: provider.currentHeartRate,
                              isConnected: provider.hasHeartRateMonitor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const DeviceConnectionScreen(),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // DISTANCE + NEW SESSION
                          Column(
                            children: [
                              // Glow + icon + KM
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 22,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  color: Colors.white.withValues(alpha: 0.10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.directions_run,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "$distanceKm KM",
                                      style: const TextStyle(
                                        fontSize: 40,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // New running session pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: buttonIdle,
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                child: const Text(
                                  "New running session!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: .3,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // MAIN CARD
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 22,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.93),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // MAP PREVIEW
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      "assets/images/backgrounds/activity/activity_map.png",
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  const Text(
                                    "GAIN MORE HEALTHY LIFE YEARS\nWITH BENEFIT!",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // BUTTON
                                  Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: isLoading
                                          ? null
                                          : () => _handleTap(context, state),
                                      onLongPress: isLoading
                                          ? null
                                          : () => _handleLongPress(
                                              context,
                                              state,
                                            ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: buttonColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            buttonText,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // STATUS TEXT
                                  Text(
                                    statusText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: provider.hasError
                                          ? Colors.red
                                          : Colors.black87,
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // TIMER
                                  AnimatedOpacity(
                                    opacity: timerVisible ? 1 : 0,
                                    duration: const Duration(milliseconds: 250),
                                    child: AnimatedScale(
                                      scale: timerVisible ? 1.0 : 0.95,
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 24,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.black26,
                                          ),
                                        ),
                                        child: Text(
                                          formattedTime,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // BOTTOM BAR (fixed at bottom)
                  Container(
                    width: double.infinity,
                    color: brandGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "EARNED SO FAR",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Consumer<BenefitProvider>(
                          builder: (context, benefitProvider, _) {
                            return Text(
                              "${benefitProvider.totalSavings.toStringAsFixed(2)} €",
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
