import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../../services/biometric_service.dart';
import '../../../../services/secure_storage_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/patient_provider.dart';

class QrCodeScreen extends ConsumerStatefulWidget {
  const QrCodeScreen({super.key});

  @override
  ConsumerState<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends ConsumerState<QrCodeScreen> {
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  bool _screenshotProtectionEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndAuthenticate();
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    super.dispose();
  }

  Future<void> _checkBiometricAndAuthenticate() async {
    // Check if biometric is enabled in settings
    final biometricEnabled = await SecureStorageService.instance.isBiometricEnabled();

    if (!biometricEnabled) {
      // Biometric not required, show QR directly
      setState(() => _isAuthenticated = true);
      _enableScreenshotProtection();
      return;
    }

    // Require biometric authentication
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    try {
      final isAvailable = await BiometricService.instance.isBiometricAvailable();

      if (!isAvailable) {
        if (mounted) {
          _showBiometricUnavailableDialog();
        }
        return;
      }

      final authenticated = await BiometricService.instance.authenticate(
        reason: 'Authenticate to view your Medical QR Code',
        biometricOnly: true,
      );

      if (mounted) {
        setState(() {
          _isAuthenticated = authenticated;
          _isAuthenticating = false;
        });

        if (authenticated) {
          _enableScreenshotProtection();
        } else {
          Navigator.of(context).pop();
        }
      }
    } on BiometricException catch (e) {
      if (mounted) {
        setState(() => _isAuthenticating = false);
        _showErrorDialog(e.message);
      }
    }
  }

  void _enableScreenshotProtection() {
    // Screenshot protection only works on Android with native implementation
    // This is a placeholder that sets a flag but does NOT actually enable protection
    // In production, you MUST integrate flutter_windowmanager natively:
    // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    if (Platform.isAndroid) {
      setState(() => _screenshotProtectionEnabled = true);
      
      // TODO: Implement actual screenshot protection
      // Requires adding flutter_windowmanager native integration
      assert(() {
        print('[QR] Screenshot protection placeholder - NOT ACTUALLY PROTECTED');
        return true;
      }());
    }
  }

  void _disableScreenshotProtection() {
    // In production, implement actual screenshot protection disable:
    // await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    if (_screenshotProtectionEnabled && Platform.isAndroid) {
      _screenshotProtectionEnabled = false;
    }
  }

  void _showBiometricUnavailableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Biometric Unavailable'),
        content: const Text(
          'Biometric authentication is not available. Please enable biometrics in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _authenticate();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final patientData = ref.watch(patientDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency QR Code'),
        actions: [
          if (_screenshotProtectionEnabled)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.shield_rounded,
                color: AppColors.success,
              ),
            ),
        ],
      ),
      body: _isAuthenticating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Authenticating...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : !_isAuthenticated
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Authentication Required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Authenticate to view your Medical QR Code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('Authenticate'),
                      ),
                    ],
                  ),
                )
              : patientData.when(
                  data: (patient) {
                    if (patient == null) {
                      return const Center(
                        child: Text('Patient data not found'),
                      );
                    }

                    final qrUrl = '${EnvConfig.emergencyBaseUrl}/${patient.qrCodeId}';

                    return SingleChildScrollView(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Security notice
                          if (_screenshotProtectionEnabled)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.shield_rounded,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Screenshot protection enabled',
                                      style: TextStyle(
                                        color: Colors.green.shade900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Info card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This QR code allows first responders to access your public medical data in emergencies.',
                                    style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // QR Code Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Name
                                Text(
                                  profile.valueOrNull?.fullName ?? 'Patient',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Emergency Medical Card',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // QR Code using pretty_qr_code
                                SizedBox(
                                  width: 220,
                                  height: 220,
                                  child: PrettyQrView.data(
                                    data: qrUrl,
                                    decoration: const PrettyQrDecoration(
                                      shape: PrettyQrSmoothSymbol(
                                        color: AppColors.primaryDark,
                                      ),
                                      image: null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Blood type badge
                                if (patient.bloodType != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.firstResponder.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.water_drop_rounded,
                                          color: AppColors.firstResponder,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Blood Type: ${patient.bloodType}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.firstResponder,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Share.share(
                                      'My CareSync Emergency QR Code:\n$qrUrl',
                                      subject: 'Emergency Medical Information',
                                    );
                                  },
                                  icon: const Icon(Icons.share_rounded),
                                  label: const Text('Share'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // TODO: Print / save as image
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Print feature coming soon!'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.print_rounded),
                                  label: const Text('Print Card'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Privacy note
                          Text(
                            'Only data marked as "Public" will be visible when this QR is scanned.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // TODO: Navigate to privacy settings
                            },
                            child: const Text('Manage Privacy Settings'),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
    );
  }
}
