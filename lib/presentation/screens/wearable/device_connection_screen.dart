import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:benefitflutter/providers/health_platform_provider.dart';
import 'package:benefitflutter/features/wearable_integration/data/sources/ble_data_source.dart';
import 'package:benefitflutter/features/wearable_integration/domain/wearable_device.dart';
import 'package:benefitflutter/features/wearable_integration/domain/enums.dart';
import 'package:benefitflutter/providers/user_provider.dart';
import 'device_pairing_screen.dart';

/// Device Connection Screen - Main hub for wearable device management
///
/// Features:
/// - Health Platform connection (Health Connect/HealthKit)
/// - BLE device scanner
/// - Connected devices list
/// - Device management (disconnect, info)
class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  // Brand colors
  final Color brandGreen = const Color(0xFF71B33A);

  final BleDataSource _bleDataSource = BleDataSource();
  List<WearableDevice> _connectedDevices = [];
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadConnectedDevices();
  }

  @override
  void dispose() {
    _bleDataSource.dispose();
    super.dispose();
  }

  Future<void> _loadConnectedDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final devices = await _bleDataSource.getConnectedDevices();
      setState(() {
        _connectedDevices = devices;
        _isLoadingDevices = false;
      });
    } catch (e) {
      setState(() => _isLoadingDevices = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load devices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleHealthPlatformConnect() async {
    final healthProvider = Provider.of<HealthPlatformProvider>(
      context,
      listen: false,
    );

    // Check if Health Connect is installed
    final isInstalled = await healthProvider.isHealthConnectInstalled();

    if (!isInstalled && Platform.isAndroid) {
      // Show dialog with option to install Health Connect
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Health Connect Required'),
          content: const Text(
            'Health Connect is not installed on your device. '
            'Would you like to install it from the Play Store?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Open Play Store to Health Connect
                final url = Uri.parse(
                  'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
                );
                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint('Failed to open Play Store: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
              child: const Text('Install'),
            ),
          ],
        ),
      );
      return;
    }

    // Health Connect is installed, request permissions
    final success = await healthProvider.connect();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health platform connected successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      // Show error with option to open settings
      final errorMsg = healthProvider.errorMessage ?? 'Failed to connect';
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Failed'),
          content: Text(errorMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (errorMsg.contains('denied'))
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Open app settings using permission_handler
                  try {
                    await openAppSettings();
                  } catch (e) {
                    debugPrint('Failed to open settings: $e');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
                child: const Text('Open Settings'),
              ),
          ],
        ),
      );
    }
  }

  Future<void> _disconnectDevice(String deviceId, String deviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device'),
        content: Text('Are you sure you want to disconnect $deviceName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _bleDataSource.disconnectDevice(deviceId);
        await _loadConnectedDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$deviceName disconnected'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to disconnect: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandGreen,
        centerTitle: true,
        title: const Text(
          'Connected Devices',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadConnectedDevices,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Health Platform Card
            _buildHealthPlatformCard(),

            const SizedBox(height: 16),

            // BLE Scanner Card
            _buildBleCard(),

            const SizedBox(height: 24),

            // Connected Devices Section
            _buildConnectedDevicesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthPlatformCard() {
    return Consumer<HealthPlatformProvider>(
      builder: (context, healthProvider, child) {
        final isConnected = healthProvider.isConnected;
        final isSyncing = healthProvider.isSyncing;
        final lastSyncTime = healthProvider.lastSyncTime;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite, color: brandGreen, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Health Platform',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Connected',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Connect to Health Connect (Android) or HealthKit (iOS) to sync your health data.',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                if (isConnected && lastSyncTime != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last synced: ${_formatLastSyncTime(lastSyncTime)}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSyncing
                        ? null
                        : () async {
                            if (isConnected) {
                              // Sync data if already connected
                              final userProvider = context.read<UserProvider>();
                              final userId = userProvider.userId;
                              if (userId == null) return;
                              await healthProvider.syncAll(userId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Health data synced successfully',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              // Connect with improved flow
                              await _handleHealthPlatformConnect();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSyncing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            isConnected ? 'Sync Now' : 'Connect',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBleCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth, color: brandGreen, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bluetooth Devices',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect heart rate monitors and other fitness sensors via Bluetooth.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DevicePairingScreen(),
                    ),
                  );

                  // Reload devices if a new device was connected
                  if (result == true) {
                    await _loadConnectedDevices();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Scan for Devices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDevicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connected Devices',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_isLoadingDevices)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_connectedDevices.isEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.devices, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No devices connected',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...(_connectedDevices.map((device) => _buildDeviceCard(device))),
      ],
    );
  }

  Widget _buildDeviceCard(WearableDevice device) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: brandGreen.withValues(alpha: 0.2),
          child: Icon(_getDeviceIcon(device.type), color: brandGreen),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          _getDeviceTypeString(device.type),
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(device.status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getStatusString(device.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                _showDeviceOptions(device);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceOptions(WearableDevice device) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Device Info'),
              onTap: () {
                Navigator.pop(context);
                _showDeviceInfo(device);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth_disabled, color: Colors.red),
              title: const Text('Disconnect'),
              onTap: () {
                Navigator.pop(context);
                _disconnectDevice(device.id, device.name);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeviceInfo(WearableDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Type', _getDeviceTypeString(device.type)),
            _buildInfoRow('Source', _getSourceString(device.source)),
            _buildInfoRow('Status', _getStatusString(device.status)),
            const SizedBox(height: 8),
            const Text(
              'Capabilities:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...device.capabilities.map(
              (capability) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• ${_getSensorTypeString(capability)}'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.heartRateMonitor:
        return Icons.favorite;
      case WearableDeviceType.smartwatch:
        return Icons.watch;
      case WearableDeviceType.fitnessBand:
        return Icons.watch;
      case WearableDeviceType.cyclingSensor:
        return Icons.directions_bike;
      case WearableDeviceType.runningPod:
        return Icons.directions_run;
      case WearableDeviceType.smartScale:
        return Icons.scale;
      case WearableDeviceType.healthPlatform:
        return Icons.health_and_safety;
      case WearableDeviceType.unknown:
        return Icons.device_unknown;
    }
  }

  String _getDeviceTypeString(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.heartRateMonitor:
        return 'Heart Rate Monitor';
      case WearableDeviceType.smartwatch:
        return 'Smartwatch';
      case WearableDeviceType.fitnessBand:
        return 'Fitness Band';
      case WearableDeviceType.cyclingSensor:
        return 'Cycling Sensor';
      case WearableDeviceType.runningPod:
        return 'Running Pod';
      case WearableDeviceType.smartScale:
        return 'Smart Scale';
      case WearableDeviceType.healthPlatform:
        return 'Health Platform';
      case WearableDeviceType.unknown:
        return 'Unknown Device';
    }
  }

  String _getSourceString(IntegrationSource source) {
    switch (source) {
      case IntegrationSource.ble:
        return 'Bluetooth';
      case IntegrationSource.healthConnect:
        return 'Health Connect';
      case IntegrationSource.healthKit:
        return 'HealthKit';
      case IntegrationSource.manual:
        return 'Manual';
    }
  }

  String _getStatusString(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.scanning:
        return 'Scanning';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.disconnected:
        return Colors.grey;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.scanning:
        return Colors.blue;
      case ConnectionStatus.error:
        return Colors.red;
    }
  }

  String _getSensorTypeString(SensorType type) {
    switch (type) {
      case SensorType.heartRate:
        return 'Heart Rate';
      case SensorType.heartRateVariability:
        return 'HRV';
      case SensorType.bloodOxygen:
        return 'Blood Oxygen';
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.cadence:
        return 'Cadence';
      case SensorType.power:
        return 'Power';
      case SensorType.strideLength:
        return 'Stride Length';
      case SensorType.steps:
        return 'Steps';
      case SensorType.speed:
        return 'Speed';
      case SensorType.distance:
        return 'Distance';
      case SensorType.elevation:
        return 'Elevation';
      case SensorType.calories:
        return 'Calories';
    }
  }

  String _formatLastSyncTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
