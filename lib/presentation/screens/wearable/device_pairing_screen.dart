import 'package:flutter/material.dart';
import 'package:benefitflutter/features/wearable_integration/data/sources/ble_data_source.dart';
import 'package:benefitflutter/features/wearable_integration/domain/wearable_device.dart';
import 'package:benefitflutter/features/wearable_integration/domain/enums.dart';

/// Device Pairing Screen - Guided flow for pairing BLE devices
///
/// Steps:
/// 1. Permission check
/// 2. Device scanning
/// 3. Device selection
/// 4. Connection testing
class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final Color brandGreen = const Color(0xFF71B33A);
  final BleDataSource _bleDataSource = BleDataSource();

  // State
  _PairingStep _currentStep = _PairingStep.permissions;
  bool _isScanning = false;
  List<WearableDevice> _discoveredDevices = [];
  WearableDevice? _selectedDevice;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _bleDataSource.stopScanning();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final hasPermissions = await _bleDataSource.hasPermissions();
      if (!mounted) return;
      setState(() {
        if (hasPermissions) {
          _currentStep = _PairingStep.scanning;
          _startScanning();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to check permissions: $e';
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final granted = await _bleDataSource.requestPermissions();
      if (!mounted) return;
      setState(() {
        if (granted) {
          _currentStep = _PairingStep.scanning;
          _errorMessage = null;
          _startScanning();
        } else {
          _errorMessage = 'Bluetooth permissions are required to scan for devices.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to request permissions: $e';
      });
    }
  }

  Future<void> _startScanning() async {
    if (_isScanning || !mounted) return;

    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _errorMessage = null;
    });

    try {
      // Scan for 15 seconds
      await _bleDataSource.startScanning(timeout: const Duration(seconds: 15));

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      // Get discovered devices
      final devices = await _bleDataSource.getAvailableDevices();
      if (!mounted) return;

      setState(() {
        _discoveredDevices = devices;
        _isScanning = false;
        if (devices.isEmpty) {
          _errorMessage = 'No heart rate monitors found. Make sure your device is turned on and nearby.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = 'Scan failed: $e';
      });
    }
  }

  Future<void> _connectToDevice(WearableDevice device) async {
    if (!mounted) return;

    setState(() {
      _selectedDevice = device;
      _currentStep = _PairingStep.connecting;
      _errorMessage = null;
    });

    try {
      await _bleDataSource.connectDevice(device.id);
      if (!mounted) return;

      setState(() {
        _currentStep = _PairingStep.success;
      });

      // Wait a moment to show success, then return
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentStep = _PairingStep.scanning;
        _errorMessage = 'Failed to connect: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandGreen,
        centerTitle: true,
        title: const Text(
          'Pair Device',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case _PairingStep.permissions:
        return _buildPermissionsStep();
      case _PairingStep.scanning:
        return _buildScanningStep();
      case _PairingStep.connecting:
        return _buildConnectingStep();
      case _PairingStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildPermissionsStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth,
              size: 80,
              color: brandGreen,
            ),
            const SizedBox(height: 24),
            const Text(
              'Bluetooth Permissions Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'BeneFit needs Bluetooth access to scan for and connect to heart rate monitors and fitness devices.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(
                    fontSize: 18,
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

  Widget _buildScanningStep() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: brandGreen.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.radar,
                size: 64,
                color: brandGreen,
              ),
              const SizedBox(height: 16),
              Text(
                _isScanning ? 'Scanning for devices...' : 'Available Devices',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isScanning
                    ? 'Make sure your device is turned on and nearby'
                    : 'Select a device to connect',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Scanning indicator
        if (_isScanning)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),

        // Error message
        if (_errorMessage != null && !_isScanning)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Device list
        Expanded(
          child: _discoveredDevices.isEmpty && !_isScanning
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.devices,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _discoveredDevices.length,
                  itemBuilder: (context, index) {
                    final device = _discoveredDevices[index];
                    return _buildDeviceCard(device);
                  },
                ),
        ),

        // Scan again button
        if (!_isScanning)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startScanning,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandGreen,
                  side: BorderSide(color: brandGreen),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeviceCard(WearableDevice device) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: brandGreen.withValues(alpha: 0.2),
          child: Icon(
            Icons.favorite,
            color: brandGreen,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          _getDeviceTypeString(device.type),
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: brandGreen,
        ),
        onTap: () => _connectToDevice(device),
      ),
    );
  }

  Widget _buildConnectingStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                strokeWidth: 8,
                valueColor: AlwaysStoppedAnimation<Color>(brandGreen),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Connecting...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting to ${_selectedDevice?.name ?? "device"}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Connected!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_selectedDevice?.name ?? "Device"} is now connected',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
}

enum _PairingStep {
  permissions,
  scanning,
  connecting,
  success,
}
