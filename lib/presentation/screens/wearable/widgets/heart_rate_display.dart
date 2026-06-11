import 'package:flutter/material.dart';

/// Heart Rate Display Widget
///
/// Features:
/// - Large BPM display with pulse animation
/// - Connection status indicator
/// - Heart rate zone indicator (optional)
/// - Mini graph of recent readings (optional)
class HeartRateDisplay extends StatefulWidget {
  final int? currentHeartRate;
  final bool isConnected;
  final String? deviceName;
  final HeartRateZone? currentZone;
  final VoidCallback? onTap;

  const HeartRateDisplay({
    super.key,
    this.currentHeartRate,
    required this.isConnected,
    this.deviceName,
    this.currentZone,
    this.onTap,
  });

  @override
  State<HeartRateDisplay> createState() => _HeartRateDisplayState();
}

class _HeartRateDisplayState extends State<HeartRateDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isConnected && widget.currentHeartRate != null) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(HeartRateDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update pulse animation based on connection status
    if (widget.isConnected && widget.currentHeartRate != null) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with connection status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: widget.isConnected ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Heart Rate',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                _buildConnectionIndicator(),
              ],
            ),

            const SizedBox(height: 12),

            // Main heart rate display
            if (widget.isConnected && widget.currentHeartRate != null)
              _buildHeartRateValue()
            else
              _buildDisconnectedState(),

            // Device name
            if (widget.isConnected && widget.deviceName != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.deviceName!,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],

            // Heart rate zone indicator
            if (widget.currentZone != null) ...[
              const SizedBox(height: 12),
              _buildZoneIndicator(widget.currentZone!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isConnected
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.isConnected ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.isConnected ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateValue() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${widget.currentHeartRate}',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BPM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisconnectedState() {
    return Column(
      children: [
        Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          widget.isConnected ? 'Waiting for data...' : 'No device connected',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        if (!widget.isConnected && widget.onTap != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.onTap,
            icon: const Icon(Icons.bluetooth_searching, size: 18),
            label: const Text('Connect Device'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF71B33A),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildZoneIndicator(HeartRateZone zone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: zone.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: zone.color, width: 1.5),
      ),
      child: Text(
        zone.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: zone.color,
        ),
      ),
    );
  }
}

/// Compact version for smaller displays
class HeartRateDisplayCompact extends StatelessWidget {
  final int? currentHeartRate;
  final bool isConnected;
  final VoidCallback? onTap;

  const HeartRateDisplayCompact({
    super.key,
    this.currentHeartRate,
    required this.isConnected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite,
              color: isConnected && currentHeartRate != null
                  ? Colors.red
                  : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            if (isConnected && currentHeartRate != null)
              Text(
                '$currentHeartRate BPM',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              )
            else
              Text(
                '--',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Heart rate zone data class
class HeartRateZone {
  final String name;
  final Color color;
  final int minBpm;
  final int maxBpm;

  const HeartRateZone({
    required this.name,
    required this.color,
    required this.minBpm,
    required this.maxBpm,
  });

  /// Calculate zone from heart rate and max heart rate
  static HeartRateZone? fromHeartRate(int bpm, int maxHeartRate) {
    final zones = getZones(maxHeartRate);
    for (final zone in zones) {
      if (bpm >= zone.minBpm && bpm <= zone.maxBpm) {
        return zone;
      }
    }
    return null;
  }

  /// Get standard heart rate zones based on max heart rate
  static List<HeartRateZone> getZones(int maxHeartRate) {
    return [
      HeartRateZone(
        name: 'Resting',
        color: Colors.blue,
        minBpm: 0,
        maxBpm: (maxHeartRate * 0.5).round(),
      ),
      HeartRateZone(
        name: 'Fat Burn',
        color: Colors.lightGreen,
        minBpm: (maxHeartRate * 0.5).round() + 1,
        maxBpm: (maxHeartRate * 0.6).round(),
      ),
      HeartRateZone(
        name: 'Cardio',
        color: Colors.orange,
        minBpm: (maxHeartRate * 0.6).round() + 1,
        maxBpm: (maxHeartRate * 0.7).round(),
      ),
      HeartRateZone(
        name: 'Peak',
        color: Colors.red,
        minBpm: (maxHeartRate * 0.7).round() + 1,
        maxBpm: (maxHeartRate * 0.85).round(),
      ),
      HeartRateZone(
        name: 'Maximum',
        color: Colors.deepOrange,
        minBpm: (maxHeartRate * 0.85).round() + 1,
        maxBpm: maxHeartRate,
      ),
    ];
  }

  /// Estimate max heart rate from age (220 - age formula)
  static int estimateMaxHeartRate(int age) {
    return 220 - age;
  }
}
