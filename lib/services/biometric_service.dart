import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service for handling biometric authentication
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on this device
  /// This checks both device support AND whether biometrics are enrolled
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics && canAuthenticate;
    } on PlatformException catch (e) {
      print('[BIO] Error checking biometric availability: ${e.message}');
      return false;
    }
  }

  /// Check if device hardware supports biometrics (regardless of enrollment)
  /// Use this for setup checks, not for blocking setup
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      print('[BIO] Error checking device support: ${e.message}');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if Face ID is available
  Future<bool> isFaceIdAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Check if Fingerprint is available
  Future<bool> isFingerprintAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint) ||
        biometrics.contains(BiometricType.strong);
  }

  /// Authenticate using biometrics
  /// Returns true if authentication was successful
  Future<bool> authenticate({
    String reason = 'Please authenticate to continue',
    bool biometricOnly = true,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // Handle specific errors
      if (e.code == 'NotAvailable') {
        throw BiometricException('Biometric authentication is not available');
      } else if (e.code == 'NotEnrolled') {
        throw BiometricException(
          'No biometrics enrolled. Please set up Face ID or fingerprint in device settings.',
        );
      } else if (e.code == 'LockedOut') {
        throw BiometricException(
          'Too many failed attempts. Please try again later.',
        );
      } else if (e.code == 'PermanentlyLockedOut') {
        throw BiometricException(
          'Biometric authentication is locked. Please unlock using your device passcode.',
        );
      }
      throw BiometricException('Authentication failed: ${e.message}');
    }
  }

  /// Get a user-friendly name for the available biometric type
  Future<String> getBiometricTypeName() async {
    if (await isFaceIdAvailable()) {
      return 'Face ID';
    } else if (await isFingerprintAvailable()) {
      return 'Fingerprint';
    }
    return 'Biometric';
  }

  /// Cancel any ongoing authentication
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on PlatformException {
      // Ignore cancellation errors
    }
  }
}

/// Custom exception for biometric errors
class BiometricException implements Exception {
  final String message;
  BiometricException(this.message);

  @override
  String toString() => message;
}

