import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/patient_provider.dart';

class QrCodeScreen extends ConsumerStatefulWidget {
  const QrCodeScreen({super.key});

  @override
  ConsumerState<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends ConsumerState<QrCodeScreen> {
  bool _screenshotProtectionEnabled = false;

  @override
  void dispose() {
    _disableScreenshotProtection();
    super.dispose();
  }

  void _onAuthenticated() {
    _enableScreenshotProtection();
  }

  void _enableScreenshotProtection() {
    if (Platform.isAndroid) {
      setState(() => _screenshotProtectionEnabled = true);
      // NOTE: In production, add flutter_windowmanager:
      // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  void _disableScreenshotProtection() {
    if (_screenshotProtectionEnabled && Platform.isAndroid) {
      // await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final patientData = ref.watch(patientDataProvider);

    // WRAPPED IN BIOMETRIC GUARD WITH STRICT MODE
    return BiometricGuard(
      reason: 'Authenticate to view your Medical QR Code',
      strictMode: true, // Forces auth every time you come back to this screen
      onAuthenticated: _onAuthenticated,
      onAuthenticationFailed: () {
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emergency QR Code'),
          actions: [
            if (_screenshotProtectionEnabled)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.shield_rounded, color: AppColors.success),
              ),
          ],
        ),
        body: patientData.when(
          data: (patient) {
            if (patient == null) {
              return const Center(child: Text('Patient data not found'));
            }

            final qrUrl = '${EnvConfig.emergencyBaseUrl}/${patient.qrCodeId}';

            return SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  if (_screenshotProtectionEnabled)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: AppColors.success, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Screenshot protection enabled',
                              style: TextStyle(color: Colors.green.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        Text(
                          profile.valueOrNull?.fullName ?? 'Patient',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Emergency Medical Card',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: PrettyQrView.data(
                            data: qrUrl,
                            decoration: const PrettyQrDecoration(
                              shape: PrettyQrSmoothSymbol(color: AppColors.primaryDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Share.share('My CareSync Emergency QR Code:\n$qrUrl');
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}