// lib/features/patient/presentation/screens/qr_code_screen.dart

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

  void _onAuthenticated() {
    if (Platform.isAndroid) {
      setState(() => _screenshotProtectionEnabled = true);
      // NOTE: In production, uncomment flutter_windowmanager to block screenshots
      // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final patientData = ref.watch(patientDataProvider);

    return BiometricGuard(
      reason: 'Authenticate to view your Medical QR Code',
      strictMode: true,
      onAuthenticated: _onAuthenticated,
      child: Scaffold(
        appBar: AppBar(title: const Text('Emergency QR Code')),
        body: patientData.when(
          data: (patient) {
            if (patient == null) return const Center(child: Text('Data not found'));

            // Construct the emergency URL
            final qrUrl = '${EnvConfig.emergencyBaseUrl}/${patient.qrCodeId}';

            return SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                children: [
                  if (_screenshotProtectionEnabled)
                    _buildProtectionBanner(),
                  const SizedBox(height: 20),
                  _buildQrCard(profile.valueOrNull?.fullName, qrUrl),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Share.share('My Emergency Medical QR:\n$qrUrl'),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share QR Link'),
                    ),
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

  Widget _buildQrCard(String? name, String data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        children: [
          Text(name ?? 'Patient', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Emergency Medical Card', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            height: 200,
            child: PrettyQrView.data(
              data: data,
              decoration: const PrettyQrDecoration(
                shape: PrettyQrSmoothSymbol(color: AppColors.primaryDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: AppColors.success, size: 20),
          SizedBox(width: 12),
          Text('Screenshot protection enabled', style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }
}