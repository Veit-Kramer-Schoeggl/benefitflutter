import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:benefitflutter/core/config/security_config.dart';

/// SSL Certificate Pinning Configuration
///
/// Pins SSL certificates for API calls to prevent MITM attacks.
/// Contains SHA-256 fingerprints of valid certificates.
///
/// ## Certificate Rotation Strategy
/// - Include 2-3 certificates (current + backups)
/// - Add new cert before old one expires
/// - Deploy app update with new cert fingerprints
/// - Remove expired certs after grace period
///
/// ## How to Get Certificate Fingerprint
/// ```bash
/// # Using openssl
/// echo | openssl s_client -connect api.benefit.app:443 2>/dev/null | \
///   openssl x509 -noout -fingerprint -sha256
///
/// # Or using keytool
/// keytool -printcert -rfc -sslserver api.benefit.app:443 | \
///   openssl x509 -inform PEM -noout -fingerprint -sha256
/// ```
class CertificatePinning {
  // TODO: Replace with real certificate fingerprints before production
  // These are placeholder values - obtain real fingerprints from your API server
  static const List<String> _pinnedFingerprints = [
    // Primary certificate (current)
    'sha256/PLACEHOLDER_PRIMARY_CERT_FINGERPRINT_BASE64_ENCODED',
    // Backup certificate (for rotation)
    'sha256/PLACEHOLDER_BACKUP_CERT_FINGERPRINT_BASE64_ENCODED',
  ];

  /// Hosts that should be pinned
  /// Only these hosts will have certificate validation
  static const List<String> _pinnedHosts = [
    'api.benefit.app',
    'dev-api.benefit.app',
  ];

  /// Check if a host should have certificate pinning
  static bool shouldPinHost(String host) {
    if (!SecurityConfig.enableCertificatePinning) return false;
    return _pinnedHosts.contains(host);
  }

  /// Validate a certificate against pinned fingerprints
  ///
  /// Returns true if certificate is valid (matches pinned fingerprint).
  /// Returns false if certificate doesn't match any pinned fingerprint.
  static bool validateCertificate(X509Certificate cert, String host) {
    // Skip validation if pinning is disabled (debug mode)
    if (!SecurityConfig.enableCertificatePinning) {
      debugPrint('CertificatePinning: Skipping validation (disabled)');
      return true;
    }

    // Skip validation for non-pinned hosts
    if (!shouldPinHost(host)) {
      return true;
    }

    try {
      // Get certificate's SHA-256 fingerprint
      final certFingerprint = _getCertificateFingerprint(cert);
      final prefixedFingerprint = 'sha256/$certFingerprint';

      // Check against pinned fingerprints
      final isValid = _pinnedFingerprints.contains(prefixedFingerprint);

      if (!isValid) {
        debugPrint(
          'CertificatePinning: Certificate validation FAILED for $host',
        );
        debugPrint('CertificatePinning: Got fingerprint: $prefixedFingerprint');
        debugPrint('CertificatePinning: Expected one of: $_pinnedFingerprints');
      } else {
        debugPrint('CertificatePinning: Certificate validated for $host');
      }

      return isValid;
    } catch (e) {
      debugPrint('CertificatePinning: Error validating certificate - $e');
      // Fail closed - reject on error
      return false;
    }
  }

  /// Get SHA-256 fingerprint of certificate in base64 format
  static String _getCertificateFingerprint(X509Certificate cert) {
    // Get DER-encoded certificate bytes
    final derBytes = cert.der;
    // Calculate SHA-256 hash
    final digest = sha256.convert(derBytes);
    // Return base64-encoded fingerprint
    return base64.encode(digest.bytes);
  }

  /// Create an HttpClient with certificate pinning enabled
  ///
  /// Use this when creating custom HTTP clients.
  static HttpClient createPinnedHttpClient() {
    final client = HttpClient();

    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          // badCertificateCallback is called when certificate validation fails
          // We implement our own validation here
          return validateCertificate(cert, host);
        };

    return client;
  }

  /// Validate and log certificate details (for debugging)
  static void logCertificateDetails(X509Certificate cert, String host) {
    if (!kDebugMode) return;

    debugPrint('=== Certificate Details for $host ===');
    debugPrint('Subject: ${cert.subject}');
    debugPrint('Issuer: ${cert.issuer}');
    debugPrint('Start: ${cert.startValidity}');
    debugPrint('End: ${cert.endValidity}');
    debugPrint('SHA256: sha256/${_getCertificateFingerprint(cert)}');
    debugPrint('=====================================');
  }
}
