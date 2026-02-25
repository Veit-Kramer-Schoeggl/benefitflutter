import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import "package:image_picker/image_picker.dart";
import 'package:benefitflutter/core/utils/password_utils.dart';
import 'package:benefitflutter/features/auth/utils/password_validator.dart';
import 'package:benefitflutter/features/auth/widgets/auth_widgets.dart';
import 'package:benefitflutter/features/user/domain/user.dart';
import 'package:benefitflutter/features/user/domain/user_biometrics_reported.dart';
import 'package:benefitflutter/features/user/domain/user_preferences.dart';
import 'package:benefitflutter/features/security/services/biometric_service.dart';
import 'package:benefitflutter/providers/user_provider.dart';
import 'package:benefitflutter/providers/app_lock_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:benefitflutter/presentation/screens/wearable/device_connection_screen.dart';
import 'package:path_provider/path_provider.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Brand color (consistent with other screens)
  final Color brandGreen = const Color(0xFF71B33A);
  static const double _cardGap = 6.0;

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;

  // User data
  User? _currentUser;
  UserBiometricsReported? _currentBiometrics;
  UserPreferences? _currentPreferences;

  // UI state
  String displayName = "Your Name";
  String country = "Austria";
  String? selectedGender;
  String? selectedHeight;
  String? selectedWeight;

  // Biometric state
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  AppBiometricType _biometricType = AppBiometricType.none;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadBiometricStatus();
  }

  /// Load biometric authentication status
  Future<void> _loadBiometricStatus() async {
    final appLockProvider = context.read<AppLockProvider>();
    final biometricService = appLockProvider.biometricService;

    final available = await biometricService.isBiometricAvailable();
    final enabled = await biometricService.isBiometricEnabled();
    final type = await biometricService.getPrimaryBiometricType();

    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
        _biometricType = type;
      });
    }
  }

  /// Load profile data from database
  Future<void> _loadProfileData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user from UserProvider (the logged-in user)
      final userProvider = context.read<UserProvider>();
      _currentUser = userProvider.currentUser;

      if (_currentUser == null) {
        throw Exception('No user logged in');
      }

      // Load latest biometrics
      _currentBiometrics = await userProvider.getLatestBiometrics(_currentUser!.id);

      // Load preferences
      _currentPreferences = await userProvider.getPreferences(_currentUser!.id);

      // Update UI state
      setState(() {
        displayName = _currentUser?.displayName ?? _currentUser?.name ?? "Your Name";
        country = _currentPreferences?.defaultLocationCity ?? "Austria";
        selectedGender = _formatGender(_currentUser?.gender);
        selectedHeight = _currentBiometrics?.heightCm != null
            ? "${_currentBiometrics!.heightCm} cm"
            : null;
        selectedWeight = _currentBiometrics?.weightKg != null
            ? "${_currentBiometrics!.weightKg!.toStringAsFixed(1)} kg"
            : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Format gender for display (capitalize first letter)
  String? _formatGender(String? gender) {
    if (gender == null) return null;
    return gender[0].toUpperCase() + gender.substring(1);
  }

  /// Parse gender from display format back to lowercase
  String _parseGender(String displayGender) {
    return displayGender.toLowerCase();
  }

  /// Parse height from "XXX cm" format
  int? _parseHeight(String? heightStr) {
    if (heightStr == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(heightStr);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Parse weight from "XX.X kg" format
  double? _parseWeight(String? weightStr) {
    if (weightStr == null) return null;
    final match = RegExp(r'([\d.]+)').firstMatch(weightStr);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  /// Save profile data to database
  Future<void> _saveProfileData() async {
    if (_currentUser == null) return;

    try {
      setState(() => _isSaving = true);

      // Update user (display_name, gender)
      final updatedUser = _currentUser!.copyWith(
        displayName: displayName,
        gender: selectedGender != null ? _parseGender(selectedGender!) : null,
      );
      await context.read<UserProvider>().updateUser(updatedUser);

      // Update or create biometrics if height/weight changed
      final heightCm = _parseHeight(selectedHeight);
      final weightKg = _parseWeight(selectedWeight);

      if (heightCm != null || weightKg != null) {
        final biometrics = UserBiometricsReported(
          id: _currentBiometrics?.id ?? const Uuid().v4(),
          userId: _currentUser!.id,
          reportDate: DateTime.now(),
          heightCm: heightCm ?? _currentBiometrics?.heightCm,
          weightKg: weightKg ?? _currentBiometrics?.weightKg,
          createdAt: _currentBiometrics?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await context.read<UserProvider>().saveBiometrics(biometrics);
      }

      // Update or create preferences (country)
      if (_currentPreferences != null) {
        final updatedPreferences = _currentPreferences!.copyWith(
          defaultLocationCity: country,
          updatedAt: DateTime.now(),
        );
        await context.read<UserProvider>().savePreferences(updatedPreferences);
      } else {
        // Create new preferences
        final newPreferences = UserPreferences(
          id: const Uuid().v4(),
          userId: _currentUser!.id,
          defaultLocationCity: country,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await context.read<UserProvider>().savePreferences(newPreferences);
      }

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Changes saved successfully",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: brandGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Reload data to reflect changes
      await _loadProfileData();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: brandGreen,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _handleLogout,
          ),
          title: const Text("Profile"),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: brandGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign Out',
          onPressed: _handleLogout,
        ),
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettingsDialog, // Change Name + Country
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---------------- HEADER ----------------
            Container(
              color: brandGreen,
              width: double.infinity,
              padding: const EdgeInsets.only(top: 24, bottom: 36),
              child: Column(
                children: [
                  // Profile image: clickable -> Gallery
                  GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _currentUser?.profileImagePath != null
                            ? FileImage(File(_currentUser!.profileImagePath!))
                            : const AssetImage(
                          'assets/images/icons/profile/icon_profil.png',
                        ),
                      ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    country,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _currentUser?.isVerified == true
                          ? Colors.green
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentUser?.isVerified == true
                          ? "Verified"
                          : "Not Verified",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: _cardGap),

            // --------------- GENDER -----------------
            _buildSelectionCard(
              title: "Gender",
              icon: Icons.person_outline,
              currentValue: selectedGender ?? "Select gender",
              onTap: () => _openSelectionMenu(
                title: "Gender",
                values: const ["Male", "Female", "Other"],
                onSelected: (value) =>
                    setState(() => selectedGender = value),
              ),
            ),

            // --------------- HEIGHT -----------------
            _buildSelectionCard(
              title: "Height",
              icon: Icons.height,
              currentValue: selectedHeight ?? "Select height",
              onTap: () => _openSelectionMenu(
                title: "Height (cm)",
                values: List.generate(120, (i) => "${140 + i} cm"),
                onSelected: (value) =>
                    setState(() => selectedHeight = value),
              ),
            ),

            // --------------- WEIGHT -----------------
            _buildSelectionCard(
              title: "Weight",
              icon: Icons.monitor_weight_outlined,
              currentValue: selectedWeight ?? "Select weight",
              onTap: () => _openSelectionMenu(
                title: "Weight (kg)",
                values: List.generate(120, (i) => "${40 + i} kg"),
                onSelected: (value) =>
                    setState(() => selectedWeight = value),
              ),
            ),

            const SizedBox(height: _cardGap),

            // --------------- CONNECTED DEVICES -----------------
            _buildNavigationCard(
              title: "Connected Devices",
              icon: Icons.watch,
              subtitle: "Manage wearable devices",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeviceConnectionScreen(),
                  ),
                );
              },
            ),

            // --------------- VERIFY IDENTITY -----------------
            if (_currentUser?.isVerified != true)
              _buildNavigationCard(
                title: "Verify Identity",
                icon: Icons.verified_user,
                subtitle: "Complete identity verification",
                onTap: _startVerificationFlow,
              ),

            const SizedBox(height: _cardGap),

            // --------------- CHANGE PASSWORD -----------------
            _buildNavigationCard(
              title: "Change Password",
              icon: Icons.lock_outline,
              subtitle: "Update your account password",
              onTap: _openChangePasswordDialog,
            ),

            // --------------- BIOMETRIC UNLOCK -----------------
            if (_biometricAvailable)
              _buildBiometricToggleCard(),

            // --------------- DELETE ACCOUNT -----------------
            _buildNavigationCard(
              title: "Delete Account",
              icon: Icons.delete_forever,
              subtitle: "Permanently delete your account",
              onTap: _confirmDeleteAccount,
            ),

            // --------------- SAVE BUTTON -------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveProfileData,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Save Changes",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ),

            const SizedBox(height: _cardGap),

            // --------------- LOGOUT SECTION -------------
            const Divider(),
            const SizedBox(height: _cardGap),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    "Sign Out",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Handle logout button press
  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout, color: Colors.red, size: 48),
        title: const Text('Sign Out?'),
        content: const Text(
          'Are you sure you want to sign out?\n\n'
          'Any active sessions will be stopped and saved automatically.\n\n'
          'You will need to log in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Perform logout
    if (mounted) {
      final userProvider = context.read<UserProvider>();
      await userProvider.logout();

      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  Future<String> _saveImageToAppDirectory(XFile image) async {
    final appDir = await getApplicationDocumentsDirectory();

    final fileName = '${_currentUser!.id}_profile.jpg';
    final savedImage = await File(image.path)
        .copy('${appDir.path}/$fileName');

    return savedImage.path;
  }

  // ----------------------------------------------------------
  // Pick profile image from gallery
  // ----------------------------------------------------------
  Future<void> _pickImageFromGallery() async {
    final XFile? image =
    await _picker.pickImage(source: ImageSource.gallery);

    if (image == null || _currentUser == null) return;

    try {
      setState(() => _isSaving = true);

      // Save image to app directory
      final savedPath = await _saveImageToAppDirectory(image);

      // Update user with new path
      final updatedUser = _currentUser!.copyWith(
        profileImagePath: savedPath,
      );

      // Save to DB
      await context.read<UserProvider>().updateUser(updatedUser);

      // Update local state
      setState(() {
        _currentUser = updatedUser;
        _isSaving = false;
      });

    } catch (e) {
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ----------------------------------------------------------
  // Card builder
  // ----------------------------------------------------------
  Widget _buildSelectionCard({
    required String title,
    required IconData icon,
    required String currentValue,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: brandGreen),
          title: Text(title),
          subtitle: Text(
            currentValue,
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Navigation card builder (for screens without selection)
  // ----------------------------------------------------------
  Widget _buildNavigationCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: brandGreen),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Biometric toggle card builder
  // ----------------------------------------------------------
  Widget _buildBiometricToggleCard() {
    final biometricName = _getBiometricName();
    final biometricIcon = _getBiometricIcon();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(biometricIcon, color: brandGreen),
          title: Text("Unlock with $biometricName"),
          subtitle: Text(
            _biometricEnabled
                ? "App will lock after 2 minutes in background"
                : "Enable to secure your app",
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: Switch(
            value: _biometricEnabled,
            activeColor: brandGreen,
            onChanged: _handleBiometricToggle,
          ),
        ),
      ),
    );
  }

  String _getBiometricName() {
    switch (_biometricType) {
      case AppBiometricType.faceId:
        return 'Face ID';
      case AppBiometricType.fingerprint:
        return 'Fingerprint';
      case AppBiometricType.iris:
        return 'Iris';
      case AppBiometricType.none:
        return 'Biometrics';
    }
  }

  IconData _getBiometricIcon() {
    switch (_biometricType) {
      case AppBiometricType.faceId:
        return Icons.face;
      case AppBiometricType.fingerprint:
        return Icons.fingerprint;
      case AppBiometricType.iris:
        return Icons.remove_red_eye;
      case AppBiometricType.none:
        return Icons.lock;
    }
  }

  Future<void> _handleBiometricToggle(bool enabled) async {
    final appLockProvider = context.read<AppLockProvider>();
    final biometricService = appLockProvider.biometricService;

    if (enabled) {
      // Enable biometric - requires authentication
      final success = await biometricService.enableBiometric();
      if (success) {
        setState(() {
          _biometricEnabled = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${_getBiometricName()} unlock enabled"),
              backgroundColor: brandGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to enable biometric unlock"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Disable biometric
      await biometricService.disableBiometric();
      setState(() {
        _biometricEnabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${_getBiometricName()} unlock disabled"),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  // ----------------------------------------------------------
  // Bottom sheet menu
  // ----------------------------------------------------------
  void _openSelectionMenu({
    required String title,
    required List<String> values,
    required Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: values
                    .map(
                      (v) => ListTile(
                    title: Text(v),
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(v);
                    },
                  ),
                )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Settings Dialog (change Name + Country + Email)
  // ----------------------------------------------------------
  void _openSettingsDialog() {
    final nameController = TextEditingController(text: displayName);
    final countryController = TextEditingController(text: country);
    final emailController = TextEditingController(text: _currentUser?.email ?? '');
    final originalEmail = _currentUser?.email ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile Settings"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(labelText: "Country"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  helperText: "Changing email requires verification",
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newCountry = countryController.text.trim();
              final newEmail = emailController.text.trim().toLowerCase();

              setState(() {
                displayName = newName.isEmpty ? displayName : newName;
                country = newCountry.isEmpty ? country : newCountry;
              });

              Navigator.pop(context);

              // Handle email change with mock verification
              if (newEmail.isNotEmpty && newEmail != originalEmail) {
                await _handleEmailChange(newEmail);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// Handle email change with mock verification
  Future<void> _handleEmailChange(String newEmail) async {
    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail)) {
      _showError("Invalid email format");
      return;
    }

    // Show mock verification dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.email, color: Colors.blue, size: 48),
        title: const Text("Verify Email"),
        content: Text(
          "A verification email has been sent to:\n\n"
          "$newEmail\n\n"
          "Please check your inbox and click the verification link.\n\n"
          "(Mock: Click 'Verified' to simulate successful verification)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Verified"),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentUser != null) {
      try {
        setState(() => _isSaving = true);

        final updatedUser = _currentUser!.copyWith(email: newEmail);
        await context.read<UserProvider>().updateUser(updatedUser);

        setState(() {
          _currentUser = updatedUser;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Email updated successfully"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isSaving = false);
        _showError("Error updating email");
      }
    }
  }

  Future<void> _startVerificationFlow() async {
    if (_currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_user, color: Colors.blue, size: 48),
        title: const Text("Verify Identity"),
        content: const Text(
          "Simulate identity verification process?\n\n"
              "This will mark your account as verified.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Verify"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isSaving = true);

      final updatedUser = _currentUser!.copyWith(
        isVerified: true,
        verificationStatus: "verified",
      );

      await context.read<UserProvider>().updateUser(updatedUser);

      setState(() {
        _currentUser = updatedUser;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Identity verified successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  void _openChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? currentPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;
    bool isLoading = false;
    String newPasswordValue = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Change Password"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PasswordTextField(
                  controller: currentController,
                  labelText: "Current Password",
                  errorText: currentPasswordError,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 12),
                PasswordTextField(
                  controller: newController,
                  labelText: "New Password",
                  errorText: newPasswordError,
                  enabled: !isLoading,
                  showRequirementsHelper: true,
                  onChanged: (value) {
                    setDialogState(() {
                      newPasswordValue = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (newPasswordValue.isNotEmpty)
                  PasswordStrengthIndicator(
                    password: newPasswordValue,
                    style: PasswordStrengthStyle.checksOnly,
                  ),
                const SizedBox(height: 12),
                PasswordTextField(
                  controller: confirmController,
                  labelText: "Confirm New Password",
                  errorText: confirmPasswordError,
                  enabled: !isLoading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Clear previous errors
                      setDialogState(() {
                        currentPasswordError = null;
                        newPasswordError = null;
                        confirmPasswordError = null;
                      });

                      final currentPw = currentController.text.trim();
                      final newPw = newController.text.trim();
                      final confirmPw = confirmController.text.trim();

                      // Check empty fields first
                      if (currentPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
                        setDialogState(() {
                          if (currentPw.isEmpty) {
                            currentPasswordError = "Current password is required";
                          }
                          if (newPw.isEmpty) {
                            newPasswordError = "New password is required";
                          }
                          if (confirmPw.isEmpty) {
                            confirmPasswordError = "Please confirm your new password";
                          }
                        });
                        return;
                      }

                      // FIRST: Verify current password before checking new password
                      if (!PasswordUtils.verifyPassword(currentPw, _currentUser!.passwordHash)) {
                        setDialogState(() {
                          currentPasswordError = "Current password is incorrect";
                        });
                        return;
                      }

                      // THEN: Check if new passwords match
                      if (newPw != confirmPw) {
                        setDialogState(() {
                          confirmPasswordError = "Passwords do not match";
                        });
                        return;
                      }

                      // THEN: Validate new password strength
                      final validationError = PasswordValidator.validate(newPw);
                      if (validationError != null) {
                        setDialogState(() {
                          newPasswordError = validationError;
                        });
                        return;
                      }

                      // All validations passed - save password
                      setDialogState(() {
                        isLoading = true;
                      });

                      // Use provider to change password (handles auth service + database)
                      final userProvider = this.context.read<UserProvider>();
                      final success = await userProvider.changePassword(
                        currentPassword: currentPw,
                        newPassword: newPw,
                      );

                      if (!success) {
                        setDialogState(() {
                          isLoading = false;
                          newPasswordError = userProvider.error ?? "Error saving password";
                        });
                        return;
                      }

                      // Success - refresh local user and close dialog
                      setState(() {
                        _currentUser = userProvider.currentUser;
                      });

                      Navigator.pop(dialogContext);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text("Password changed successfully"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    // Step 1: Show warning and request verification code
    final proceedToVerification = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 56),
        title: const Text(
          "Delete Your Account?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "⚠️ This action is PERMANENT and IRREVERSIBLE.",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 16),
            Text("The following will be permanently deleted:"),
            SizedBox(height: 8),
            Text("• Your profile and account information"),
            Text("• All your activity sessions and history"),
            Text("• All your benefits and rewards"),
            Text("• All connected device data"),
            Text("• All preferences and settings"),
            SizedBox(height: 16),
            Text(
              "This data CANNOT be recovered after deletion.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 16),
            Text(
              "A verification code will be sent to your email to confirm this action.",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Send Verification Code"),
          ),
        ],
      ),
    );

    if (proceedToVerification != true || _currentUser == null) return;

    // Request deletion code
    setState(() => _isSaving = true);
    final userProvider = context.read<UserProvider>();
    final deletionCode = await userProvider.requestAccountDeletion();
    setState(() => _isSaving = false);

    if (deletionCode == null) {
      _showError(userProvider.error ?? "Failed to request deletion");
      return;
    }

    if (!mounted) return;

    // Step 2: Show verification code input dialog
    await _showDeletionVerificationDialog(deletionCode);
  }

  Future<void> _showDeletionVerificationDialog(String mockCode) async {
    final codeController = TextEditingController();
    String? codeError;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.email, color: Colors.blue, size: 48),
          title: const Text("Verify Deletion"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "A verification code has been sent to:\n${_currentUser?.email ?? 'your email'}",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              VerificationCodeField(
                controller: codeController,
                labelText: "Enter 6-digit code",
                errorText: codeError,
                enabled: !isLoading,
                mockCode: mockCode,
                showMockCodeHint: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      this.context.read<UserProvider>().clearPendingDeletion();
                      Navigator.pop(dialogContext);
                    },
              child: const Text("Cancel"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = codeController.text.trim();

                      if (code.isEmpty) {
                        setDialogState(() {
                          codeError = "Please enter the verification code";
                        });
                        return;
                      }

                      if (code.length != 6) {
                        setDialogState(() {
                          codeError = "Code must be 6 digits";
                        });
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        codeError = null;
                      });

                      final userProvider = this.context.read<UserProvider>();
                      final success = await userProvider.confirmAccountDeletion(code);

                      if (!success) {
                        setDialogState(() {
                          isLoading = false;
                          codeError = userProvider.error ?? "Invalid code";
                        });
                        return;
                      }

                      // Success - navigate to login
                      Navigator.pop(dialogContext);
                      if (mounted) {
                        Navigator.of(this.context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Delete My Account"),
            ),
          ],
        ),
      ),
    );
  }
}
