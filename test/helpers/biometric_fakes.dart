import 'package:benefitflutter/features/security/services/biometric_service.dart';

/// In-memory [BiometricService] for tests. Defaults to "no biometrics / app
/// lock off" so the app-lock overlay stays inactive in widget tests. Flip the
/// flags to exercise enabled/auth paths.
class FakeBiometricService implements BiometricService {
  bool biometricAvailable = false;
  bool biometricEnabled = false;
  bool appLockEnabled = false;
  bool authSucceeds = true;
  AppBiometricType primaryType = AppBiometricType.none;
  DateTime? lastUnlock;

  int authenticateCalls = 0;

  @override
  Future<bool> isDeviceSupported() async => biometricAvailable;

  @override
  Future<bool> canCheckBiometrics() async => biometricAvailable;

  @override
  Future<bool> isBiometricAvailable() async => biometricAvailable;

  @override
  Future<List<AppBiometricType>> getAvailableBiometrics() async =>
      primaryType == AppBiometricType.none ? [] : [primaryType];

  @override
  Future<AppBiometricType> getPrimaryBiometricType() async => primaryType;

  @override
  String getBiometricName(AppBiometricType type) {
    switch (type) {
      case AppBiometricType.fingerprint:
        return 'Fingerprint';
      case AppBiometricType.faceId:
        return 'Face ID';
      case AppBiometricType.iris:
        return 'Iris';
      case AppBiometricType.none:
        return 'None';
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    String reason = 'Please authenticate to unlock BeneFit',
  }) async {
    authenticateCalls++;
    return authSucceeds
        ? BiometricAuthResult.success()
        : BiometricAuthResult.failed('Authentication failed');
  }

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<bool> enableBiometric() async {
    biometricEnabled = true;
    return true;
  }

  @override
  Future<void> disableBiometric() async {
    biometricEnabled = false;
  }

  @override
  Future<bool> isAppLockEnabled() async => appLockEnabled;

  @override
  Future<void> setAppLockEnabled(bool enabled) async {
    appLockEnabled = enabled;
  }

  @override
  Future<DateTime?> getLastUnlockTime() async => lastUnlock;

  @override
  Future<void> clearPreferences() async {
    biometricEnabled = false;
    appLockEnabled = false;
    lastUnlock = null;
  }
}
